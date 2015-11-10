SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    Populates the member security (MS) table for a specific entity, using the following rules:  
    1)    Within a single hierarchy, single role, an explicit DENY always wins throughout its sub-tree,   
        regardless of any descendant�s other security assignments.  
    2)    Within a single hierarchy, single role, the closest assignment to a member wins.  
        So if there is a READ closer than an earlier WRITE then the READ wins  
    3)    Across 2 or more hierarchies, in a single role, the MIN permission should prevail.   
        So if a specific member in two hierarchies has H1=READ and H2=WRITE then READ wins  
    4)    Across 2 or more roles, 1 or more hierarchies, the MAX permission wins.   
        So if a specific member in two roles has R1=READ and R2=WRITE then WRITE wins  
  
    Test cases:  
    EXEC mdm.udpSecurityMemberProcess @Entity_ID = 7, @Version_ID = 4;  
    EXEC mdm.udpSecurityMemberProcess @Entity_ID = 8, @Version_ID = 4;  
    EXEC mdm.udpSecurityMemberProcess @Entity_ID = 41, @Version_ID = 21;  
    EXEC mdm.udpSecurityMemberProcess @Entity_ID = 36, @Version_ID = 20;  
    SELECT en.ID AS Entity_ID, md.ID AS Model_ID, mv.ID AS Version_ID FROM mdm.tblEntity AS en INNER JOIN mdm.tblModel AS md ON (en.Model_ID = md.ID) INNER JOIN mdm.tblModelVersion AS mv ON (md.ID = mv.Model_ID)  
    SELECT * FROM mdm.tbl_2_7_MS;  
    SELECT * FROM mdm.tblHierarchy  
    SELECT * FROM mdm.tblDerivedHierarchy  
    SELECT * FROM mdm.tblDerivedHierarchyDetail  
    SELECT * FROM mdm.tblSecurityRoleAccessMember WHERE Entity_ID = 7 AND Version_ID = 4  
    DELETE FROM mdm.tblSecurityRoleAccessMember WHERE Entity_ID = 8  
    UPDATE mdm.tblSecurityRoleAccessMember SET HierarchyType_ID = 0 WHERE Entity_ID = 8 AND Version_ID = 4 AND Hierarchy_ID = 7  
      
    --ALTER DATABASE MDM_Sample SET SINGLE_USER WITH ROLLBACK IMMEDIATE;  
    --ALTER DATABASE MDM_Sample SET MULTI_USER;  
    --ALTER DATABASE MDM_Sample SET READ_COMMITTED_SNAPSHOT ON;  
