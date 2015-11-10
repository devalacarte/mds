SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*    
==============================================================================    
 Copyright (c) Microsoft Corporation. All Rights Reserved.    
==============================================================================    
  
Description: Bulk hierarchy relationship moves.    
    
The following are assumed validated prior to calling and are not validated here:    
    * User    
    * Version    
    * Entity    
        
declare     
    @HierarchyMembers AS mdm.HierarchyMembers    
    
insert into @HierarchyMembers(ChildCode, TargetCode, TargetType_ID, HierarchyName) values (N'FR-M94S-38', N'B', 1, N'Index'); -- Move to different parent.    
insert into @HierarchyMembers(ChildCode, TargetCode, TargetType_ID, HierarchyName) values (N'XXXXXXXXX', N'B', 1, N'Index'); -- Invalid child code.    
insert into @HierarchyMembers(ChildCode, TargetCode, TargetType_ID, HierarchyName) values (N'FR-R38B-44', N'XXXXXXXXX', 1, N'Index'); -- Invalid parent code.    
insert into @HierarchyMembers(ChildCode, TargetCode, TargetType_ID, HierarchyName) values (N'FR-M63B-40', N'B', 1, N'XXXXXXXXX'); -- Invalid hierarchy name.    
    
EXEC mdm.udpHierarchyMembersUpdate @User_ID=1, @Version_ID = 20, @Entity_ID = 31, @HierarchyMembers = @HierarchyMembers, @LogFlag = 1    
    
*/    
CREATE PROCEDURE [mdm].[udpHierarchyMembersUpdate]  
(    
    @User_ID                INT,    
    @Version_ID             INT,    
    @Entity_ID              INT,    
    @HierarchyMembers       mdm.HierarchyMembers READONLY,   
    @OriginalTransaction_ID INT = NULL, -- The original transaction ID that is being reversed. Leave NULL if this change is not a transaction reversal.  
    @LogFlag                INT = NULL, --1 = log the transaction; anything else = do not log  
    @IsCreateMode           BIT = 0 -- Set to 1 when calling this sproc as part of creating an entity member. This will mean relaxed security checks, such as allowing nodes to be moved from ROOT, even if the user doesn't have Update permission on ROOT  
)    
WITH EXECUTE AS 'mds_schema_user'    
AS     
BEGIN    
    SET NOCOUNT ON;    
  
    DECLARE     
         @SQL                       NVARCHAR(MAX)    
        ,@ParamList                 NVARCHAR(max)       
        ,@TranCounter               INT     
        ,@ChildAttributeColumnName  sysname    
    
        ,@TableName                 sysname    
        ,@ParentChildViewName       sysname    
        ,@EntityTable               sysname    
        ,@HierarchyTable            sysname    
        ,@HierarchyParentTable      sysname    
        ,@CollectionTable           sysname    
        ,@SecurityTable             sysname    
        ,@IsFlat                    BIT    
            
        ,@TargetType_Parent         INT = 1    
        ,@TargetType_Sibling        INT = 2    
            
        ,@TransactionType_HierarchyParentSet    INT = 4    
        ,@TransactionType_HierarchySiblingSet   INT = 5    
    
        --Member Types    
        ,@MemberType_Unknown        INT = 0    
        ,@MemberType_Leaf           INT = 1    
        ,@MemberType_Consolidated   INT = 2    
    
        --Permissions    
        ,@Permission_Deny           INT = 1    
        ,@Permission_Update         INT = 2    
        ,@Permission_ReadOnly       INT = 3    
        ,@Permission_Inferred       INT = 99    
  
        --Security Levels    
        ,@SecurityLevel             TINYINT    
        ,@SecLvl_NoAccess           TINYINT = 0    
        ,@SecLvl_ObjectSecurity     TINYINT = 1    
        ,@SecLvl_MemberSecurity     TINYINT = 2    
        ,@SecLvl_ObjectAndMemberSecurity TINYINT = 3    
  
        --Member status  
        ,@Status_Inactive           TINYINT = 2  
  
        --Top-level node ids and codes  
        ,@RootCode                  NVARCHAR(10) = N'ROOT'  
        ,@Root_ID                   INT = 0  
        ,@UnusedCode                NVARCHAR(10) = N'MDMUNUSED'  
        ,@Unused_ID                 INT = -1  
            
        --Error ObjectTypes    
        ,@ObjectType_Entity         INT = 5    
        ,@ObjectType_Hierarchy      INT = 6    
        ,@ObjectType_Attribute      INT = 7    
        ,@ObjectType_MemberCode     INT = 12    
        ,@ObjectType_MemberId       INT = 19    
        ,@ObjectType_MemberAttribute INT = 22    
    
        --Error Codes    
        ,@ErrorCode_NoPermissionForThisOperationOnThisObject    INT = 120003    
        ,@ErrorCode_ConsolidatedMemberCannotBeChildOfMdmUnused  INT = 210059  
        ,@ErrorCode_InvalidMemberCode                           INT = 300002    
        ,@ErrorCode_InvalidExplicitHierarchy                    INT = 300009    
        ,@ErrorCode_ReadOnlyMember                              INT = 300015    
        ,@ErrorCode_MemberCausesCircularReference               INT = 300020    
    
        ,@MemberIds                mdm.MemberId    
    ;    
  
    -- Get the roles that pertain to the user.  
    DECLARE @SecurityRoles TABLE(RoleID INT PRIMARY KEY);  
    INSERT INTO @SecurityRoles    
    SELECT DISTINCT Role_ID FROM mdm.[viw_SYSTEM_SECURITY_USER_ROLE] WHERE User_ID = @User_ID;  
  
    DECLARE  
         @strRoot_ID                    NVARCHAR(3) = CONVERT(NVARCHAR(3), @Root_ID)  
        ,@strUnused_ID                  NVARCHAR(3) = CONVERT(NVARCHAR(3), @Unused_ID)  
        ,@strStatus_Inactive            NVARCHAR(3) = CONVERT(NVARCHAR(3), @Status_Inactive)  
        ,@strMemberType_Leaf            NVARCHAR(3) = CONVERT(NVARCHAR(3), @MemberType_Leaf)  
        ,@strMemberType_Consolidated    NVARCHAR(3) = CONVERT(NVARCHAR(3), @MemberType_Consolidated);  
  
    --Final results to be returned.    
    CREATE TABLE #HierarchyMemberWorkingSet    
        (    
          Row_ID                    INT IDENTITY(1,1) NOT NULL    
         ,Hierarchy_ID              INT NULL    
         ,HierarchyName             NVARCHAR(50) COLLATE DATABASE_DEFAULT NULL  
         ,Child_ID                  INT NULL    
         ,ChildCode                 NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL  
         ,ChildMemberType_ID        INT NULL    
         ,Target_ID                 INT NULL    
         ,TargetCode                NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL  
         ,TargetMemberType_ID       INT NULL    
         ,TargetType_ID             INT NULL    
         ,Parent_ID                 INT NULL    
         ,ParentCode                NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL  
         ,PriorParent_ID            INT NULL    
         ,PriorParentCode           NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL  
         ,PriorParentHierarchy_ID   INT NULL -- Used for detecting when a consolidated member is being moved to another hierarchy. Otherwise, will be the same as the Hierarchy_ID column.  
         ,PriorSortOrder            INT NULL  
         ,SortOrder                 INT NULL    
         ,RelativeSortOrder         INT NULL    
         ,Member_ID                 INT NULL --Member Id in error    
         ,MemberCode                NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL --Member code in error    
         ,MemberType_ID             INT NULL --Member Type in error    
         ,ErrorCode                 INT NULL    
         ,ErrorObjectType           INT NULL    
        );    
  
    --Intermediate working set    
    CREATE TABLE #HierarchyMemberWorkingSet2    
        (    
          Row_ID                INT IDENTITY(1,1) NOT NULL    
         ,Hierarchy_ID          INT NULL    
         ,HierarchyName         NVARCHAR(50) COLLATE DATABASE_DEFAULT NULL    
         ,Child_ID              INT NULL    
         ,ChildCode             NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL    
         ,ChildMemberType_ID    INT NULL    
         ,Target_ID             INT NULL    
         ,TargetCode            NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL    
         ,TargetMemberType_ID   INT NULL    
         ,TargetType_ID         INT NULL    
         ,Parent_ID             INT NULL    
         ,ParentCode            NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL    
         ,PriorParent_ID        INT NULL    
         ,PriorParentCode       NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL    
         ,PriorSortOrder        INT NULL  
         ,SortOrder             INT NULL    
         ,RelativeSortOrder     INT NULL    
         ,ErrorCode             INT NULL    
         ,ErrorObjectType       INT NULL    
        );    
    
    --Stores the transactions of the hierarchy member UPDATEs    
    CREATE TABLE #HierarchyMemberTransactions    
        (    
         TransactionType INT    
        ,Hierarchy_ID    INT    
        ,ChildType_ID    TINYINT     
        ,Child_EN_ID     INT NULL    
        ,Child_HP_ID     INT NULL    
        ,ChildCode       NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL  
        ,PriorParent_ID  INT NULL    
        ,PriorParentCode NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL    
        ,NewParent_ID    INT NULL    
        ,NewParentCode   NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL    
        );    
    
    ----------------------------------------------------------------------------------------    
    --Get Entity table information.    
    ----------------------------------------------------------------------------------------    
    SELECT    
        @EntityTable = Quotename(EntityTable),    
        @HierarchyTable = Quotename(HierarchyTable),    
        @HierarchyParentTable = Quotename(HierarchyParentTable),    
        @CollectionTable = Quotename(CollectionTable),    
        @SecurityTable = Quotename(SecurityTable),    
        @IsFlat = IsFlat    
    FROM         
        mdm.tblEntity WHERE ID = @Entity_ID;    
        
    IF @IsFlat = 1 BEGIN    
        RAISERROR('MDSERR310021|For consolidated members, the entity must be enabled for hierarchies and collections.', 16, 1);  
        RETURN;    
    END;    
    
    SELECT @ParentChildViewName = Quotename(mdm.udfViewNameGetByID(@Entity_ID, 4, 0));    
  
    ----------------------------------------------------------------------------------------    
    -- Insert hierarchy members into working set.    
    ----------------------------------------------------------------------------------------    
    INSERT INTO #HierarchyMemberWorkingSet    
        (Hierarchy_ID, HierarchyName, Child_ID, ChildCode, ChildMemberType_ID, Target_ID, TargetCode, TargetMemberType_ID, TargetType_ID)    
    SELECT    
          NULLIF(hm.Hierarchy_ID, 0)    
         ,hm.HierarchyName    
         ,hm.Child_ID    
         ,hm.ChildCode    
         ,hm.ChildMemberType_ID    
         ,hm.Target_ID    
         ,hm.TargetCode    
         ,hm.TargetMemberType_ID    
         ,hm.TargetType_ID    
    FROM @HierarchyMembers AS hm    
  
    ----------------------------------------------------------------------------------------    
    --Get Member ID, Code, and Type    
    ----------------------------------------------------------------------------------------    
    -- Check for top-level nodes.  
    UPDATE #HierarchyMemberWorkingSet    
    SET    Target_ID = CASE UPPER(TargetCode) WHEN @RootCode THEN @Root_ID WHEN @UnusedCode THEN @Unused_ID END,    
        TargetMemberType_ID = @MemberType_Consolidated    
    WHERE UPPER(TargetCode) IN (@RootCode, @UnusedCode)  
      
    UPDATE #HierarchyMemberWorkingSet    
    SET    TargetCode = CASE Target_ID WHEN @Root_ID THEN @RootCode WHEN @Unused_ID THEN @UnusedCode END,    
        TargetMemberType_ID = @MemberType_Consolidated    
    WHERE Target_ID IN (@Root_ID, @Unused_ID)  
      
    IF EXISTS(SELECT * FROM #HierarchyMemberWorkingSet ws WHERE COALESCE(ws.Target_ID, 0) = 0 OR ws.TargetCode IS NULL OR COALESCE(ws.Child_ID, 0) = 0 OR ws.ChildCode IS NULL)  
        BEGIN  
            --Get Target IDs for leaf targets  
            IF EXISTS(SELECT * FROM #HierarchyMemberWorkingSet ws WHERE ws.TargetMemberType_ID IS NULL OR (ws.Target_ID IS NULL AND ws.TargetCode IS NOT NULL AND ws.TargetMemberType_ID = @strMemberType_Leaf))  
                BEGIN  
                    SET @SQL = N'    
                        UPDATE ws    
                        SET ws.Target_ID = m.ID,  
                            ws.TargetMemberType_ID = ' + @strMemberType_Leaf + N'    
                        FROM #HierarchyMemberWorkingSet AS ws    
                        INNER JOIN mdm.' + @EntityTable + N' AS m                            
                            ON m.Version_ID = @Version_ID  
                            AND m.Status_ID IS NOT NULL  
                            AND m.Status_ID = 1  
                            AND ws.TargetCode IS NOT NULL  
                            AND ws.TargetCode = m.Code  
                            AND ws.ErrorCode IS NULL    
                            AND ws.Target_ID IS NULL;';    
                    --PRINT(@SQL);    
                    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;    
                END  
  
            --Get Target Codes for leaf targets  
            IF EXISTS(SELECT * FROM #HierarchyMemberWorkingSet ws WHERE ws.TargetMemberType_ID IS NULL OR (ws.TargetCode IS NULL AND ws.Target_ID IS NOT NULL AND ws.TargetMemberType_ID = @strMemberType_Leaf))  
                BEGIN  
                    SET @SQL = N'    
                        UPDATE ws    
                        SET ws.TargetCode = m.Code,  
                            ws.TargetMemberType_ID = ' + @strMemberType_Leaf + N'    
                        FROM #HierarchyMemberWorkingSet AS ws    
                        INNER JOIN mdm.' + @EntityTable + N' AS m                            
                            ON m.Version_ID = @Version_ID  
                            AND m.Status_ID IS NOT NULL  
                            AND m.Status_ID = 1  
                            AND ws.Target_ID IS NOT NULL  
                            AND ws.Target_ID = m.ID  
                            AND ws.ErrorCode IS NULL    
                            AND ws.TargetCode IS NULL;';    
                    --PRINT(@SQL);    
                    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;    
                END  
             
           --Get Target IDs for consolidated targets  
            IF EXISTS(SELECT * FROM #HierarchyMemberWorkingSet ws WHERE ws.TargetMemberType_ID IS NULL OR (ws.Target_ID IS NULL AND ws.TargetCode IS NOT NULL AND ws.TargetMemberType_ID = @strMemberType_Consolidated))  
                BEGIN  
                    SET @SQL = N'    
                        UPDATE ws    
                        SET ws.Target_ID = m.ID,  
                            ws.TargetMemberType_ID = ' + @strMemberType_Consolidated + N'    
                        FROM #HierarchyMemberWorkingSet AS ws    
                        INNER JOIN mdm.' + @HierarchyParentTable + N' AS m    
                            ON m.Version_ID = @Version_ID  
                            AND m.Status_ID IS NOT NULL  
                            AND m.Status_ID = 1  
                            AND ws.TargetCode IS NOT NULL  
                            AND ws.TargetCode = m.Code  
                            AND ws.ErrorCode IS NULL    
                            AND ws.Target_ID IS NULL;';    
                    --PRINT(@SQL);    
                    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;    
                END  
  
           --Get Target Codes for consolidated targets  
            IF EXISTS(SELECT * FROM #HierarchyMemberWorkingSet ws WHERE ws.TargetMemberType_ID IS NULL OR (ws.TargetCode IS NULL AND ws.Target_ID IS NOT NULL AND ws.TargetMemberType_ID = @strMemberType_Consolidated))  
                BEGIN  
                    SET @SQL = N'    
                        UPDATE ws    
                        SET ws.TargetCode = m.Code,    
                            ws.TargetMemberType_ID = ' + @strMemberType_Consolidated + N'    
                        FROM #HierarchyMemberWorkingSet AS ws    
                        INNER JOIN mdm.' + @HierarchyParentTable + N' AS m    
                            ON m.Version_ID = @Version_ID  
                            AND m.Status_ID IS NOT NULL  
                            AND m.Status_ID = 1  
                            AND ws.Target_ID IS NOT NULL  
                            AND ws.Target_ID = m.ID  
                            AND ws.ErrorCode IS NULL    
                            AND ws.Target_ID IS NULL;';    
                    --PRINT(@SQL);    
                    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;    
                END  
    
            --Get Child IDs for leaf children  
            IF EXISTS(SELECT * FROM #HierarchyMemberWorkingSet ws WHERE ws.ChildMemberType_ID IS NULL OR (ws.Child_ID IS NULL AND ws.ChildCode IS NOT NULL AND ws.ChildMemberType_ID = @strMemberType_Leaf))  
                BEGIN  
                    SET @SQL = N'    
                        UPDATE ws    
                        SET ws.Child_ID = m.ID,  
                            ws.ChildMemberType_ID = ' + @strMemberType_Leaf + N'                            
                        FROM #HierarchyMemberWorkingSet AS ws    
                        INNER JOIN mdm.' + @EntityTable + N' AS m    
                            ON m.Version_ID = @Version_ID   
                            AND m.Status_ID IS NOT NULL  
                            AND m.Status_ID = 1  
                            AND ws.ChildCode IS NOT NULL  
                            AND ws.ChildCode = m.Code  
                            AND ws.Child_ID IS NULL  
                            AND ws.ErrorCode IS NULL;';    
                    --PRINT(@SQL);    
                    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;    
                END  
  
            --Get Child Codes for leaf children  
            IF EXISTS(SELECT * FROM #HierarchyMemberWorkingSet ws WHERE ws.ChildMemberType_ID IS NULL OR (ws.ChildCode IS NULL AND ws.Child_ID IS NOT NULL AND ws.ChildMemberType_ID = @strMemberType_Leaf))  
                BEGIN  
                    SET @SQL = N'    
                        UPDATE ws    
                        SET ws.ChildCode = m.Code,  
                            ws.ChildMemberType_ID = ' + @strMemberType_Leaf + N'                            
                        FROM #HierarchyMemberWorkingSet AS ws    
                        INNER JOIN mdm.' + @EntityTable + N' AS m    
                            ON m.Version_ID = @Version_ID   
                            AND m.Status_ID IS NOT NULL  
                            AND m.Status_ID = 1  
                            AND ws.Child_ID IS NOT NULL  
                            AND ws.Child_ID = m.ID  
                            AND ws.ChildCode IS NULL  
                            AND ws.ErrorCode IS NULL;';    
                    --PRINT(@SQL);    
                    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;    
                END  
    
            --Get Child IDs for consolidated children  
            IF EXISTS(SELECT * FROM #HierarchyMemberWorkingSet ws WHERE ws.ChildMemberType_ID IS NULL OR (ws.Child_ID IS NULL AND ws.ChildCode IS NOT NULL AND ws.ChildMemberType_ID = @strMemberType_Consolidated))  
                BEGIN  
                    SET @SQL = N'    
                        UPDATE ws    
                        SET ws.Child_ID = m.ID,  
                            ws.ChildMemberType_ID = ' + @strMemberType_Consolidated + N'    
                        FROM #HierarchyMemberWorkingSet AS ws    
                        INNER JOIN mdm.' + @HierarchyParentTable + N' AS m    
                            ON m.Version_ID = @Version_ID   
                            AND m.Status_ID IS NOT NULL  
                            AND m.Status_ID = 1  
                            AND ws.ChildCode IS NOT NULL  
                            AND ws.ChildCode = m.Code  
                            AND ws.Child_ID IS NULL  
                            AND ws.ErrorCode IS NULL;';    
                    --PRINT(@SQL);    
                    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;    
                END  
  
            --Get Child Codes for consolidated children  
            IF EXISTS(SELECT * FROM #HierarchyMemberWorkingSet ws WHERE ws.ChildMemberType_ID IS NULL OR (ws.ChildCode IS NULL AND ws.Child_ID IS NOT NULL AND ws.ChildMemberType_ID = @strMemberType_Consolidated))  
                BEGIN  
                    SET @SQL = N'    
                        UPDATE ws    
                        SET ws.ChildCode = m.Code,    
                            ws.ChildMemberType_ID = ' + @strMemberType_Consolidated + N'    
                        FROM #HierarchyMemberWorkingSet AS ws    
                        INNER JOIN mdm.' + @HierarchyParentTable + N' AS m    
                            ON m.Version_ID = @Version_ID   
                            AND m.Status_ID IS NOT NULL  
                            AND m.Status_ID = 1  
                            AND ws.Child_ID IS NOT NULL  
                            AND ws.Child_ID = m.ID  
                            AND ws.ChildCode IS NULL  
                            AND ws.ErrorCode IS NULL;';    
                    --PRINT(@SQL);    
                    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;    
                END  
        END  
  
    -- Invalid member code check    
    UPDATE #HierarchyMemberWorkingSet      
        SET ErrorCode = @ErrorCode_InvalidMemberCode,    
            ErrorObjectType = @ObjectType_MemberCode,    
            MemberCode = TargetCode,    
            MemberType_ID = @MemberType_Unknown    
    WHERE TargetCode IS NOT NULL AND Target_ID IS NULL    
    AND   ErrorCode IS NULL;    
    
    UPDATE #HierarchyMemberWorkingSet      
        SET ErrorCode = @ErrorCode_InvalidMemberCode,    
            ErrorObjectType = @ObjectType_MemberCode,    
            MemberCode = ChildCode,    
            MemberType_ID = @MemberType_Unknown    
    WHERE ChildCode IS NOT NULL AND Child_ID IS NULL    
    AND   ErrorCode IS NULL;    
  
    ----------------------------------------------------------------------------------------    
    -- Check object and member security  
    ----------------------------------------------------------------------------------------    
    --Check security level before going any further.    
    EXEC mdm.udpSecurityLevelGet @User_ID, @Entity_ID, @SecurityLevel OUTPUT;  
    SET @SecurityLevel = COALESCE(@SecurityLevel, @SecLvl_NoAccess);  
    
    IF @SecurityLevel = @SecLvl_NoAccess BEGIN    
        IF EXISTS(SELECT 1 FROM #HierarchyMemberWorkingSet WHERE ChildMemberType_ID = @MemberType_Leaf) BEGIN    
            --Flag Child leaf member types with deny permissions    
            UPDATE ws    
            SET ErrorCode = @ErrorCode_NoPermissionForThisOperationOnThisObject,    
                ErrorObjectType = @ObjectType_MemberCode,    
                MemberCode = ChildCode,    
                MemberType_ID = @MemberType_Leaf    
            FROM #HierarchyMemberWorkingSet ws    
            WHERE ws.ChildMemberType_ID = @MemberType_Leaf;    
        END;    
    
        IF EXISTS(SELECT 1 FROM #HierarchyMemberWorkingSet WHERE TargetMemberType_ID = @MemberType_Leaf) BEGIN    
            --Flag Target leaf member types with deny permissions    
            UPDATE ws    
            SET ErrorCode = @ErrorCode_NoPermissionForThisOperationOnThisObject,    
                ErrorObjectType = @ObjectType_MemberCode,    
                MemberCode = TargetCode,    
                MemberType_ID = @MemberType_Leaf    
            FROM #HierarchyMemberWorkingSet ws    
            WHERE ws.TargetMemberType_ID = @MemberType_Leaf;    
        END;    
    
        IF EXISTS(SELECT 1 FROM #HierarchyMemberWorkingSet WHERE ChildMemberType_ID = @MemberType_Consolidated) BEGIN    
            --Flag Child leaf member types with deny permissions    
            UPDATE ws    
            SET ErrorCode = @ErrorCode_NoPermissionForThisOperationOnThisObject,    
                ErrorObjectType = @ObjectType_MemberCode,    
                MemberCode = ChildCode,    
                MemberType_ID = @MemberType_Consolidated    
            FROM #HierarchyMemberWorkingSet ws    
            WHERE ws.ChildMemberType_ID = @MemberType_Consolidated    
            AND ws.ErrorCode IS NULL;    
        END;    
    
        IF EXISTS(SELECT 1 FROM #HierarchyMemberWorkingSet WHERE TargetMemberType_ID = @MemberType_Consolidated) BEGIN    
            --Flag Target leaf member types with deny permissions    
            UPDATE ws    
            SET ErrorCode = @ErrorCode_NoPermissionForThisOperationOnThisObject,    
                ErrorObjectType = @ObjectType_MemberCode,    
                MemberCode = TargetCode,    
                MemberType_ID = @MemberType_Consolidated    
            FROM #HierarchyMemberWorkingSet ws    
            WHERE ws.TargetMemberType_ID = @MemberType_Consolidated    
            AND ws.ErrorCode IS NULL;    
        END;    
    END ELSE  
    BEGIN  
  
        --Lookup hierarchy IDs  
        IF @SecurityLevel IN (@SecLvl_ObjectSecurity, @SecLvl_ObjectAndMemberSecurity)    
        BEGIN    
            --Get hierarchies based on user's permissions  
            UPDATE ws  
            SET ws.Hierarchy_ID = h.ID  
            FROM #HierarchyMemberWorkingSet ws  
            INNER JOIN mdm.tblHierarchy h  
                ON h.Name = ws.HierarchyName  
            INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY sec  
                ON h.ID = sec.ID  
                AND sec.User_ID = @User_ID  
            WHERE   
                h.Entity_ID = @Entity_ID  
                AND ws.ErrorCode IS NULL;  
        END ELSE BEGIN    
            --No object security so get hierarchy IDs straight from table.  
            UPDATE ws  
            SET ws.Hierarchy_ID = h.ID  
            FROM #HierarchyMemberWorkingSet ws  
            INNER JOIN mdm.tblHierarchy h  
                ON h.Name = ws.HierarchyName  
            WHERE   
                h.Entity_ID = @Entity_ID  
                AND ws.ErrorCode IS NULL;  
        END    
    
        -- Flag any invalid hierarchy names  
        UPDATE #HierarchyMemberWorkingSet  
        SET ErrorCode = @ErrorCode_InvalidExplicitHierarchy,  
            ErrorObjectType = @ObjectType_Hierarchy  
        WHERE   
            Hierarchy_ID IS NULL  
            AND ErrorCode IS NULL;  
  
        ----------------------------------------------------------------------------------------  
        -- Lookup Parent_ID from Target_ID  
        ----------------------------------------------------------------------------------------          
        -- TargetType is Sibling  
        IF EXISTS(SELECT 1 FROM #HierarchyMemberWorkingSet WHERE TargetType_ID = @TargetType_Sibling AND ErrorCode IS NULL)  
        BEGIN  
            SET @SQL = N'  
                    UPDATE ws  
                    SET   
                        ws.Parent_ID = hr.Parent_ID,  
                        ws.ParentCode = hr.Parent_Code  
                    FROM mdm.' + @ParentChildViewName + N' AS hr  
                    INNER JOIN #HierarchyMemberWorkingSet AS ws  
                        ON  hr.Version_ID = @Version_ID  
                        AND hr.Hierarchy_ID = ws.Hierarchy_ID  
                        AND hr.Child_ID = ws.Target_ID  
                        AND hr.ChildType_ID = ws.TargetMemberType_ID  
                        AND ws.ErrorCode IS NULL  
                        AND ws.TargetType_ID = @TargetType_Sibling  
                    ';  
            SET @ParamList = N'@Version_ID INT, @TargetType_Sibling INT';  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @TargetType_Sibling;  
              
            -- For members being moved to unused node, overwrite null parent ID and Code with correct values.  
            UPDATE #HierarchyMemberWorkingSet  
            SET   
                Parent_ID = @Unused_ID,  
                ParentCode = @UnusedCode  
            WHERE  
                ErrorCode IS NULL AND  
                TargetType_ID = @TargetType_Sibling AND  
                Parent_ID IS NULL  
        END;  
    
        -- TargetType is Parent  
        UPDATE #HierarchyMemberWorkingSet  
        SET   
            Parent_ID = COALESCE(Target_ID, @Unused_ID),  
            ParentCode = COALESCE(TargetCode, @UnusedCode)  
        WHERE  
            ErrorCode IS NULL AND  
            TargetType_ID = @TargetType_Parent  
  
        -- Ensure no consolidated members are being moved under MDMUNUSED (not supported)  
        UPDATE #HierarchyMemberWorkingSet   
            SET ErrorCode = @ErrorCode_ConsolidatedMemberCannotBeChildOfMdmUnused  
        WHERE  
                ErrorCode IS NULL  
            AND Parent_ID = @Unused_ID  
            AND ChildMemberType_ID = @MemberType_Consolidated  
  
        ----------------------------------------------------------------------------------------  
        -- Lookup prior parent info.  
        ----------------------------------------------------------------------------------------  
        -- Note that when a member is assigned to ROOT, there will be a row in the HR table whose Parent_HP_ID column is null.  
        -- But when a member is assigned to MDMUNUSED, there will be no row in the HR table.  
        -- Also, unlike leaf members, consolidated members can only be in one hierarchy at a time. If a consolidated member is  
        -- being moved and its new parent is in a different hierarchy than prior hierarchy, then record the prior parent's hierarchy id.  
        SET @SQL = N'  
        -- Get prior parent info for Leaf members  
        UPDATE ws  
        SET  
             ws.PriorParent_ID = COALESCE(hr.Parent_HP_ID, ' + @strRoot_ID + N')  
            ,ws.PriorParentCode = COALESCE(hp.Code, N''' + @RootCode + N''')  
            ,ws.PriorParentHierarchy_ID = hr.Hierarchy_ID -- For leaf members ws.PriorParentHierarchy_ID will be the same as ws.Hierarchy_ID.  
            ,ws.PriorSortOrder = hr.SortOrder  
        FROM #HierarchyMemberWorkingSet AS ws  
        INNER JOIN mdm.' + @HierarchyTable + N' hr   
        ON      ws.Child_ID = hr.Child_EN_ID  
            AND ws.ChildMemberType_ID = hr.ChildType_ID  
            AND ws.Hierarchy_ID =  hr.Hierarchy_ID -- Leaf members can be in all hierarchies, so only match with HR row that pertain to the hierarchy specified in the working set row.  
        LEFT JOIN mdm.' + @HierarchyParentTable + N' hp  
            ON      hr.Parent_HP_ID = hp.ID  
                AND hr.Version_ID = hp.Version_ID  
        WHERE  
                ws.ErrorCode IS NULL  
            AND ws.ChildMemberType_ID = ' + @strMemberType_Leaf + N'  
            AND hr.Version_ID = @Version_ID  
  
        -- Get prior parent info for Consolidated members  
        UPDATE ws  
        SET  
             ws.PriorParent_ID = COALESCE(hr.Parent_HP_ID, ' + @strRoot_ID + N')  
            ,ws.PriorParentCode = COALESCE(hp.Code, N''' + @RootCode + N''')  
            ,ws.PriorParentHierarchy_ID = hr.Hierarchy_ID -- ws.PriorParentHierarchy_ID will be the same as ws.Hierarchy_ID, except for Consolidated members moving to a different hierarchy.  
            ,ws.PriorSortOrder = hr.SortOrder  
        FROM #HierarchyMemberWorkingSet AS ws  
        INNER JOIN mdm.' + @HierarchyTable + N' hr  
        ON      ws.Child_ID = hr.Child_HP_ID  
            AND ws.ChildMemberType_ID = hr.ChildType_ID  
            -- No need to add ws.Hierarchy_ID to the JOIN condition since Consolidated (unlike Leaf) members can only belong to a single hierarchy.  
        LEFT JOIN mdm.' + @HierarchyParentTable + N' hp  
            ON      hr.Parent_HP_ID = hp.ID  
                AND hr.Version_ID = hp.Version_ID  
        WHERE  
                ws.ErrorCode IS NULL  
            AND ws.ChildMemberType_ID = ' + @strMemberType_Consolidated + N'  
            AND hr.Version_ID = @Version_ID  
        ';  
        SET @ParamList = N'@Version_ID INT';  
        EXEC sp_executesql @SQL, @ParamList, @Version_ID;  
  
        -- If the previous query didn't find a prior parent for a child, then set its prior parent to MDMUNUSED.  
        UPDATE ws  
        SET  
             ws.PriorParent_ID = @Unused_ID  
            ,ws.PriorParentCode = @UnusedCode  
        FROM #HierarchyMemberWorkingSet AS ws  
        WHERE  
                ws.ErrorCode IS NULL  
            AND ws.PriorParent_ID IS NULL;  
  
        ----------------------------------------------------------------------------------------  
        -- Check Child, Target (sibling only), Parent, and Prior Parent permissions.  
        ----------------------------------------------------------------------------------------  
        -- Object Permissions.  Mark any members the user doesn't have permission to.    
        IF @SecurityLevel IN (@SecLvl_ObjectSecurity, @SecLvl_ObjectAndMemberSecurity)    
        BEGIN    
            -- Flag Child members without Update object permissions.  
            UPDATE ws  
            SET  
                 ErrorCode =  
                    CASE COALESCE(sec.Privilege_ID, @Permission_Deny)  
                        WHEN @Permission_ReadOnly THEN @ErrorCode_ReadOnlyMember  
                        WHEN @Permission_Inferred THEN @ErrorCode_ReadOnlyMember  
                        ELSE @ErrorCode_NoPermissionForThisOperationOnThisObject  
                    END   
                ,ErrorObjectType = @ObjectType_MemberCode  
                ,MemberCode = ChildCode  
                ,MemberType_ID = ChildMemberType_ID  
            FROM #HierarchyMemberWorkingSet ws  
            LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE sec  
            ON ws.ChildMemberType_ID = sec.ID  
            WHERE   
                    ws.ErrorCode IS NULL  
                AND sec.Entity_ID = @Entity_ID  
                AND sec.User_ID = @User_ID  
                AND COALESCE(sec.Privilege_ID, @Permission_Deny) <> @Permission_Update;  
  
            -- Flag Target (sibling only) members that don't have at least Read object permission (Read permission is sufficient for the sibling, so long as the parent has Update).  
            UPDATE ws  
            SET  
                 ErrorCode = @ErrorCode_NoPermissionForThisOperationOnThisObject  
                ,ErrorObjectType = @ObjectType_MemberCode  
                ,MemberCode = TargetCode  
                ,MemberType_ID = TargetMemberType_ID  
            FROM #HierarchyMemberWorkingSet ws  
            LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE sec  
            ON ws.TargetMemberType_ID = sec.ID  
            WHERE   
                    ws.ErrorCode IS NULL  
                AND ws.TargetType_ID = @TargetType_Sibling -- Only check sibling target types. Parent target types will be checked below.  
                AND sec.Entity_ID = @Entity_ID  
                AND sec.User_ID = @User_ID  
                AND COALESCE(sec.Privilege_ID, @Permission_Deny) = @Permission_Deny;  
  
            -- Flag Parent members without Update object permissions. This also covers Prior Parent.  
            DECLARE @EntityConsolidatedPermission INT = @Permission_Deny;  
            SELECT  
                @EntityConsolidatedPermission = COALESCE(sec.Privilege_ID, @Permission_Deny)  
            FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE sec  
            WHERE  
                sec.ID = @MemberType_Consolidated  
                AND sec.Entity_ID = @Entity_ID  
                AND sec.User_ID = @User_ID;  
            IF @EntityConsolidatedPermission <> @Permission_Update  
            BEGIN  
                UPDATE ws  
                SET  
                     ErrorCode =  
                        CASE COALESCE(@EntityConsolidatedPermission, @Permission_Deny)  
                            WHEN @Permission_ReadOnly THEN @ErrorCode_ReadOnlyMember  
                            WHEN @Permission_Inferred THEN @ErrorCode_ReadOnlyMember  
                            ELSE @ErrorCode_NoPermissionForThisOperationOnThisObject  
                        END   
                    ,ErrorObjectType = @ObjectType_MemberCode  
                    ,MemberCode = ParentCode  
                    ,MemberType_ID = @MemberType_Consolidated  
                FROM #HierarchyMemberWorkingSet ws  
                WHERE   
                        ws.ErrorCode IS NULL  
                    AND ws.Parent_ID <> @Root_ID; -- ROOT ignores MemberType permission, since it is a virtual member.  
            END;  
        END;  
  
        --Check Member Permissions.  Mark any members the user doesn't have permission to.  
        IF @SecurityLevel IN (@SecLvl_MemberSecurity, @SecLvl_ObjectAndMemberSecurity)  
        BEGIN  
            -- Create temp table for storing member permissions.  
            CREATE TABLE #MemberPermissions  
            (  
                ID              INT,  
                MemberType_ID   INT,  
                Privilege_ID    INT  
            );  
            CREATE UNIQUE CLUSTERED INDEX #ix_MemberPermissions_ID_MemberType_ID ON #MemberPermissions(ID, MemberType_ID);  
  
            -- Get a list of all distinct hierarchy IDs in the input  
            DECLARE @Hierarchy_ID INT = NULL;  
            DECLARE @HierarchyIds TABLE (Hierarchy_ID INT NOT NULL PRIMARY KEY);  
            INSERT INTO @HierarchyIds (Hierarchy_ID)  
            SELECT DISTINCT ws.Hierarchy_ID   
            FROM #HierarchyMemberWorkingSet ws  
            WHERE   
                    ws.ErrorCode IS NULL  
                AND ws.Hierarchy_ID IS NOT NULL  
            UNION  
            SELECT DISTINCT ws.PriorParentHierarchy_ID AS Hierarchy_ID   
            FROM #HierarchyMemberWorkingSet ws  
            WHERE   
                    ws.ErrorCode IS NULL  
                AND ws.PriorParentHierarchy_ID IS NOT NULL;  
  
            -- Loop through each hierarchy and lookup member permissions (note that the ROOT node could have differing permissions in different hierarchies)  
            WHILE EXISTS (SELECT 1 FROM @HierarchyIds)  
            BEGIN  
                -- Get the next hierarchy in the list.  
                SELECT TOP 1   
                    @Hierarchy_ID = Hierarchy_ID  
                FROM @HierarchyIds;  
                DELETE FROM @HierarchyIds WHERE Hierarchy_ID = @Hierarchy_ID;  
  
                -- Get the member ids that pertain to the hierarchy.  
                DELETE FROM @MemberIds;  
                INSERT INTO @MemberIds (ID, MemberType_ID)  
                SELECT -- Sibling targets  
                     Target_ID  
                    ,TargetMemberType_ID  
                FROM #HierarchyMemberWorkingSet  
                WHERE   
                        Target_ID IS NOT NULL  
                    AND TargetType_ID = @TargetType_Sibling  
                    AND Hierarchy_ID = @Hierarchy_ID  
                    AND ErrorCode IS NULL  
                UNION  
                SELECT -- Parents  
                     Parent_ID  
                    ,@MemberType_Consolidated  
                FROM #HierarchyMemberWorkingSet  
                WHERE   
                        Parent_ID IS NOT NULL  
                    AND Hierarchy_ID = @Hierarchy_ID  
                    AND ErrorCode IS NULL  
                UNION  
                SELECT -- Prior Parents  
                     PriorParent_ID  
                    ,@MemberType_Consolidated  
                FROM #HierarchyMemberWorkingSet  
                WHERE   
                        PriorParent_ID IS NOT NULL  
                    AND PriorParentHierarchy_ID = @Hierarchy_ID  
                    AND ErrorCode IS NULL  
                UNION  
                SELECT -- Children  
                     Child_ID  
                    ,ChildMemberType_ID  
                FROM #HierarchyMemberWorkingSet  
                WHERE  
                        Child_ID IS NOT NULL  
                    AND Hierarchy_ID = @Hierarchy_ID  
                    AND ErrorCode IS NULL;  
    
                IF EXISTS (SELECT 1 FROM @MemberIds)  
                BEGIN  
                    -- Get member permissions. It it necessary to do this once per hierarchy because each hierarchy has its   
                    -- own ROOT node, each with its own permissions.  
                    DELETE FROM #MemberPermissions;  
                    INSERT INTO #MemberPermissions  
                    EXEC mdm.udpSecurityMembersResolverGet @User_ID, @Version_ID, @Entity_ID, @MemberIds, @Hierarchy_ID;  
                
                    -- Flag Child members without Update member permission.  
                    UPDATE ws  
                    SET  
                         ErrorCode =  
                            CASE COALESCE(sec.Privilege_ID, @Permission_Deny)  
                                WHEN @Permission_ReadOnly THEN @ErrorCode_ReadOnlyMember  
                                WHEN @Permission_Inferred THEN @ErrorCode_ReadOnlyMember  
                                ELSE @ErrorCode_NoPermissionForThisOperationOnThisObject  
                            END  
                        ,ErrorObjectType = @ObjectType_MemberCode  
                        ,MemberCode = ChildCode  
                        ,MemberType_ID = ChildMemberType_ID  
                    FROM #HierarchyMemberWorkingSet ws  
                    LEFT JOIN #MemberPermissions sec  
                    ON   
                            ws.Child_ID = sec.ID  
                        AND ws.ChildMemberType_ID = sec.MemberType_ID  
                    WHERE   
                            ws.ErrorCode IS NULL  
                        AND ws.Hierarchy_ID = @Hierarchy_ID  
                        AND COALESCE(sec.Privilege_ID, @Permission_Deny) <> @Permission_Update;  
  
                    -- Flag Target (sibling only) members that don't have at least Read member permission (Read permission is sufficient for the sibling, so long as the parent has Update).  
                    UPDATE ws  
                    SET  
                         ErrorCode = @ErrorCode_NoPermissionForThisOperationOnThisObject  
                        ,ErrorObjectType = @ObjectType_MemberCode  
                        ,MemberCode = TargetCode  
                        ,MemberType_ID = TargetMemberType_ID  
                    FROM #HierarchyMemberWorkingSet ws  
                    LEFT JOIN #MemberPermissions sec  
                    ON   
                            ws.Target_ID = sec.ID  
                        AND ws.TargetMemberType_ID = sec.MemberType_ID  
                    WHERE   
                            ws.ErrorCode IS NULL  
                        AND ws.TargetType_ID = @TargetType_Sibling -- Only check sibling target types. Parent target types will be checked below.  
                        AND ws.Hierarchy_ID = @Hierarchy_ID  
                        AND COALESCE(sec.Privilege_ID, @Permission_Deny) = @Permission_Deny;  
  
                    -- Flag Parent members without Update member permissions.  
                    UPDATE ws  
                    SET  
                         ErrorCode =  
                            CASE COALESCE(sec.Privilege_ID, @Permission_Deny)  
                                WHEN @Permission_ReadOnly THEN @ErrorCode_ReadOnlyMember  
                                WHEN @Permission_Inferred THEN @ErrorCode_ReadOnlyMember  
                                ELSE @ErrorCode_NoPermissionForThisOperationOnThisObject  
                            END  
                        ,ErrorObjectType = @ObjectType_MemberCode  
                        ,MemberCode = ParentCode  
                        ,MemberType_ID = @MemberType_Consolidated  
                    FROM #HierarchyMemberWorkingSet ws  
                    LEFT JOIN #MemberPermissions sec  
                    ON   
                            ws.Parent_ID = sec.ID  
                        AND @MemberType_Consolidated = sec.MemberType_ID  
                    WHERE   
                            ws.ErrorCode IS NULL  
                        AND ws.Hierarchy_ID = @Hierarchy_ID  
                        AND COALESCE(sec.Privilege_ID, @Permission_Deny) <> @Permission_Update;  
  
                    -- Flag Prior Parent members without Update member permissions.  
                    UPDATE ws  
                    SET  
                         ErrorCode =  
                            CASE COALESCE(sec.Privilege_ID, @Permission_Deny)  
                                WHEN @Permission_ReadOnly THEN @ErrorCode_ReadOnlyMember  
                                WHEN @Permission_Inferred THEN @ErrorCode_ReadOnlyMember  
                                ELSE @ErrorCode_NoPermissionForThisOperationOnThisObject  
                            END  
                        ,ErrorObjectType = @ObjectType_MemberCode  
                        ,MemberCode = PriorParentCode  
                        ,MemberType_ID = @MemberType_Consolidated  
                    FROM #HierarchyMemberWorkingSet ws  
                    LEFT JOIN #MemberPermissions sec  
                    ON   
                            ws.PriorParent_ID = sec.ID  
                        AND @MemberType_Consolidated = sec.MemberType_ID  
                    WHERE   
                            ws.ErrorCode IS NULL  
                        AND ws.PriorParentHierarchy_ID = @Hierarchy_ID  
                        AND (COALESCE(@IsCreateMode, 0) = 0 OR ws.PriorParent_ID <> @Root_ID) -- When in create mode allow moves from ROOT, even if ROOT doesn't have update permission.  
                        AND COALESCE(sec.Privilege_ID, @Permission_Deny) <> @Permission_Update;  
                END;  
            END; -- while  
        END;  
  
        -- Flag duplicate rows (i.e. rows that move the same member within the same hierarchy)  
        WITH cteDuplicates AS  
        (  
            SELECT  
                 ws.Child_ID  
                ,ws.Hierarchy_ID  
                ,ws.ChildMemberType_ID  
            FROM #HierarchyMemberWorkingSet ws  
            GROUP BY   
                 ws.Child_ID  
                ,ws.Hierarchy_ID  
                ,ws.ChildMemberType_ID  
            HAVING COUNT(ws.Child_ID) > 1  
        )          
        UPDATE ws  
        SET  
            ws.ErrorCode = @ErrorCode_InvalidMemberCode,  
            ws.ErrorObjectType = @ObjectType_MemberCode,    
            ws.MemberCode = ws.ChildCode,    
            ws.MemberType_ID = ws.ChildMemberType_ID  
        FROM #HierarchyMemberWorkingSet ws  
        INNER JOIN cteDuplicates dup  
        ON      ws.Child_ID = dup.Child_ID  
            AND ws.Hierarchy_ID = dup.Hierarchy_ID  
            AND ws.ChildMemberType_ID = dup.ChildMemberType_ID  
  
        -- Check for and prevent circular relationships.  
        CREATE TABLE #CircularRelationships (Row_ID INT PRIMARY KEY);  
        SET @SQL =N'  
        WITH cteConsolidatedChildren AS -- Get all consolidated children being moved to a new parent  
        (  
            SELECT  
                 Row_ID  
                ,Child_ID  
                ,Parent_ID  
            FROM #HierarchyMemberWorkingSet  
            WHERE   
                    ErrorCode IS NULL        -- Ignore rows that already have an error  
                AND ChildMemberType_ID = ' + @strMemberType_Consolidated + N' -- Only look at consolidated child members (moving a leaf member cannot create a circular reference)  
        )  
        ,cteParents AS -- Get all parent assignments. New parent assignments (in the working set) trump existing assignments (in the HR table).  
        (  
            SELECT  
                 hr.Child_HP_ID Child_ID  
                ,COALESCE(ws.Parent_ID, hr.Parent_HP_ID) Parent_ID -- Use the existing parent only if a new parent is not defined in the working set.  
            FROM ' + @HierarchyTable + N' hr  
            LEFT JOIN cteConsolidatedChildren ws   
                ON hr.Child_HP_ID = ws.Child_ID  
            WHERE COALESCE(ws.Parent_ID, hr.Parent_HP_ID) IS NOT NULL -- For efficiency, exclude null parents since they cannot be part of a circular relationship.  
        )  
        ,cteAncestors AS -- Recursively find each new ancestor (from the new parent on up) of each consolidated member being moved.  
        (  
            SELECT  
                 Row_ID  
                ,Child_ID  
                ,Parent_ID Ancestor_ID  
                ,0 [Level]  
            FROM cteConsolidatedChildren  
              
            UNION ALL  
              
            SELECT  
                 a.Row_ID   
                ,a.Child_ID  
                ,hr.Parent_ID Ancestor_ID   
                ,a.[Level] + 1 [Level]  
            FROM cteAncestors a  
            INNER JOIN cteParents hr  
                ON a.Ancestor_ID = hr.Child_ID  
            WHERE  
                    a.[Level] < 99 -- Protects against "The statement terminated. The maximum recursion 100 has been exhausted before statement completion" error.  
                AND a.Child_ID <> a.Ancestor_ID -- End the recursion once a circular relationship has been found.  
        )  
        INSERT INTO #CircularRelationships (Row_ID)  
        SELECT DISTINCT Row_ID  
        FROM cteAncestors   
        WHERE Child_ID = Ancestor_ID;-- If the move would make the consolidated member its own ancestor, then it would create a circular relationship.  
        ';  
        --PRINT @SQL;  
        EXEC sp_executesql @SQL;  
  
        UPDATE ws    
        SET  
            ws.ErrorCode = @ErrorCode_MemberCausesCircularReference,  
            ws.ErrorObjectType = @ObjectType_MemberCode,    
            ws.MemberCode = ws.ChildCode,    
            ws.MemberType_ID = @MemberType_Consolidated    
        FROM #HierarchyMemberWorkingSet AS ws   
        INNER JOIN #CircularRelationships cir  
            ON ws.Row_ID = cir.Row_ID   
  
    END;  
        
    --Exit now if we have no members to update because user doesn't have necessary security or invalid member codes.  
    IF NOT EXISTS(SELECT 1 FROM #HierarchyMemberWorkingSet WHERE ErrorCode IS NULL) BEGIN    
        SELECT DISTINCT     
             HierarchyName    
            ,ChildCode    
            ,COALESCE(ChildMemberType_ID,0) AS ChildMemberType_ID    
            ,TargetCode    
            ,COALESCE(TargetMemberType_ID,0) AS TargetMemberType_ID    
            ,ErrorCode    
            ,ErrorObjectType    
            ,MemberCode -- Member code in error    
            ,MemberType_ID -- Member type in error    
            ,NULL AS MemberName    
        FROM #HierarchyMemberWorkingSet    
        WHERE ErrorCode IS NOT NULL;    
        RETURN(0);    
    END    
  
    --Start transaction, being careful to check if we are nested    
    SET @TranCounter = @@TRANCOUNT;    
    IF @TranCounter > 0 SAVE TRANSACTION TX;    
    ELSE BEGIN TRANSACTION;    
    
    --get an applock to help avoid deadlocks    
    DECLARE @lock INT;    
    EXEC @lock = sp_getapplock     
                    @Resource=N'Mds_Hierarchy_Save',     
                    @LockMode=N'Exclusive',    
                    @LockOwner=N'Transaction',    
                    @LockTimeout=10000,    
                    @DbPrincipal=N'public';    
    
    --0 and 1 are acceptable return codes from sp_getapplock    
    IF @lock NOT IN (0,1) BEGIN    
        RAISERROR(N'Unable to acquire Lock', 16, 1);    
    END    
    ELSE BEGIN TRY   
  
        /*    
        Check to see if a consolidated relationship exists for ANY hierarchy besides the one in this save process.      
        If so the consolidated member is being moved from one hierarchy to another.      
        Move all children in old hierarchy to Root and remove record.    
        */                              
        IF EXISTS(    
            SELECT 1     
            FROM #HierarchyMemberWorkingSet  
            WHERE ChildMemberType_ID = @MemberType_Consolidated  
            AND Hierarchy_ID IS NOT NULL  
            AND ErrorCode IS NULL  
            )     
        BEGIN    
            INSERT INTO #HierarchyMemberWorkingSet2  
                (Child_ID, ChildMemberType_ID, Hierarchy_ID)  
            SELECT   
                Child_ID,  
                ChildMemberType_ID,  
                Hierarchy_ID  
            FROM #HierarchyMemberWorkingSet  
            WHERE  
                    ChildMemberType_ID = @MemberType_Consolidated  
                AND Hierarchy_ID <> PriorParentHierarchy_ID  
                AND Hierarchy_ID IS NOT NULL  
                AND ErrorCode IS NULL;  
  
            IF EXISTS (SELECT 1 FROM #HierarchyMemberWorkingSet2)  
            BEGIN  
                SET @SQL = N'    
                    --Move to ROOT                      
                    UPDATE hr SET     
                        hr.Parent_HP_ID = NULL    
                    FROM mdm.' + @HierarchyTable + N' AS hr    
                    INNER JOIN #HierarchyMemberWorkingSet2 hm    
                    ON  ((hr.Parent_HP_ID IS NULL AND hm.Child_ID IS NULL) OR (hm.Child_ID IS NOT NULL AND hr.Parent_HP_ID = hm.Child_ID))     
                    AND Version_ID =  @Version_ID;    
                        
                        
                    DELETE hr    
                    FROM mdm.' + @HierarchyTable + N' AS hr    
                    INNER JOIN #HierarchyMemberWorkingSet2 hm    
                    ON    hr.ChildType_ID = hm.ChildMemberType_ID     
                    AND hm.Child_ID = CASE hr.ChildType_ID WHEN ' + @strMemberType_Leaf + N' THEN hr.Child_EN_ID WHEN ' + @strMemberType_Consolidated + N' THEN hr.Child_HP_ID END     
                    AND Version_ID = @Version_ID;    
    
                    UPDATE hp SET     
                        hp.Hierarchy_ID = hm.Hierarchy_ID    
                    FROM mdm.' + @HierarchyParentTable + N' AS hp    
                    INNER JOIN #HierarchyMemberWorkingSet2 hm    
                    ON ((hp.ID IS NULL AND hm.Child_ID IS NULL) OR (hm.Child_ID IS NOT NULL AND hp.ID = hm.Child_ID))     
                    AND Version_ID =  @Version_ID;';  
                --PRINT @SQL;    
                SET @ParamList = N'@Version_ID INT';                            
                EXEC sp_executesql @SQL, @ParamList, @Version_ID;    
            END;  
    
        END; --if    
  
        --Check to see if a relationship exists, if not create one.    
        SET @SQL = N'    
            DELETE FROM #HierarchyMemberWorkingSet2;    
              
            INSERT INTO #HierarchyMemberWorkingSet2 (Hierarchy_ID, Child_ID, ChildMemberType_ID)    
            SELECT    
                ws.Hierarchy_ID, ws.Child_ID, ws.ChildMemberType_ID    
            FROM #HierarchyMemberWorkingSet AS ws    
            LEFT OUTER JOIN mdm.' + @HierarchyTable + N' AS hr    
                ON hr.Version_ID = @Version_ID  
                AND hr.Hierarchy_ID = ws.Hierarchy_ID  
                AND hr.Child_EN_ID = ws.Child_ID  
                AND hr.ChildType_ID = ws.ChildMemberType_ID  
            WHERE hr.Hierarchy_ID IS NULL  
            AND ws.Hierarchy_ID IS NOT NULL  
            AND ws.ErrorCode IS NULL  
            AND ws.ChildMemberType_ID = ' + @strMemberType_Leaf + N';  
  
            INSERT INTO #HierarchyMemberWorkingSet2 (Hierarchy_ID, Child_ID, ChildMemberType_ID)    
            SELECT    
                ws.Hierarchy_ID, ws.Child_ID, ws.ChildMemberType_ID    
            FROM #HierarchyMemberWorkingSet AS ws    
            LEFT OUTER JOIN mdm.' + @HierarchyTable + N' AS hr    
                ON hr.Version_ID = @Version_ID  
                AND hr.Hierarchy_ID = ws.Hierarchy_ID  
                AND hr.Child_HP_ID = ws.Child_ID  
                AND hr.ChildType_ID = ws.ChildMemberType_ID  
            WHERE hr.Hierarchy_ID IS NULL  
            AND ws.Hierarchy_ID IS NOT NULL  
            AND ws.ErrorCode IS NULL  
            AND ws.ChildMemberType_ID = ' + @strMemberType_Consolidated + N';'    
    
        --PRINT @SQL        
        SET @ParamList = N'@Version_ID INT, @User_ID INT, @Entity_ID INT';    
        EXEC sp_executesql @SQL, @ParamList, @Version_ID, @User_ID, @Entity_ID;   
          
        IF EXISTS(SELECT 1 FROM #HierarchyMemberWorkingSet2)    
        BEGIN    
            DECLARE @HierarchyMembersCreate AS mdm.HierarchyMembers    
            INSERT INTO @HierarchyMembersCreate (Hierarchy_ID, Child_ID, ChildMemberType_ID)    
            SELECT Hierarchy_ID, Child_ID, ChildMemberType_ID FROM #HierarchyMemberWorkingSet2;    
            EXEC mdm.udpHierarchyMembersCreate @User_ID, @Version_ID, @Entity_ID, @HierarchyMembersCreate;   
        END;    
  
        --Delete relationship(move to Unused)    
        IF EXISTS(SELECT 1 FROM #HierarchyMemberWorkingSet WHERE COALESCE(Parent_ID, @Unused_ID) = @Unused_ID AND ErrorCode IS NULL)   
        BEGIN    
            SET @SQL = N'    
                DELETE hr    
                OUTPUT ' + CONVERT(NVARCHAR(2), @TransactionType_HierarchyParentSet) +  
                N', deleted.Hierarchy_ID, deleted.ChildType_ID, deleted.Child_EN_ID, deleted.Child_HP_ID, ws.ChildCode, COALESCE(deleted.Parent_HP_ID, ' + @strRoot_ID + N'), ws.PriorParentCode, ' + @strUnused_ID + N',N''' + @UnusedCode + N''' INTO #HierarchyMemberTransactions    
                FROM mdm.' + @HierarchyTable + N' AS hr    
                INNER JOIN #HierarchyMemberWorkingSet AS ws    
                ON    Version_ID = @Version_ID    
                AND   hr.Hierarchy_ID = ws.Hierarchy_ID     
                AND   COALESCE(ws.Parent_ID, ' + @strUnused_ID + N') = ' + @strUnused_ID + N'    
                AND   hr.ChildType_ID = ws.ChildMemberType_ID     
                AND   ws.Child_ID = CASE hr.ChildType_ID WHEN ' + @strMemberType_Leaf + N' THEN hr.Child_EN_ID WHEN ' + @strMemberType_Consolidated + N' THEN hr.Child_HP_ID END;';    
    
            SET @ParamList = N'@Version_ID INT';    
            EXEC sp_executesql @SQL,@ParamList, @Version_ID;    
        END; --if    
    
        ELSE IF EXISTS(SELECT 1 FROM #HierarchyMemberWorkingSet WHERE TargetType_ID = @TargetType_Parent AND ErrorCode IS NULL)   
        BEGIN --Parent    
            --Get relative sort orders              
            WITH cteRelativeSortOrder AS  
            (  
                SELECT ROW_NUMBER() OVER (PARTITION BY ws.Parent_ID ORDER BY ws.PriorSortOrder) AS RelativeSortOrder, ws.Hierarchy_ID, ws.ChildMemberType_ID, ws.Child_ID  
                    FROM #HierarchyMemberWorkingSet AS ws  
            )  
            UPDATE ws  
                SET ws.RelativeSortOrder = cteRelativeSortOrder.RelativeSortOrder  
                    FROM #HierarchyMemberWorkingSet ws  
                    INNER JOIN cteRelativeSortOrder  
                        ON cteRelativeSortOrder.Hierarchy_ID = ws.Hierarchy_ID    
                        AND cteRelativeSortOrder.ChildMemberType_ID = ws.ChildMemberType_ID    
                        AND cteRelativeSortOrder.Child_ID = ws.Child_ID;  
  
            SET @ParamList = N'@Version_ID INT, @TargetType_Parent INT';    
            EXEC sp_executesql @SQL,@ParamList, @Version_ID, @TargetType_Parent;    
  
            -- Get Sort order    
            SET @SQL = N'    
                WITH cte AS   
                (    
                    SELECT hr.Hierarchy_ID, hr.Parent_HP_ID AS Parent_ID, COALESCE(MAX(hr.SortOrder), 0) AS SortOrder    
                        FROM #HierarchyMemberWorkingSet AS ws  
                        LEFT JOIN mdm.' + @HierarchyTable + N' AS hr  
                            ON hr.Version_ID = @Version_ID    
                            AND hr.Hierarchy_ID = ws.Hierarchy_ID    
                            AND ((COALESCE(ws.Target_ID, 0) = 0 AND hr.Parent_HP_ID IS NULL) OR (ws.Target_ID = hr.Parent_HP_ID))    
                            AND ws.TargetType_ID = @TargetType_Parent    
                            AND ws.ErrorCode IS NULL    
                        GROUP BY hr.Hierarchy_ID, hr.Parent_HP_ID    
                )    
                UPDATE ws    
                    SET ws.SortOrder = (COALESCE(cte.SortOrder, 0) + COALESCE(ws.RelativeSortOrder, 0))  
                    FROM #HierarchyMemberWorkingSet AS ws     
                    LEFT JOIN cte    
                        ON cte.Hierarchy_ID = ws.Hierarchy_ID    
                        AND cte.Parent_ID = ws.Target_ID    
            ';    
                
            SET @ParamList = N'@Version_ID INT, @TargetType_Parent INT';    
            EXEC sp_executesql @SQL,@ParamList, @Version_ID, @TargetType_Parent;    
    
            -- Remove rows that are not actually moving the child.  
            DELETE FROM #HierarchyMemberWorkingSet  
            WHERE   
                    PriorParent_ID = Parent_ID  
                AND PriorSortOrder = SortOrder  
                AND PriorParentHierarchy_ID = Hierarchy_ID  
                AND ErrorCode IS NULL;  
  
            --Build the update string. Ensure a @Target_ID of zero is converted to NULL, which is    
            --the correct value for children of Root.   
            --EDM-1863: Also schedule the updated member for level recalculation during validation (assign LevelNumber = -1)    
            SET @SQL = N'    
                UPDATE hr    
                SET    
                    hr.Parent_HP_ID =  NULLIF(ws.Target_ID, ' + @strRoot_ID + N'),    
                    hr.SortOrder =  ws.SortOrder,    
                    hr.LastChgDTM = GETUTCDATE(),    
                    hr.LastChgUserID = @User_ID,    
                    hr.LastChgVersionID = @Version_ID,  
                    hr.LevelNumber = -1    
                OUTPUT ' + CONVERT(NVARCHAR(2), @TransactionType_HierarchyParentSet) +  
                N', inserted.Hierarchy_ID, inserted.ChildType_ID, inserted.Child_EN_ID, inserted.Child_HP_ID, ws.ChildCode, ws.PriorParent_ID, ws.PriorParentCode, COALESCE(inserted.Parent_HP_ID, ' + @strRoot_ID + N'), COALESCE(ws.ParentCode, N''' + @RootCode + N''') INTO #HierarchyMemberTransactions    
                FROM mdm.' + @HierarchyTable + N' AS hr    
                INNER JOIN #HierarchyMemberWorkingSet AS ws    
                    ON  hr.Version_ID = @Version_ID     
                    AND    hr.Hierarchy_ID = ws.Hierarchy_ID    
                    AND    hr.ChildType_ID = ws.ChildMemberType_ID    
                    AND    ws.Child_ID = CASE hr.ChildType_ID WHEN ' + @strMemberType_Leaf + N' THEN hr.Child_EN_ID WHEN ' + @strMemberType_Consolidated + N' THEN hr.Child_HP_ID END    
                    AND ws.TargetType_ID = ' + @strMemberType_Leaf + N'    
                    AND ws.ErrorCode IS NULL;';    
                          
            SET @ParamList = N'@User_ID INT, @Version_ID INT';    
            EXEC sp_executesql @SQL, @ParamList, @User_ID, @Version_ID;     
        END   
        ELSE IF EXISTS(SELECT 1 FROM #HierarchyMemberWorkingSet WHERE TargetType_ID = @TargetType_Sibling AND ErrorCode IS NULL)   
        BEGIN --Sibling    
    
            --Get relative sort orders  
            WITH cteRelativeSortOrder AS  
            (  
                SELECT ROW_NUMBER() OVER (PARTITION BY ws.Parent_ID ORDER BY ws.PriorSortOrder) AS RelativeSortOrder, ws.Hierarchy_ID, ws.ChildMemberType_ID, ws.Child_ID  
                    FROM #HierarchyMemberWorkingSet AS ws  
            )  
            UPDATE ws  
                SET ws.RelativeSortOrder = cteRelativeSortOrder.RelativeSortOrder  
                    FROM #HierarchyMemberWorkingSet ws  
                    INNER JOIN cteRelativeSortOrder  
                        ON cteRelativeSortOrder.Hierarchy_ID = ws.Hierarchy_ID    
                        AND cteRelativeSortOrder.ChildMemberType_ID = ws.ChildMemberType_ID    
                        AND cteRelativeSortOrder.Child_ID = ws.Child_ID;  
  
            SET @ParamList = N'@Version_ID INT';    
            EXEC sp_executesql @SQL,@ParamList, @Version_ID;  
  
            -- Get Sort order    
            SET @SQL = N'    
                WITH cte AS   
                (    
                    SELECT hr.Hierarchy_ID, hr.ChildType_ID, hr.Child_ID, COALESCE(MAX(hr.Child_SortOrder), 0) AS SortOrder    
                        FROM #HierarchyMemberWorkingSet AS ws  
                        LEFT JOIN mdm.' + @ParentChildViewName + N' AS hr    
                            ON Version_ID = @Version_ID    
                            AND hr.Hierarchy_ID = ws.Hierarchy_ID    
                            AND ((ws.Target_ID IS NULL AND hr.Child_ID IS NULL)    
                            OR (ws.Target_ID = hr.Child_ID))    
                            AND ws.TargetType_ID = ' + @strMemberType_Consolidated + N'    
                            AND ws.ErrorCode IS NULL    
                        GROUP BY hr.Hierarchy_ID, hr.ChildType_ID, hr.Child_ID    
                )    
                UPDATE ws    
                    SET ws.SortOrder = COALESCE(cte.SortOrder, 0) + COALESCE(ws.RelativeSortOrder, 0)  
                        FROM #HierarchyMemberWorkingSet AS ws     
                        LEFT JOIN cte    
                            ON cte.Hierarchy_ID = ws.Hierarchy_ID    
                            AND cte.ChildType_ID = ws.TargetMemberType_ID  
                            AND cte.Child_ID = ws.Target_ID    
            ';        
                
            SET @ParamList = N'@Version_ID INT';    
            EXEC sp_executesql @SQL,@ParamList, @Version_ID;    
            
          -- Remove rows that are not actually moving the child.  
            DELETE FROM #HierarchyMemberWorkingSet  
            WHERE   
                    PriorParent_ID = Parent_ID  
                AND PriorSortOrder = SortOrder  
                AND PriorParentHierarchy_ID = Hierarchy_ID  
                AND ErrorCode IS NULL;  
    
            --Update the childen SortOrder to Sort + Number of children pasted   
            SET @SQL = N'    
                WITH cteMaxRelativeSortOrder AS   
                (  
                    SELECT MAX(COALESCE(ws.RelativeSortOrder, 0)) as MaxRelativeSortOrder, Target_ID  
                        FROM #HierarchyMemberWorkingSet AS ws    
                            WHERE ws.TargetType_ID = ' + @strMemberType_Consolidated + N'  
                            AND ws.ErrorCode IS NULL  
                        GROUP BY ws.Target_ID  
                )  
                UPDATE hr    
                SET    
                    hr.SortOrder = (hr.SortOrder + COALESCE(cteMaxRelativeSortOrder.MaxRelativeSortOrder, 0)),    
                    hr.LastChgDTM = GETUTCDATE(),    
                    hr.LastChgUserID =  @User_ID,    
                    hr.LastChgVersionID =  @Version_ID     
                FROM #HierarchyMemberWorkingSet AS ws  
                LEFT JOIN mdm.' + @HierarchyTable + N' AS hr    
                    ON  hr.Version_ID = @Version_ID     
                    AND    hr.Hierarchy_ID = ws.Hierarchy_ID    
                    AND    ((COALESCE(ws.Parent_ID, 0) = 0 AND hr.Parent_HP_ID IS NULL) OR (ws.Parent_ID IS NOT NULL AND hr.Parent_HP_ID = ws.Parent_ID))     
                    AND ws.TargetType_ID = ' + @strMemberType_Consolidated + N'    
                    AND hr.SortOrder IS NOT NULL AND hr.SortOrder >= ws.SortOrder  
                    AND ws.ErrorCode IS NULL  
                LEFT JOIN cteMaxRelativeSortOrder  
                    ON cteMaxRelativeSortOrder.Target_ID = ws.Target_ID  
                    ;';  
    
            SET @ParamList = N'@User_ID INT, @Version_ID INT';      
            EXEC sp_executesql @SQL, @ParamList, @User_ID, @Version_ID;    
                  
            --Update the Member being Moved. Ensure a @Parent_ID of zero is converted to NULL, which is    
            --the correct value for children of Root.    
            --Schedule the updated member for level recalculation during validation (assign LevelNumber = -1)    
            SET @SQL = N'    
                UPDATE hr    
                SET    
                    hr.Parent_HP_ID =  NULLIF(ws.Parent_ID, ' + @strRoot_ID + N'),    
                    hr.SortOrder =  ws.SortOrder,    
                    hr.LastChgDTM = GETUTCDATE(),    
                    hr.LastChgUserID = @User_ID,    
                    hr.LastChgVersionID = @Version_ID,  
                    hr.LevelNumber = -1    
                OUTPUT ' + CONVERT(NVARCHAR(2), @TransactionType_HierarchySiblingSet) +  
                N', inserted.Hierarchy_ID, inserted.ChildType_ID, inserted.Child_EN_ID, inserted.Child_HP_ID, ws.ChildCode, ws.PriorParent_ID, ws.PriorParentCode, COALESCE(inserted.Parent_HP_ID, ' + @strRoot_ID + N'), COALESCE(ws.ParentCode, N''' + @RootCode + N''') INTO #HierarchyMemberTransactions    
                FROM mdm.' + @HierarchyTable + N' AS hr    
                INNER JOIN #HierarchyMemberWorkingSet AS ws    
                    ON  hr.Version_ID = @Version_ID     
                    AND    hr.Hierarchy_ID = ws.Hierarchy_ID    
                    AND    hr.ChildType_ID = ws.ChildMemberType_ID    
                    AND    ws.Child_ID = CASE hr.ChildType_ID WHEN ' + @strMemberType_Leaf + N' THEN hr.Child_EN_ID WHEN ' + @strMemberType_Consolidated + N' THEN hr.Child_HP_ID END    
                    AND ws.TargetType_ID = ' + @strMemberType_Consolidated + N'    
                    AND ws.ErrorCode IS NULL;';    
    
            SET @ParamList = N'@User_ID INT, @Version_ID INT';    
            EXEC sp_executesql @SQL, @ParamList, @User_ID, @Version_ID;    
  
        END; --if    
  
        --Log the transaction    
        IF @LogFlag = 1 BEGIN    
            INSERT INTO mdm.tblTransaction     
            (    
                Version_ID,    
                TransactionType_ID,    
                OriginalTransaction_ID,    
                Hierarchy_ID,    
                Entity_ID,    
                Member_ID,    
                MemberType_ID,    
                MemberCode,    
                OldValue,    
                OldCode,    
                NewValue,    
                NewCode,    
                EnterDTM,    
                EnterUserID,    
                LastChgDTM,    
                LastChgUserID    
            )    
            SELECT     
                @Version_ID     
                ,txn.TransactionType    
                ,COALESCE(@OriginalTransaction_ID, 0)  
                ,txn.Hierarchy_ID     
                ,@Entity_ID     
                ,CASE txn.ChildType_ID WHEN @MemberType_Leaf THEN txn.Child_EN_ID ELSE txn.Child_HP_ID END --Member_ID    
                ,txn.ChildType_ID --MemberType_ID    
                ,txn.ChildCode --MemberCode    
                ,COALESCE(txn.PriorParent_ID, @Unused_ID) --OldValue    
                ,CASE COALESCE(txn.PriorParent_ID, @Unused_ID) WHEN @Unused_ID THEN @UnusedCode WHEN @Root_ID THEN @RootCode ELSE txn.PriorParentCode END --OldCode    
                ,COALESCE(txn.NewParent_ID, @Unused_ID) --NewValue    
                ,CASE COALESCE(txn.NewParent_ID, @Unused_ID) WHEN @Unused_ID THEN @UnusedCode WHEN @Root_ID THEN @RootCode ELSE txn.NewParentCode END --NewCode    
                ,GETUTCDATE()     
                ,@User_ID      
                ,GETUTCDATE()     
                ,@User_ID     
            FROM #HierarchyMemberTransactions AS txn    
        END; --if @LogFlag    
  
        --Put a msg onto the SB queue to process member security    
        EXEC mdm.udpSecurityMemberQueueSave   
            @Role_ID    = NULL,-- update member count cache for all users  
            @Version_ID = @Version_ID,  
            @Entity_ID  = @Entity_ID;  
            
        EXEC @lock = sp_releaseapplock     
                        @Resource=N'Mds_Hierarchy_Save',     
                        @DbPrincipal = N'public',    
                        @LockOwner = N'Transaction';       
                            
        --Return any errors                                                    
        SELECT DISTINCT     
             HierarchyName    
            ,ChildCode    
            ,COALESCE(ChildMemberType_ID,0) AS ChildMemberType_ID    
            ,TargetCode    
            ,COALESCE(TargetMemberType_ID,0) AS TargetMemberType_ID    
            ,ErrorCode    
            ,ErrorObjectType    
            ,MemberCode -- Member code in error    
            ,MemberType_ID -- Member type in error    
            ,NULL AS MemberName    
        FROM #HierarchyMemberWorkingSet    
        WHERE ErrorCode IS NOT NULL;    
    
        --Commit only if we are not nested    
        IF @TranCounter = 0 COMMIT TRANSACTION;    
    
    END TRY    
    BEGIN CATCH    
     
        -- Get error info  
        DECLARE  
            @ErrorMessage NVARCHAR(4000),  
            @ErrorSeverity INT,  
            @ErrorState INT;  
        EXEC mdm.udpGetErrorInfo  
            @ErrorMessage = @ErrorMessage OUTPUT,  
            @ErrorSeverity = @ErrorSeverity OUTPUT,  
            @ErrorState = @ErrorState OUTPUT;  
    
        IF @TranCounter = 0     
            ROLLBACK TRANSACTION;    
        ELSE IF XACT_STATE() <> -1     
            ROLLBACK TRANSACTION TX;    
                
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);    
        RETURN(1);    
            
    END CATCH    
  
    SET NOCOUNT OFF;    
END; --proc
GO