*/  
CREATE PROCEDURE [mdm].[udpSecurityMemberProcess]  
(  
    @Entity_ID  INT,  
    @Version_ID INT,  
    @UserIdList mdm.IdList READONLY -- Optional list of user IDs whose member count cache will be invalidated. If none are specified, then all users will have their cache invalidated.  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    /*=================================================================  
      Declare variables, check parameters, initialize structures  
      =================================================================*/  
  
    DECLARE  
        @Model_ID               INT,  
        @SQL                    NVARCHAR(MAX),  
        @table_MS               sysname,  
        @table_HR               sysname,  
        @SecurityRole_ID        INT,  
        @DerivedHierarchy_ID    INT,  
        -- This pseudo-constant is for use in string concatenation operations to prevent string truncation. When concatenating two or more strings,  
        -- if none of the strings is an NVARCHAR(MAX) or an NVARCHAR constant that is longer than 4,000 characters, then the resulting string   
        -- will be silently truncated to 4,000 characters. Concatenating with this empty NVARCHAR(MAX), is sufficient to prevent truncation.  
        -- See http://connect.microsoft.com/SQLServer/feedback/details/283368/nvarchar-max-concatenation-yields-silent-truncation.  
        @TruncationGuard            NVARCHAR(MAX) = N'';  
      
    --Validate that @Entity_ID is both specified and valid  
    IF (@Entity_ID IS NULL OR NOT EXISTS(SELECT 1 FROM mdm.tblEntity WHERE ID = @Entity_ID)) BEGIN  
        RAISERROR('MDSERR100004|The Entity ID is not valid.', 16, 1);  
        RETURN;    
    END; --if  
      
    --Try populate variables based on input parameters. If specific variables  
    --are still NULL after the query, that implies that an invalid combination  
    --of parameters was passed in.  
    SELECT   
        @Model_ID = md.ID,  
        @table_MS = en.SecurityTable,      
        @table_HR = en.HierarchyTable  
    FROM mdm.tblEntity AS en   
    INNER JOIN mdm.tblModel AS md ON (en.Model_ID = md.ID)  
    INNER JOIN mdm.tblModelVersion AS mv ON (md.ID = mv.Model_ID)   
    WHERE en.ID = @Entity_ID AND mv.ID = @Version_ID;  
      
    --Validate that @Version_ID is both specified and valid (based on previous query)  
    IF (@Version_ID IS NULL OR @table_MS IS NULL) BEGIN  
        RAISERROR('MDSERR100005|The Version ID is not valid.', 16, 1);  
        RETURN;    
    END; --if  
      
    --Cache all the security assignments in a form that saves us some computation later  
    CREATE TABLE #assignments  
    (  
        SecurityRole_ID         INT NOT NULL, --The Security Role that has this assignment.  
        Entity_ID               INT NOT NULL, --The Entity_ID that is secured. Ignored (value 0) for VirtualRoots.  
        ExplicitHierarchy_ID    INT NULL, --\ These two columns are mutually exclusive.  
        DerivedHierarchy_ID     INT NULL, --/ They point to the hierarchy that is secured.  
        EN_ID                   INT NULL, --\ These two columns are mutually exclusive. Both are NULL for VirtualRoots.  
        HP_ID                   INT NULL, --/ They point to the member row that is secured.  
        IsVirtualRoot           BIT NOT NULL, --A VirtualRoot is a non-material row providing a single place to secure the entire hierarchy.  
        Privilege_ID            INT NOT NULL, --1=DENY, 2=READ, 3=UPDATE  
        SRAM_ID                 INT NOT NULL, --Original ID from SRAM table          
        IsProcessed             BIT NOT NULL  --Loop counter to keep track of which settings have been applied  
    ); --create table  
    CREATE CLUSTERED INDEX ix_assignments ON #assignments(SecurityRole_ID, Entity_ID, ExplicitHierarchy_ID, DerivedHierarchy_ID, IsVirtualRoot, EN_ID, HP_ID);  
  
    PRINT 'Creating member security items for Entity_ID: ' + CONVERT(NVARCHAR(30), @Entity_ID) + ' and Version_ID: ' + CONVERT(NVARCHAR(30), @Version_ID) + ' started at: ' + CONVERT(NVARCHAR(30), GETDATE(), 108);  
      
    --Populate the #assignments temporary table with just the data relevant to this model/version.  
    --For the explicit hierarchy assignments, load just the specified entity  
    --For the derived hierarchy assignments, load all entities in the model of the specified entity  
    INSERT INTO #assignments(SecurityRole_ID, Entity_ID, ExplicitHierarchy_ID, DerivedHierarchy_ID, EN_ID, HP_ID, IsVirtualRoot, Privilege_ID, SRAM_ID, IsProcessed)  
    SELECT DISTINCT   
        sr.Role_ID,   
        CASE sr.HierarchyType_ID   
            WHEN 0 THEN sr.Entity_ID   
            ELSE CASE   
                WHEN sr.MemberType_ID = 2 AND sr.Member_ID = 0 THEN 0 --Entity_ID ignored for DH VirtualRoot records  
                ELSE sr.Entity_ID   
            END   
        END, --case  
        CASE sr.HierarchyType_ID WHEN 0 THEN sr.Hierarchy_ID ELSE NULL END, --ExplicitHierarchy_ID  
        CASE sr.HierarchyType_ID WHEN 1 THEN sr.Hierarchy_ID ELSE NULL END, --DerivedHierarchy_ID  
        CASE sr.MemberType_ID WHEN 1 THEN sr.Member_ID ELSE NULL END, --EN_ID  
        CASE WHEN sr.MemberType_ID = 2 AND sr.Member_ID = 0 THEN NULL WHEN sr.MemberType_ID = 2 THEN sr.Member_ID ELSE NULL END, --HP_ID  
        CASE WHEN sr.MemberType_ID = 2 AND sr.Member_ID = 0 THEN 1 ELSE 0 END, --IsVirtualRoot  
        sr.Privilege_ID,  
        sr.ID,          
        0 --IsProcessed=False  
    FROM mdm.tblModel AS md  
    INNER JOIN mdm.tblEntity AS en ON (md.ID = en.Model_ID)  
    INNER JOIN mdm.tblSecurityRoleAccessMember AS sr ON (en.ID = sr.Entity_ID)  
    WHERE   
        md.ID = @Model_ID   
        AND sr.Version_ID = @Version_ID --Do NOT filter on Status_ID since we simply reprocess everything (1=new, 2=processed)  
        AND (sr.Entity_ID = @Entity_ID OR sr.HierarchyType_ID = 1); --Requested entity for EH, and all model's entities for DH  
  
    --Create a temporary table to hold the intermediate values. We need a staging  
    --area since maps from different hierarchies in the entity will create duplicate  
    --and overlapping entries.  
    CREATE TABLE #map  
    (  
        ID INT IDENTITY(1,1),  
        SecurityRole_ID     INT NOT NULL,  
        MemberType_ID       TINYINT NOT NULL,   
        EN_ID               INT NULL,  
        HP_ID               INT NULL,  
        Privilege_ID        INT NOT NULL,  
        PrivilegeSortOrder  INT NOT NULL  
    ); --create table  
    CREATE CLUSTERED INDEX ix_map ON #map(SecurityRole_ID, MemberType_ID, EN_ID, HP_ID);  
  
  
    /*=================================================================  
      Explicit Hierarchy analysis  
      =================================================================*/  
  
    --Don't do anything if explicit hierachies do not exist for this entity, or there are no relevant security assignments  
    IF @table_HR IS NOT NULL AND EXISTS(SELECT 1 FROM #assignments WHERE ExplicitHierarchy_ID IS NOT NULL AND IsProcessed = 0) BEGIN  
      
        --Note that there may be multiple rows with the same SecurityRole_ID, so we use TOP 1  
        SELECT TOP 1 @SecurityRole_ID = SecurityRole_ID FROM #assignments WHERE ExplicitHierarchy_ID IS NOT NULL AND IsProcessed = 0 ORDER BY SecurityRole_ID;  
  
        --Stage the security data from any explicit hierarchies associated with the entity  
        --Filter the SRAM table to get only the rows within context of the current request  
        --Since the Privilege_ID enum is not in the order of least-privilege.  
        SET @SQL = N'  
            WITH sram AS  
            (    --Filter the SRAM table to get only the rows within context of the current request  
                SELECT ExplicitHierarchy_ID, EN_ID, HP_ID, IsVirtualRoot, Privilege_ID   
                FROM #assignments WHERE  
                    SecurityRole_ID = @SecurityRole_ID AND --Current Security Role  
                    Entity_ID = @Entity_ID AND --Requested Entity  
                    ExplicitHierarchy_ID IS NOT NULL --Only want Explicit Hierarchies      
                    AND IsProcessed = 0                      
            ),';  
  
        --Virtual roots: The user can assign a permission to the root of the hierarchy.  
        --However the root is a UE/security concept and does not exist in the actual tables.   
        --We need a virtual root member for each hierarchy for each role specified anywhere in the tree.   
        --All members that inherit directly from the virtual root have their Parent_HP_ID set to NULL.   
        --We create virtual roots regardless of whether the root is assigned explicit permissions,  
        --since we need to cater for the degenerate case (hence the LEFT join)  
        SET @SQL = @SQL + N'  
            virtualRoots AS  
            (    --Virtual roots    (with or without security assignments)  
                SELECT DISTINCT  
                    hr.Hierarchy_ID AS ExplicitHierarchy_ID,  
                    NULL AS Parent_HP_ID,  
                    NULL AS Child_EN_ID,   
                    NULL AS Child_HP_ID,  
                    sr.Privilege_ID,  
                    CONVERT(BIT, 1) AS IsVirtualRoot  
                FROM mdm.' + QUOTENAME(@table_HR) + N' AS hr  
                LEFT JOIN sram AS sr ON  
                    hr.Hierarchy_ID = sr.ExplicitHierarchy_ID  
                    AND sr.IsVirtualRoot = 1 --Ensure assignment is at the root  
                WHERE  
                    hr.Version_ID = @Version_ID --Requested Version  
                    AND hr.Parent_HP_ID IS NULL --Top-level nodes only  
                    AND hr.Status_ID = 1 --Active (non-deleted)                          
            ),';  
  
        --The memberNodes CTE joins the raw members to the security role access member (SRAM) table  
        --in order to find the members that have explicit security assignments.  
        SET @SQL = @SQL + N'  
            memberNodes AS  
            (    --Raw members with assignments  
                SELECT  
                    hr.Hierarchy_ID AS ExplicitHierarchy_ID,   
                    hr.Parent_HP_ID,  
                    hr.Child_EN_ID,   
                    hr.Child_HP_ID,  
                    sr.Privilege_ID,  
                    CONVERT(BIT, 0) AS IsVirtualRoot  
                FROM mdm.' + QUOTENAME(@table_HR) + N' AS hr   
                LEFT JOIN sram AS sr ON   
                    hr.Hierarchy_ID = sr.ExplicitHierarchy_ID AND  
                    sr.IsVirtualRoot = 0 AND  
                    (      
                        (hr.ChildType_ID = 1 AND hr.Child_EN_ID = sr.EN_ID) OR   
                        (hr.ChildType_ID = 2 AND hr.Child_HP_ID = sr.HP_ID)  
                    )  
                WHERE   
                    hr.Version_ID = @Version_ID AND --Requested Version  
                    hr.Status_ID = 1 --Active (non-deleted)  
            ),';  
  
        --Instead of composing another CTE, dump the results to a temporary staging table so  
        --we can index it in order to improve performance for the next step.  
        --We need to swap read(3->2) & write(2->3) to make the sorting operation work. We swap   
        --them back when we are complete.  
        --Use a SELECT INTO to create the staging table to get the best bulk insert performance  
        SET @SQL = @SQL + N'  
            stage AS   
            (  
                SELECT IsVirtualRoot, ExplicitHierarchy_ID, Parent_HP_ID, Child_EN_ID, Child_HP_ID, Privilege_ID FROM virtualRoots  
                UNION ALL  
                SELECT IsVirtualRoot, ExplicitHierarchy_ID, Parent_HP_ID, Child_EN_ID, Child_HP_ID, Privilege_ID FROM memberNodes  
            )  
            SELECT   
                IsVirtualRoot, ExplicitHierarchy_ID, Parent_HP_ID, Child_EN_ID, Child_HP_ID,  
                CASE Privilege_ID WHEN 2 THEN 3 WHEN 3 THEN 2 ELSE Privilege_ID END AS Privilege_ID --Swap 2 & 3 so least privilege sorting works  
            INTO #stage  
            FROM stage;  
              
            CREATE CLUSTERED INDEX ix_stage ON #stage(IsVirtualRoot, ExplicitHierarchy_ID, Parent_HP_ID, Child_EN_ID, Child_HP_ID);  
            ';  
          
        --The tree CTE is a recursive branch-walker that pulls permissions down inheritance  
        --chains. The anchor clause selects the virtual root, and the recursive clause  
        --selects any member whose ascendant is in the anchor set. It also defines the distance   
        --(delta) between assigned nodes and their non-assigned descendants which is important   
        --later on when we look for the closest assignments.  
        SET @SQL = @SQL + N'  
            WITH tree AS  
            (    --Anchor clause  
                SELECT  
                    ExplicitHierarchy_ID,   
                    Parent_HP_ID,  
                    Child_EN_ID,   
                    Child_HP_ID,  
                    Privilege_ID,  
                    IsVirtualRoot,  
                    --Distance to closest assigned node (NULL=none, 0=self)  
                    CASE WHEN Privilege_ID IS NULL THEN NULL ELSE 0 END AS Delta_ID   
                FROM #stage  
                WHERE IsVirtualRoot = 1  
                  
                UNION ALL --This is a recursive UNION  
                  
                --Recursive clause  
                SELECT   
                    mom.ExplicitHierarchy_ID,  
                    kid.Parent_HP_ID,   
                    kid.Child_EN_ID,   
                    kid.Child_HP_ID,  
                    CASE --Recursively inherit Privilege_ID following the specified rules   
                        WHEN mom.Privilege_ID = 1 THEN 1 --Inherited explicit DENY trumps any given security on child  
                        ELSE ISNULL(kid.Privilege_ID, mom.Privilege_ID) --Else use the most recent (closest) assignment  
                    END AS Privilege_ID, --case  
                    kid.IsVirtualRoot,  
                    CASE --Distance to most recently (closest) assigned node (NULL=none, 0=self)  
                        WHEN mom.Privilege_ID = 1 THEN 0 --Since an inherited explicit DENY trumps all, treat it as a local assignment  
                        WHEN kid.Privilege_ID IS NULL THEN mom.Delta_ID + 1 --If no local assignment, get distance to closest inherited assignment  
                        ELSE 0 --Reset distance to 0, since current node has an explicit assignment  
                    END AS Delta_ID --case  
                FROM tree AS mom  
                INNER JOIN #stage AS kid ON  
                    mom.ExplicitHierarchy_ID = kid.ExplicitHierarchy_ID AND                          
                    (  
                        (mom.IsVirtualRoot = 1 AND kid.Parent_HP_ID IS NULL) OR --For virtual roots, join on NULL==NULL  
                        (mom.IsVirtualRoot = 0 AND mom.Child_HP_ID = kid.Parent_HP_ID) --For non-root members, join on keys  
                    )  
                WHERE kid.IsVirtualRoot = 0  
            ),';  
  
        --The closestInPath CTE partitions each member by the hierarchies & roles that it is in. It autonumbers   
        --each row within a partition such that the row with the smallest delta (distance to an assigned node,   
        --including itself) is first in the partition.  
        --We exclude virtual roots since they were just a computation convenience. We also exclude any member   
        --having neither explicit nor inherited security.   
        SET @SQL = @SQL + N'  
            closestInPath AS  
            (    --Only keep non-virtual rows with explicit assignments in their ancestor path.   
                --Sort each node by the roles it belongs to, with the smallest distance coming first  
                SELECT   
                    ROW_NUMBER() OVER(PARTITION BY ExplicitHierarchy_ID, Child_EN_ID, Child_HP_ID ORDER BY Delta_ID ASC) AS Sequence_ID,  
                    ExplicitHierarchy_ID, Child_EN_ID AS EN_ID, Child_HP_ID AS HP_ID, Delta_ID, Privilege_ID  
                FROM tree   
                WHERE IsVirtualRoot = 0 AND Delta_ID IS NOT NULL   
            ),';  
              
        --Since we might have multiple explicit hierarchies within this entity, we now need to consolidate the  
        --privileges across them. We do this via a GROUPing clause that finds the MIN (least privilege) across  
        --all the hierarchies and roles that the member participates in. Note that we are still within the context  
        --of a single role.  
        SET @SQL = @SQL + N'  
            leastPrivilege AS  
            (    --If a specific member within a single role belongs to multiple secured explicit hierarchies, then  
                --that member retains the LEAST privilege propogated from within that context.  
                SELECT EN_ID, HP_ID, MIN(Privilege_ID) AS Privilege_ID  
                FROM closestInPath  
                WHERE Sequence_ID = 1 --Only keep the most recent (closest) assignment                  
                GROUP BY EN_ID, HP_ID  
            )';  
              
        --The final operation inserts into the staging table, ensures that the closest (most recent)   
        --explicitly-assigned permissions trump any inherited permissions.  
        --Swap the Privilege_ID enum back to its original form since we are now done with sorting it                  
        SET @SQL = @SQL + N'  
            INSERT INTO #map(SecurityRole_ID, MemberType_ID, EN_ID, HP_ID, Privilege_ID, PrivilegeSortOrder)  
            SELECT @SecurityRole_ID, CASE WHEN EN_ID IS NOT NULL THEN 1 ELSE 2 END, EN_ID, HP_ID,   
                CASE Privilege_ID WHEN 2 THEN 3 WHEN 3 THEN 2 ELSE Privilege_ID END, -- unswap Read (3) and Update (2) permissions  
                Privilege_ID -- use the swapped Privilege_ID as the sort order  
            FROM leastPrivilege;';  
              
        --Finally output the number of rows inserted (for debugging & tracing purposes)  
        --then clean up the temp table so it can be recreated in the next iteration  
        SET @SQL = @SQL + N'  
            PRINT ''' + QUOTENAME(@table_MS) + N': EH (All): '' + CONVERT(NVARCHAR(30), @@ROWCOUNT);  
            PRINT CONVERT(NVARCHAR(MAX),GETDATE(), 108);  
            DROP TABLE #stage;  
            ';  
  
        --Loop through each SecurityRole_ID of the explicit hierarchies  
        --The SQL statement that we execute is the same for each role, so this is a small, tight loop  
        WHILE EXISTS(SELECT 1 FROM #assignments WHERE ExplicitHierarchy_ID IS NOT NULL AND IsProcessed = 0) BEGIN  
  
            SELECT TOP 1 @SecurityRole_ID = SecurityRole_ID FROM #assignments WHERE ExplicitHierarchy_ID IS NOT NULL AND IsProcessed = 0 ORDER BY SecurityRole_ID;  
              
            --Execute the dynamic SQL  
            --PRINT @SQL;  
            EXEC sp_executesql @SQL, N'@Entity_ID INT, @Version_ID INT, @SecurityRole_ID INT', @Entity_ID, @Version_ID, @SecurityRole_ID;  
          
            UPDATE #assignments SET IsProcessed = 1 WHERE ExplicitHierarchy_ID IS NOT NULL AND SecurityRole_ID = @SecurityRole_ID;  
  
        END; --while  
  
    END; --if  
  
  
    /*=================================================================  
      Derived Hierarchy analysis  
      =================================================================*/      
  
    --Stage the security data from any derived hierarchies associated with the entity's model  
    --Don't do anything if derived hierachies do not exist for this entity's model, or there are no relevant security assignments  
    IF EXISTS(SELECT 1 FROM #assignments WHERE DerivedHierarchy_ID IS NOT NULL AND IsProcessed = 0) BEGIN  
  
        --Create a table to hold the details of each level of every derived hierarchy in the entity's model  
        CREATE TABLE #dhLevel  
        (  
            ID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY CLUSTERED,   
            DerivedHierarchy_ID INT NOT NULL,   
            Level_ID INT NOT NULL,   
            Entity_ID INT NOT NULL,   
            EntityTable sysname,   
            EntityName NVARCHAR(50) NOT NULL,   
            DbaColumn sysname NULL,   
            DbaEntity_ID INT NULL,   
            DbaLevel_ID INT NULL,  
            IsProcessed BIT NOT NULL DEFAULT 0  
        ); --table  
  
        --Get the details for non-composite hierarchies in the current model  
        WITH dhLevel AS  
        (  
            SELECT  
                 dh.ID AS DerivedHierarchy_ID  
                ,dhd.[Name]  
                ,dhd.Level_ID  
                --ForeignType_ID has range [0..4] so ensure CASE statements exclude non-applicable values  
                ,CASE dhd.ForeignType_ID WHEN 0 THEN dhd.Foreign_ID WHEN 1 THEN a.DomainEntity_ID ELSE NULL END AS [Entity_ID]   
                ,CASE dhd.ForeignType_ID WHEN 1 THEN a.Entity_ID ELSE NULL END AS [Parent.Entity.ID]  
                ,CASE dhd.ForeignType_ID WHEN 1 THEN dhd.Foreign_ID ELSE NULL END AS [Parent.Attribute.ID]  
                ,CASE dhd.ForeignType_ID WHEN 1 THEN a.[TableColumn] ELSE NULL END AS [Parent.Attribute.TableColumn]  
            FROM mdm.tblDerivedHierarchy AS dh  
            INNER JOIN mdm.tblDerivedHierarchyDetail AS dhd ON (dh.ID = dhd.DerivedHierarchy_ID) --Ensures that DH has at least one defined level  
            LEFT JOIN mdm.tblAttribute AS a ON (dhd.Foreign_ID = a.ID) --Levels join via DBAs  
            WHERE dh.Model_ID = @Model_ID  
        ),  
        exclude AS  
        (    --Exclude specific types of derived hierarchies:  
            SELECT   
                DerivedHierarchy_ID, [Name], Level_ID, Entity_ID, [Parent.Entity.ID], [Parent.Attribute.ID], [Parent.Attribute.TableColumn]  
            FROM dhLevel WHERE  
                --Only use hierarchies that include a level that uses the specified entity  
                DerivedHierarchy_ID IN (SELECT DerivedHierarchy_ID FROM dhLevel WHERE Entity_ID = @Entity_ID) AND  
                --Exclude hybrid(composite) hierarchies  
                DerivedHierarchy_ID NOT IN (SELECT DerivedHierarchy_ID FROM mdm.tblDerivedHierarchyDetail WHERE ForeignType_ID > 1)  
        )  
        --Insert the details into the #dhLevels table in a shape that will make the @SQL generation simpler  
        INSERT INTO #dhLevel(DerivedHierarchy_ID, Level_ID, Entity_ID, EntityTable, EntityName, DbaColumn, DbaEntity_ID, DbaLevel_ID)  
        SELECT kid.DerivedHierarchy_ID, kid.Level_ID, kid.Entity_ID, en.EntityTable, en.Name, mom.[Parent.Attribute.TableColumn], mom.Entity_ID, mom.Level_ID  
        FROM exclude AS kid  
        INNER JOIN mdm.tblEntity AS en ON (kid.Entity_ID = en.ID)  
        LEFT JOIN exclude AS mom ON (kid.Entity_ID = mom.[Parent.Entity.ID] AND kid.DerivedHierarchy_ID = mom.DerivedHierarchy_ID)  
        ORDER BY kid.Level_ID DESC; --MDS hierarchies are declared upside-down, so we want to reverse the order  
  
        --SELECT * FROM #dhLevel;  
  
        --Don't do anything if there are no defined levels in the derived hierarchies  
        --Loop through each derived hierarchy one at a time, since they each have a different structure  
        WHILE EXISTS(SELECT 1 FROM #dhLevel WHERE IsProcessed = 0) BEGIN  
          
            --There will likely be several rows for each derived hierarchy id, so use TOP 1  
            SELECT TOP 1 @DerivedHierarchy_ID = DerivedHierarchy_ID   
            FROM #dhLevel WHERE IsProcessed = 0 ORDER BY DerivedHierarchy_ID;  
              
            --Generate the virtual roots for the current derived hierarchy and security role  
            SET @SQL = N'  
                        WITH sram AS  
                        (    --Filter the SRAM table to get only the rows within context of the current request  
                            SELECT Entity_ID, EN_ID, HP_ID, IsVirtualRoot, Privilege_ID  
                            FROM #assignments WHERE  
                                DerivedHierarchy_ID = @DerivedHierarchy_ID AND --Only want the current derived hierarchy  
                                SecurityRole_ID = @SecurityRole_ID --Only want the current security role  
                                AND IsProcessed = 0  
                        ),  
                        virtualRoots AS  
                        (    --Virtual roots    (with or without security assignments)  
                            SELECT   
                                sr.Privilege_ID,  
                                CASE WHEN sr.Privilege_ID IS NOT NULL THEN 0 ELSE NULL END AS Delta_ID,  
                                CONVERT(BIT, 1) AS IsVirtualRoot                              
                            FROM #dhLevel AS lv  
                            INNER JOIN mdm.tblDerivedHierarchy AS dh ON (lv.DerivedHierarchy_ID = dh.ID)  
                            INNER JOIN mdm.tblModel AS md ON (dh.Model_ID = md.ID)  
                            INNER JOIN mdm.tblModelVersion AS mv ON (md.ID = mv.Model_ID)  
                            LEFT JOIN sram AS sr ON (sr.IsVirtualRoot = 1) --We treat virtual roots as entity-agnostic, so grab ALL of them for this DH  
                            WHERE  
                                dh.ID = @DerivedHierarchy_ID AND   
                                mv.ID = @Version_ID  
                        )';  
                  
            --Loop through each level in the current hierarchy, generating the dynamic @SQL clause as a CTE for each level  
            DECLARE @ID INT, @LastUsedLevelAlias NVARCHAR(35), @LastUsedEntity_ID INT;  
            WHILE EXISTS(SELECT 1 FROM #dhLevel WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID AND IsProcessed = 0) BEGIN  
                  
                --Get the next level in the current hierarchy  
                SELECT TOP 1   
                    @ID = ID,  
                    @LastUsedEntity_ID = Entity_ID,   
                    @LastUsedLevelAlias = N'L' + CONVERT(NVARCHAR(30), Level_ID)  
                FROM #dhLevel   
                WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID AND IsProcessed = 0  
                ORDER BY Level_ID DESC; --MDS derived hierarchies are declared upside-down, so the top level entity is last  
                  
                --Generate the level details and join clause. Joins are different depending  
                --on whether it is the first, or a subsequent level.  
                SELECT @SQL = @SQL + N',  
                        ' + quotename(@LastUsedLevelAlias) + N' AS  
                        (    --' + EntityName + N'  
                            SELECT      
                                kid.ID,  
                                CASE --Recursively inherit Privilege_ID following the specified rules  
                                    WHEN mom.Privilege_ID = 1 THEN 1 --Inherited explicit DENY trumps any given security on child  
                                    ELSE ISNULL(sr.Privilege_ID, mom.Privilege_ID) --Else use the most recent (closest) assignment  
                                END AS Privilege_ID, --case  
                                CASE --Distance to most recently (closest) assigned node (NULL=none, 0=self)  
                                    WHEN mom.Privilege_ID = 1 THEN 0 --Since an inherited explicit DENY trumps all, treat it as a local assignment  
                                    WHEN sr.Privilege_ID IS NULL THEN mom.Delta_ID + 1 --If no local assignment, get distance to closest inherited assignment          
                                    ELSE 0 --Reset distance to 0, since current node has an explicit assignment  
                                END AS Delta_ID --case' +  
                    --The top-most level has no DBA by definition, so use that fact to identify it.  
                    --We could have checked instead for MAX(Level_ID)==N but this is simpler & more efficient.  
                    CASE WHEN DbaEntity_ID IS NULL THEN N'  
                            FROM virtualRoots AS mom  
                            INNER JOIN mdm.' + QUOTENAME(EntityTable) + N' AS kid ON (kid.Version_ID = @Version_ID AND kid.Status_ID = 1)'  
                    ELSE N'  
                            FROM L' + CONVERT(NVARCHAR(30), DbaLevel_ID) + N' AS mom  
                            INNER JOIN mdm.' + QUOTENAME(EntityTable) + N' AS kid ON (kid.Version_ID = @Version_ID AND mom.ID = kid.' + QUOTENAME(DbaColumn) + N' AND kid.Status_ID = 1)'  
                    END + N'  
                            LEFT JOIN sram AS sr ON (sr.Entity_ID = ' + CONVERT(NVARCHAR(30), Entity_ID) + N' AND sr.EN_ID = kid.ID)  
                        )'  
                FROM #dhLevel WHERE ID = @ID;  
                  
                --Update the loop counter  
                UPDATE #dhLevel SET IsProcessed = 1 WHERE ID = @ID;  
                                  
                --Don't go any lower down the hierarchy tree than the requested entity (save some processing)  
                IF (@LastUsedEntity_ID = @Entity_ID) BREAK;  
                  
            END; --while  
              
            --Since we can exit the inner loop early, make sure all unprocessed rows are deleted else the outer loop will spin  
            --Do NOT delete from #dhLevel since the data is also used in the generatded @SQL. Instead flag it as completed.  
            UPDATE #dhLevel SET IsProcessed = 1 WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID;  
              
            --Add the boiler-plate SQL code to navigate the derived hierarchy.  
            --Since the Privilege_ID enum is not in the order of least-privilege, we need to   
            --swap read(3->2) & write(2->3) to make the sorting operation work. We swap them back   
            --when we are complete.          
            SET @SQL = @SQL + N',  
                        closestLeastPriv AS   
                        (    --Only keep rows with explicit assignments in their ancestor path.   
                            --Sort each node by the roles it belongs to, with the smallest distance at the top  
                            SELECT  
                                ROW_NUMBER() OVER(PARTITION BY ID ORDER BY Delta_ID ASC) AS Sequence_ID,  
                                ID, Delta_ID, Privilege_ID  
                            FROM ' + quotename(@LastUsedLevelAlias) + N' WHERE Delta_ID IS NOT NULL  
                        )  
                        --Insert into the staging table, ensuring that the closest (most recent)   
                        --explicitly-assigned permissions trump any inherited permissions.  
                        INSERT INTO #map(SecurityRole_ID, MemberType_ID, EN_ID, Privilege_ID, PrivilegeSortOrder)  
                        SELECT   
                            @SecurityRole_ID, 1, ID,  
                            Privilege_ID,  
                            CASE Privilege_ID WHEN 2 THEN 3 WHEN 3 THEN 2 ELSE Privilege_ID END --Swap 2 & 3 so least privilege sorting works  
                        FROM closestLeastPriv AS clp  
                        WHERE Sequence_ID = 1; --Only keep the most recent (closest) assignment  
          
                        PRINT ''' + QUOTENAME(@table_MS) + N': DH (#'' + CONVERT(NVARCHAR(30), @DerivedHierarchy_ID) + N''): '' + CONVERT(NVARCHAR(30), @@ROWCOUNT);  
                        PRINT CONVERT(NVARCHAR(MAX),GETDATE(), 108);  
                ';  
  
            --Loop through each SecurityRole_ID of the current derived hierarchy  
            --The SQL statement that we execute is the same for each role, so this is a small, tight loop              
            WHILE EXISTS(SELECT 1 FROM #assignments WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID AND IsProcessed = 0) BEGIN  
              
                SELECT TOP 1 @SecurityRole_ID = SecurityRole_ID FROM #assignments WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID AND IsProcessed = 0 ORDER BY SecurityRole_ID;  
                  
                --Execute the dynamic SQL  
                --PRINT @SQL  
                EXEC sp_executesql @SQL, N'@Version_ID INT, @Entity_ID INT, @DerivedHierarchy_ID INT, @SecurityRole_ID INT', @Version_ID, @Entity_ID, @DerivedHierarchy_ID, @SecurityRole_ID;  
                  
                UPDATE #assignments SET IsProcessed = 1 WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID AND SecurityRole_ID = @SecurityRole_ID;  
              
            END; --while  
                          
        END; --while  
      
    END; --if  
  
      
    /*=================================================================  
      Load _MS tables  
      =================================================================*/  
  
    --DECLARE @MapCount INT = 0;  
    --SELECT @MapCount = COUNT(*) FROM #map;  
    --PRINT N'@#map row count before de-duplication: ' + CONVERT(NVARCHAR, COALESCE(@MapCount, N'NULL'));  
    DECLARE @StartTime DATETIME2 = CURRENT_TIMESTAMP;  
  
    --Remove any duplicates due to members occuring in multiple hierarchies with the same Delta_ID, in the same role.  
    --In other words, the same member (eg) 917 could occur twice but with different Privilege_ID.  
    --Keep the row with the least privilege.  
    DELETE FROM a  
    FROM #map AS a  
    INNER JOIN #map AS b ON   
    (  
            a.SecurityRole_ID = b.SecurityRole_ID  
        AND a.MemberType_ID = b.MemberType_ID  
        AND COALESCE(a.EN_ID, 0) = COALESCE(b.EN_ID, 0)  
        AND COALESCE(a.HP_ID, 0) = COALESCE(b.HP_ID, 0)  
        AND (    a.PrivilegeSortOrder > b.PrivilegeSortOrder  
             OR (a.PrivilegeSortOrder = b.PrivilegeSortOrder AND a.ID > b.ID)  -- If multiple rows have the same sort order, delete all but the first duplicate row.  
            )  
    );  
    PRINT N'Remove duplicates from #map, elapsed time: ' + CONVERT(NVARCHAR, DATEDIFF(MS, @StartTime, CURRENT_TIMESTAMP) / 1000.0) + N' sec';  
    --SELECT @MapCount = COUNT(*) FROM #map;  
    --PRINT N'@#map row count after de-duplication: ' + CONVERT(NVARCHAR, COALESCE(@MapCount, N'NULL'));  
  
    --ALWAYS do the next step, even in #map is empty. An empty #map means that  
    --there is no security anymore, so any existing _MS rows should be deleted.  
    --MERGE the #map table into the final _MS member table. Since the staging table  
    --will contain many duplicate and overlapping hierarchies & members, use a  
    --GROUPing clause to make sure that the maximum permission is granted for  
    --overlapping roles. Use an indexed staging table, else a non-indexed MERGE   
    --is very expensive      
    SET @SQL = @TruncationGuard + N'  
        --Ensure we are using the READ COMMITTED level so that we can use SNAPSHOT functionality  
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;  
          
        --DECLARE @MapCount INT = 0;  
        --SELECT @MapCount = COUNT(*) FROM mdm.' + QUOTENAME(@table_MS) + N' WHERE Version_ID = @Version_ID;  
        --PRINT N''MS table row count: '' + CONVERT(NVARCHAR, COALESCE(@MapCount, N''NULL''));  
  
        -- Update the MS table. There are two possible approaches:  
        --    1. DELETE all of the existing rows in the MS table for the specified version and INSERT all of the #map rows into the MS table, or  
        --    2. MERGE #map with the MS table.  
        -- When there are few differences between the MS table and #map, option #2 is *much* faster (5-8 times faster in a test scenario with 3M rows) than #1.   
        -- However, on a test run when all 3M rows were different, #2 was about 1.5-2.5 times slower than #1. So measure how different #map is from the MS table  
        -- to determine which approach to use.  
        DECLARE @DeleteCount    INT,  
                @InsertCount    INT,  
                @UpdateCount    INT,  
                @NoChangeCount  INT;  
  
        DECLARE @StartTime DATETIME2 = CURRENT_TIMESTAMP;  
        WITH targetFilteredByVersion AS -- Get the rows from the MS table that pertain to the specified version  
        (  
            SELECT SecurityRole_ID, MemberType_ID, EN_ID, HP_ID, Privilege_ID  
            FROM mdm.' + QUOTENAME(@table_MS) + N'  
            WHERE Version_ID = @Version_ID  
        )  
        SELECT  
            @DeleteCount    = SUM(CASE WHEN source.SecurityRole_ID IS NULL              THEN 1 ELSE 0 END),  
            @InsertCount    = SUM(CASE WHEN target.SecurityRole_ID IS NULL              THEN 1 ELSE 0 END),  
            @UpdateCount    = SUM(CASE WHEN target.Privilege_ID <> source.Privilege_ID  THEN 1 ELSE 0 END),  
            @NoChangeCount  = SUM(CASE WHEN target.Privilege_ID = source.Privilege_ID   THEN 1 ELSE 0 END)  
        FROM targetFilteredByVersion AS target  
        FULL JOIN #map AS source  
        ON (    target.SecurityRole_ID      = source.SecurityRole_ID  
            AND target.MemberType_ID        = source.MemberType_ID  
            AND COALESCE(target.EN_ID, 0)   = COALESCE(source.EN_ID, 0)  
            AND COALESCE(target.HP_ID, 0)   = COALESCE(source.HP_ID, 0))  
  
        PRINT N''Count differences, elapsed time: '' + CONVERT(NVARCHAR, DATEDIFF(MS, @StartTime, CURRENT_TIMESTAMP) / 1000.0) + N'' sec'';  
        PRINT N''@DeleteCount = ''   + COALESCE(CONVERT(NVARCHAR, @DeleteCount),   N''NULL'');  
        PRINT N''@InsertCount = ''   + COALESCE(CONVERT(NVARCHAR, @InsertCount),   N''NULL'');  
        PRINT N''@UpdateCount = ''   + COALESCE(CONVERT(NVARCHAR, @UpdateCount),   N''NULL'');  
        PRINT N''@NoChangeCount = '' + COALESCE(CONVERT(NVARCHAR, @NoChangeCount), N''NULL'');  
  
        DECLARE @TotalChangeCount INT = (@DeleteCount + @InsertCount + @UpdateCount);  
        SET @StartTime = CURRENT_TIMESTAMP;  
        IF @TotalChangeCount > 0 -- If there are no changes, then do nothing.  
        BEGIN  
            IF @TotalChangeCount > (@NoChangeCount / 2) -- This heuristic determines which approach to use.  
            BEGIN  
                -- There are at least twice as many changed rows as unchanged rows, so doing DELETE-INSERT will probably be faster than doing MERGE.  
                DELETE FROM mdm.' + QUOTENAME(@table_MS) + N' WHERE Version_ID = @Version_ID;  
  
                INSERT INTO mdm.' + QUOTENAME(@table_MS) + N'  
                       (Version_ID, SecurityRole_ID, MemberType_ID, EN_ID, HP_ID, Privilege_ID)  
                SELECT @Version_ID, SecurityRole_ID, MemberType_ID, EN_ID, HP_ID, Privilege_ID  
                FROM #map;  
  
                PRINT N''DELETE-INSERT elapsed time: '' + CONVERT(NVARCHAR, DATEDIFF(MS, @StartTime, CURRENT_TIMESTAMP)/1000.0) + N'' sec'';  
            END ELSE  
            BEGIN  
                -- There are twice as many (or more) unchanged rows as changed rows, so doing MERGE will probably be faster than doing DELETE-INSERT.  
                MERGE mdm.' + QUOTENAME(@table_MS) + N' AS target  
                USING #map AS source  
                ON (target.SecurityRole_ID      = source.SecurityRole_ID AND  
                    target.MemberType_ID        = source.MemberType_ID AND  
                    -- Note that Version_ID does not need to be included in the matching criteria because two different versions of the same member will   
                    -- have different IDs. Thus, it is sufficient to match on EN_ID and HP_ID.  
                    COALESCE(target.EN_ID, 0)   = COALESCE(source.EN_ID, 0) AND  
                    COALESCE(target.HP_ID, 0)   = COALESCE(source.HP_ID, 0))  
                WHEN MATCHED AND target.Privilege_ID <> source.Privilege_ID THEN  
                    UPDATE SET target.Privilege_ID = source.Privilege_ID  
                WHEN NOT MATCHED BY TARGET THEN  
                    INSERT (Version_ID,  SecurityRole_ID,        MemberType_ID,        EN_ID,        HP_ID,        Privilege_ID)  
                    VALUES (@Version_ID, source.SecurityRole_ID, source.MemberType_ID, source.EN_ID, source.HP_ID, source.Privilege_ID)  
                WHEN NOT MATCHED BY SOURCE AND target.Version_ID = @Version_ID /*Do not delete rows pertaining to other versions*/ THEN  
                    DELETE;  
              
                PRINT N''MERGE elapsed time: '' + CONVERT(NVARCHAR, DATEDIFF(MS, @StartTime, CURRENT_TIMESTAMP)/1000.0) + N'' sec'';  
            END;  
        END  
  
        --Output statistics for performance & debugging reasons  
        PRINT N''' + QUOTENAME(@table_MS) + N': MS (All): '' + CONVERT(NVARCHAR(30), @@ROWCOUNT);  
        PRINT CONVERT(NVARCHAR(MAX),GETDATE(), 108);  
        --Clean up  
        DROP TABLE #map;  
        ';  
  
    --PRINT @SQL;  
    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;  
    PRINT 'Creating member security items for Entity_ID: ' + CONVERT(NVARCHAR(30), @Entity_ID) + ' and Version_ID: ' + CONVERT(NVARCHAR(30), @Version_ID) + ' finished at: ' + CONVERT(NVARCHAR(30), GETDATE(), 108);  
      
    --Update the status of all the SRAM rows we have used, to flag that they have been used in  
    --at least one processing operation. This flag does not signify that the processing is   
    --complete and/or up to date, it just states that this has happened once.  
    UPDATE sram SET   
        IsInitialized = 1  
    FROM mdm.tblSecurityRoleAccessMember AS sram  
    INNER JOIN #assignments AS asg ON sram.ID = asg.SRAM_ID  
    WHERE asg.IsProcessed = 1;  
  
    --Now that member security has been processed, clear the applicable cached member counts.  
    DECLARE @FilterByUser BIT =  
        CASE WHEN (SELECT COUNT(*) FROM @UserIdList) > 0 THEN 1 ELSE 0 END; -- If no users are specified, then clear cached member counts for all users.  
    UPDATE mc  
    SET  
        LastCount  = -1,  
        LastChgDTM = GETUTCDATE()  
    FROM mdm.tblUserMemberCount mc  
    LEFT JOIN @UserIdList u  
        ON mc.User_ID       = u.ID  
    WHERE  
            (@FilterByUser  = 0 OR u.ID IS NOT NULL)  
        AND mc.Version_ID   = @Version_ID   
        AND mc.Entity_ID    = @Entity_ID;  
    SET NOCOUNT OFF;  
END; --proc
GO
