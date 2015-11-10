SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    THIS SPROC (IN THEORY) SHOULD ONLY BE CALLED BY udpHierarchyMembersGet.    
    The reason nothing should call this sproc directly is that the wrapper(udpHierarchyMembersGet) was written  
    to do the lookups necesary to provide the parameters for this sproc.  
  
    --Examples  
    EXEC mdm.udpHierarchyGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=1,@HierarchyType_ID=0,@Item_ID=6,@ItemType_ID=0,@ParentItem_ID=0,@ParentItemType_ID=0,@Parent_ID=0,@RowLimit=N'51'  
*/  
  
CREATE PROCEDURE [mdm].[udpHierarchyGet]  
(  
    @User_ID                INT,   
    @Version_ID             INT,   
    @Hierarchy_ID           INT,   
    @HierarchyType_ID       SMALLINT,              
    @Item_ID                INT = NULL,   
    @ItemType_ID            INT = NULL,   
    @ParentItem_ID          INT = NULL,   
    @ParentItemType_ID      INT = NULL,   
    @Parent_ID              INT,   
    @RowLimit               INT = NULL,  
    @IncludeDeny            BIT = 0,  
    @AnchorNullRecursions   BIT = 0,   
    @ReturnXML              BIT = 0,  
    @EntityMemberTypeID     INT = 0  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    SET CONCAT_NULL_YIELDS_NULL OFF;  
      
    DECLARE @EntityTable                    sysname,  
            @HierarchyParentTable           sysname,  
            @HierarchyTable                 sysname,  
            @HierarchyView                  sysname,  
            @CollectionMemberTable          sysname,  
            @CollectionTable                sysname,  
            @ViewName                       sysname,  
            @SQL                            NVARCHAR(MAX),  
            @Model_ID                       INT,  
            @ModelPrivilege_ID              INT,  
            @ModelLeafPrivilege_ID          INT,  
            @ModelConsolidatedPrivilege_ID  INT,    
            @MemberType_ID                  INT,   
            @Object_ID                      INT, --Security object   
            @SecItem_ID                     INT, --Security item  
            @RootSecured                    INT,  
            @MemberPrivilege_ID             INT,  
            @Entity_ID                      INT,  
            @UseMemberSecurity              INT, --0=No,1=Yes,2=LeafOnly  
            @EntityMUID                     UNIQUEIDENTIFIER,  
            @HierarchyMUID                  UNIQUEIDENTIFIER,  
            @strEntityName                  NVARCHAR(100),  
            @ParamList                      NVARCHAR(MAX),  
            @RowLimitText                   NVARCHAR(11),  
            @MemberSecurityCTE              NVARCHAR(MAX),  
            @SecurityTable                  sysname  
  
    DECLARE @ProcID sysname; SET @ProcID = OBJECT_NAME(@@PROCID);  
  
    DECLARE @ExplicitHierarchyType_ID SMALLINT = 0;  
    DECLARE @DerivedHierarchyType_ID SMALLINT = 1;  
    DECLARE @CollectionType_ID SMALLINT = 2;  
      
    IF @HierarchyType_ID < 0 OR @HierarchyType_ID > 2 -- Hierarchy type should be 0, 1, 2  
        OR (@HierarchyType_ID <> 0 AND (@Item_ID IS NULL OR @ItemType_ID IS NULL OR @ItemType_ID < 0 OR @ItemType_ID > 3)) -- Item type and ID can not be NULL, item type should be 0-3  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END  
      
    SET @MemberPrivilege_ID=2  
  
    SELECT @Model_ID = Model_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID  
      
    SET @RootSecured=0  
  
    --Get Entity_ID  
    IF @HierarchyType_ID = @ExplicitHierarchyType_ID --Explicit    
        BEGIN  
            SET @Entity_ID = CONVERT(NVARCHAR(25),@Item_ID)  
        END  
    ELSE --Derived  
        BEGIN  
            SET @Entity_ID =   
            CASE  
                WHEN @ItemType_ID = 0 THEN @Item_ID  
                WHEN @ItemType_ID = 1 THEN (SELECT DomainEntity_ID FROM mdm.tblAttribute WHERE ID = @Item_ID)  
                WHEN @ItemType_ID = 2 THEN (SELECT Entity_ID FROM mdm.tblHierarchy WHERE ID = @Item_ID)  
                WHEN @ItemType_ID = 3 THEN @Item_ID  
            END  
        END  
  
  
    --Assign the Object ID  
    --This used be different based on the Parent_ID. See TFS 142134  
    SET @Object_ID = CASE @HierarchyType_ID   
        WHEN @ExplicitHierarchyType_ID THEN 6   
        WHEN @CollectionType_ID THEN 11   
        ELSE   
        CASE @ItemType_ID   
            WHEN 0 THEN 3   
            WHEN 1 THEN 4   
            WHEN 2 THEN 6   
            WHEN 3 THEN 3   
            ELSE 0 END   
        END  
  
    /*  
    Assign the member type:  
    ----------------------  
    2: Default value  
    1: Start ID = -1 indicates Unused (non-mandatory hierarchy)  
    1: Hierarchy ID = 1 indicates a Derived Hierarchy  
    3: Hierarchy ID = 2 indicates a Collection  
    */  
    SELECT @MemberType_ID = CASE WHEN @Parent_ID = -1 THEN 1 WHEN @HierarchyType_ID = @DerivedHierarchyType_ID THEN 1 WHEN @HierarchyType_ID = @CollectionType_ID THEN 3 ELSE 2 END  
  
    --For an Explicit Hierarchy the MemberType ID represents the Item ID  
    IF @HierarchyType_ID = @ExplicitHierarchyType_ID SET @Item_ID = ISNULL(@Item_ID, (SELECT Entity_ID FROM mdm.tblHierarchy WHERE ID = @Hierarchy_ID))  
  
    --Determine the item ID to use when determining the default security permissions (Explicit Hierarchies are secured on the Hierarchy_ID).  
    --This used be different based on the Parent_ID.  See TFS 142134  
    SET @SecItem_ID = CASE @HierarchyType_ID WHEN @ExplicitHierarchyType_ID THEN @Hierarchy_ID ELSE @Item_ID END  
  
    --Fetch the default privilege for the selected member type within the current hierarchy.  
    --SELECT @ModelPrivilege_ID = mdm.udfSecurityUserMemberDefault(@User_ID, @SecItem_ID, @Object_ID, @MemberType_ID)  
    --SELECT @ModelLeafPrivilege_ID = mdm.udfSecurityUserMemberDefault(@User_ID, @SecItem_ID, @Object_ID, 1)  
    --PERF - moved these calls to a udp to decrease the execution plan compile time.  
    EXEC mdm.udpSecurityUserMemberDefault   
        @User_ID = @User_ID,   
        @Item_ID = @SecItem_ID,   
        @Object_ID = @Object_ID,   
        @MemberType_ID = @MemberType_ID,   
        @Privilege_ID = @ModelPrivilege_ID OUTPUT;  
            
    EXEC mdm.udpSecurityUserMemberDefault     
        @User_ID = @User_ID,     
        @Item_ID = @SecItem_ID,     
        @Object_ID = @Object_ID,     
        @MemberType_ID = 1,     
        @Privilege_ID = @ModelLeafPrivilege_ID OUTPUT;    
          
        IF(@MemberType_ID = 3)  
        BEGIN  
            EXEC mdm.udpSecurityUserMemberDefault     
                @User_ID = @User_ID,     
                @Item_ID = @SecItem_ID,     
                @Object_ID = @Object_ID,     
                @MemberType_ID = 2,     
                @Privilege_ID = @ModelConsolidatedPrivilege_ID OUTPUT;    
        END  
  
    --Initialize variables  
    SET @SQL = N''  
    IF @ModelPrivilege_ID = (SELECT ID FROM mdm.tblSecurityPrivilege WHERE Code = N'DENY') --if default privilege is Deny then do not return any rows  
        SET @RowLimitText = N'0'  
    ELSE      
        BEGIN   
            SET @RowLimitText = ISNULL(CAST(@RowLimit as NVARCHAR(11)), N'100 Percent')  
             
            SELECT @Object_ID = CASE @HierarchyType_ID WHEN @ExplicitHierarchyType_ID THEN 6 WHEN @CollectionType_ID THEN 11 ELSE CASE @ItemType_ID WHEN 0 THEN 3 WHEN 1 THEN 4 WHEN 2 THEN 6 WHEN 3 THEN 3 ELSE 0 END END  
            IF @HierarchyType_ID = @DerivedHierarchyType_ID AND @ModelPrivilege_ID=99--If a Derived Hierarchy, then resolve against any explicit assignments for the hierarchy (EDM-2384)  
              SET @ModelPrivilege_ID = mdm.udfMin(mdm.udfSecurityUserHierarchyDerivedItem(@User_ID, @Hierarchy_ID, @Object_ID, @Item_ID), @ModelPrivilege_ID);  
  
        END   
  
    --Figure out if Member security is used  
    SET @UseMemberSecurity=mdm.udfUseMemberSecurity(@User_ID,@Version_ID,2,@Hierarchy_ID,@HierarchyType_ID,@Entity_ID,@MemberType_ID,NULL)  
      
    --If UseMemberSecurity is false for Consolidated Members, check again for Leaf Members to handle the case  
    --where member security was set for a Derived Hierarchy whose leaf members fall within this Explicit Hierarchy.  
    IF @UseMemberSecurity = 0 AND @MemberType_ID = 2   
    BEGIN          
        SET @UseMemberSecurity=mdm.udfUseMemberSecurity(@User_ID,@Version_ID,2,@Hierarchy_ID,@HierarchyType_ID,@Entity_ID,1,NULL)    
    END  
      
    --PRINT '@User_ID: ' + convert(nvarchar(100),@User_ID);  
    --PRINT '@Version_ID: ' + convert(nvarchar(100),@Version_ID);  
    --PRINT '@Hierarchy_ID: ' + convert(nvarchar(100),@Hierarchy_ID);  
    --PRINT '@HierarchyType_ID: ' + convert(nvarchar(100),@HierarchyType_ID);  
    --PRINT '@Entity_ID: ' + convert(nvarchar(100),@Entity_ID);  
    --PRINT '@Item_ID: ' + convert(nvarchar(100),@Item_ID);  
    --PRINT '@ItemType_ID: ' + convert(nvarchar(100),@ItemType_ID);  
  
    PRINT '@UseMemberSecurity: ' + convert(nvarchar(100),@UseMemberSecurity);  
    --Check to see if Root is secured  
    IF EXISTS(  
        SELECT * FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
        WHERE   
            IsMapped=1 AND  
            User_ID = @User_ID AND  
            Hierarchy_ID = @Hierarchy_ID AND  
            HierarchyType_ID = @HierarchyType_ID AND  
            Member_ID=0  
        ) AND @UseMemberSecurity=1  
    SET @RootSecured=1  
    ----------------------------------------------------------------------------------------  
  
      
    SELECT @EntityMUID=MUID,@strEntityName=[Name] FROM mdm.tblEntity WHERE ID=@Entity_ID  
    IF @HierarchyType_ID = @ExplicitHierarchyType_ID SELECT @HierarchyMUID=MUID FROM mdm.tblHierarchy WHERE ID=@Hierarchy_ID  
      
                                  
    --BEGIN PROCESSING  
    --Criterion 1: process explicit hierarchy  
    IF @HierarchyType_ID = @ExplicitHierarchyType_ID   
        BEGIN        
            SELECT      
                @EntityTable = EntityTable,   
                @HierarchyParentTable = HierarchyParentTable,   
                @HierarchyTable = HierarchyTable,  
                @SecurityTable    = SecurityTable  
            FROM  
                mdm.tblEntity  
            WHERE  
                ID = @Item_ID;  
  
              
            SET @MemberSecurityCTE = '  
                            --Member security cte  
                            DECLARE @Ancestors TABLE(MemberID INT, MemberTypeID INT, AncestorID INT,AncestorMemberTypeID INT,LevelNumber SMALLINT);  
                            DECLARE @RAM TABLE(VersionID INT,[HierarchyID] INT,MemberID INT, MemberTypeID INT);  
                            DECLARE @TempVersionID INT;  
                            DECLARE @TempHierarchyID INT;  
                            DECLARE @TempMemberID INT;  
                            DECLARE @TempMemberTypeID INT;  
                            INSERT INTO @RAM  SELECT Version_ID,Hierarchy_ID, Member_ID,MemberType_ID FROM mdm.tblSecurityRoleAccessMember WHERE Hierarchy_ID=' + CONVERT(NVARCHAR(30), @Hierarchy_ID) + ' AND HierarchyType_ID = ' + CONVERT(NVARCHAR(30), @HierarchyType_ID) + ' ;  
                            WHILE (SELECT COUNT(*) FROM @RAM) <> 0  
                            BEGIN  
                                SELECT TOP 1   
                                    @TempVersionID=VersionID, @TempHierarchyID=HierarchyID, @TempMemberID=MemberID, @TempMemberTypeID=MemberTypeID   
                                FROM @RAM ORDER BY VersionID;  
                                  
                                INSERT INTO @Ancestors   
                                EXEC mdm.udpHierarchyAncestorsGet ' + CONVERT(NVARCHAR(30), @User_ID) + ',@TempVersionID, @TempHierarchyID, @TempMemberID, @TempMemberTypeID, 0, 1;  
                                  
                                DELETE FROM @RAM WHERE VersionID=@TempVersionID AND HierarchyID=@TempHierarchyID AND MemberID=@TempMemberID AND MemberTypeID=@TempMemberTypeID;  
                            END;                              
                            WITH ms as  
                            (  
                                SELECT  
                                    Version_ID,  
                                    CASE WHEN EN_ID IS NULL THEN HP_ID ELSE EN_ID END AS Member_ID,  
                                    MemberType_ID,  
                                    Privilege_ID,  
                                    SecurityRole_ID  
                                FROM  
                                    mdm.' + quotename(@SecurityTable) + N' X  
                                    INNER JOIN [mdm].[viw_SYSTEM_SECURITY_USER_ROLE] U ON X.SecurityRole_ID = U.Role_ID   
                                        AND U.User_ID = ' + CONVERT(NVARCHAR(30), @User_ID) + '  
                            ),  
                            msr as   
                            (  
                                SELECT ROW_NUMBER() OVER (PARTITION BY Version_ID,Member_ID,MemberType_ID ORDER BY SecurityRole_ID,Privilege_ID ASC) AS RN, * FROM ms  
                            ),  
                            membersresolved as  
                            (  
                            SELECT * FROM msr X WHERE X.RN = 1   
                            ),  
                            TopMostSecuredNodes as  
                            (  
                            SELECT DISTINCT MemberID,MemberTypeID FROM @Ancestors   
                            WHERE MemberID NOT IN (select MemberID from @Ancestors WHERE AncestorID IN(SELECT MemberID FROM @Ancestors) )  
                            )                                          
                            ';  
                              
            SELECT @HierarchyView = mdm.udfViewNameGetByID(@Item_ID, 4, 0)  
  
            IF @Parent_ID = -1 --Unused (non-mandatory hierarchy)  
                BEGIN  
                --Are the table variables we want to use not null?   
                    IF @HierarchyTable IS NULL  
                    BEGIN  
                        RAISERROR('MDSERR100104|A required schema object for this call is missing. Verify that the Hierarchy table exists for this entity.', 16, 1);  
                        RETURN;    
                    END  
                    IF @EntityTable IS NULL  
                    BEGIN  
                        RAISERROR('MDSERR100103|A required schema object for this call is missing. Verify that the Entity table exists for this entity.', 16, 1);  
                        RETURN;    
                    END   
                      
                    --For Non-Mandatory hierarchies, we always use the member security as we   
                    --have to get the permissions of the nodes of where they reside now      
                    SET @SQL = @MemberSecurityCTE + N'   
                        SELECT TOP ' + @RowLimitText + N'           
                            tEN.Code                    AS Code,          
                            ISNULL(tEN.Name, '''')        AS Name,   
                            ''MDMUNUSED''                AS ParentCode,   
                            ''''                        AS ParentName,  
                            @EntityMUID                    AS ChildEntity_MUID ,  
                            @EntityName                    AS ChildEntity_Name ,  
                            @EntityID                    AS ParentEntity_ID,    
                            @EntityMUID                    AS ParentEntity_MUID,  
                            @EntityName                    AS ParentEntity_Name,  
                            @HierarchyMUID                AS RelationshipId,  
                            2                            AS RelationshipTypeId,          
                            -1                            AS Parent_ID,           
                            0                            AS Hierarchy_ID,           
                            tEN.ID                        AS Child_ID,          
                            CONVERT(INT,1)                AS ChildType_ID,          
                            CONVERT(INT,2)                AS ParentType_ID,  
                            -1                            AS SortOrder,   
                            0                            AS NextHierarchyType_ID,  
                            CONVERT(INTEGER,ISNULL(SR.Privilege_ID, @MemberPrivilegeID)) AS Privilege_ID,  
                            @ModelPrivilegeID            AS ModelPrivilege_ID  
                        FROM  
                            mdm.' + quotename(@EntityTable) + N' AS tEN '  
                        IF @UseMemberSecurity <> 0 SET @SQL = @SQL + N'  
                                INNER JOIN membersresolved AS SR  
                                        ON SR.Member_ID = tEN.ID  
                                        AND SR.MemberType_ID = 1 '  
                        IF @UseMemberSecurity = 0 SET @SQL = @SQL + N'  
                                LEFT JOIN membersresolved AS SR  
                                        ON SR.Member_ID = tEN.ID  
                                        AND SR.MemberType_ID = 1 '  
                         SET @SQL = @SQL + N'                   
                            WHERE  
                                tEN.Status_ID = 1 AND '  
                            IF @IncludeDeny <> 1 SET @SQL = @SQL + N'ISNULL(SR.Privilege_ID,@MemberPrivilegeID ) <> 1 AND '  
                            SET @SQL = @SQL + N'  
                                tEN.Version_ID = @VersionID AND   
                                NOT EXISTS  
                                (  
                                    SELECT  
                                        tHR.Child_EN_ID  
                                    FROM   
                                        mdm.' + quotename(@HierarchyTable) + N' AS tHR                                 
                                    WHERE    
                                        tHR.Child_EN_ID = tEN.ID AND  
                                        tHR.Version_ID = @VersionID AND   
                                        tHR.ChildType_ID = 1 AND  
                                        tHR.Status_ID = 1 AND    
                                        tHR.Hierarchy_ID = @HierarchyID                               
                                )  
                            ORDER BY   
                                tEN.Code  
                        '                        
                        IF @ReturnXML=1  
                            SET @SQL = @SQL + N'  
                            FOR XML PATH(''MemberData''),ELEMENTS,ROOT(''ArrayOfMemberData'');'  
  
                        SET @ParamList = N'@MemberPrivilegeID        INT  
                                          ,@ModelPrivilegeID        INT  
                                          ,@UserID                    INT  
                                          ,@EntityID                INT  
                                          ,@VersionID                INT  
                                          ,@HierarchyID                INT  
                                          ,@EntityMUID              UNIQUEIDENTIFIER   
                                          ,@EntityName              NVARCHAR(100)  
                                          ,@HierarchyMUID            UNIQUEIDENTIFIER'   
  
                        EXEC sp_executesql @SQL, @ParamList  
                                ,@MemberPrivilege_ID  
                                ,@ModelPrivilege_ID  
                                ,@User_ID  
                                ,@Entity_ID  
                                ,@Version_ID   
                                ,@Hierarchy_ID  
                                ,@EntityMUID  
                                ,@strEntityName  
                                ,@HierarchyMUID  
                                                                              
            END ELSE BEGIN --Used (mandatory hierarchy)  
  
                IF OBJECT_ID(N'mdm.'+@HierarchyView,N'V') IS NULL BEGIN  
                        RAISERROR('MDSERR100102|A view is required.', 16, 1);  
                        RETURN;    
                END; --if  
              
                SET @SQL = CASE WHEN @UseMemberSecurity <> 0 THEN + @MemberSecurityCTE ELSE + ' ' END + N'  
                    SELECT TOP ' + @RowLimitText + N'  
                        tHR.Child_Code                    AS Code,   
                        tHR.Child_Name                    AS Name,  
                        tHR.Parent_Code                    AS ParentCode,   
                        tHR.Parent_Name                    AS ParentName,  
                        @EntityID                        AS Item_ID,   
                        0                                AS ItemType_ID,  
                        @EntityID                        AS ParentItem_ID,  
                        @EntityID                        AS ChildEntity_ID,  
                        @EntityMUID                        AS ChildEntity_MUID ,  
                        @EntityName                        AS ChildEntity_Name ,  
                        @EntityID                        AS ParentEntity_ID,    
                        @EntityMUID                        AS ParentEntity_MUID,  
                        @EntityName                        AS ParentEntity_Name,  
                        @HierarchyMUID                    AS RelationshipId,  
                        2                                AS RelationshipTypeId,  
                        0                                AS ParentItemType_ID,   
                        tHR.Parent_ID,   
                        tHR.Hierarchy_ID,   
                        tHR.Child_ID                    AS Child_ID,  
                        CONVERT(INT,tHR.ChildType_ID)    AS ChildType_ID,   
                        2                                AS ParentType_ID,   
                        tHR.Child_SortOrder                AS SortOrder,   
                        @HierarchyID                    AS NextHierarchy_ID,   
                        0                                AS NextHierarchyType_ID,  
                        CASE WHEN tHR.ChildType_ID=1 THEN @ModelLeafPrivilegeID ELSE @ModelPrivilegeID END AS ModelPrivilege_ID,';  
                IF @UseMemberSecurity <> 0 SET @SQL = @SQL + N'  
                        CONVERT(INTEGER,ISNULL(SR.Privilege_ID, @MemberPrivilegeID)) AS Privilege_ID'  
                ELSE SET @SQL += N'  
                        CASE WHEN tHR.ChildType_ID=1 AND @ModelLeafPrivilegeID =1 THEN @ModelLeafPrivilegeID ELSE @ModelPrivilegeID END  
                        AS Privilege_ID'    
                SET @SQL = @SQL + N'  
                    FROM '   
                IF @RootSecured=0 AND ISNULL(@Parent_ID, 0) = 0 AND @UseMemberSecurity = 1 SET @SQL = @SQL + N'  
                        TopMostSecuredNodes AS SU  
                    INNER JOIN mdm.' + quotename(@HierarchyView) + N' AS tHR   
                        ON SU.MemberID = tHR.Child_HP_ID  
                        AND SU.MemberTypeID = tHR.ChildType_ID   
                        AND tHR.Hierarchy_ID = @HierarchyID  
                        '  
                IF (ISNULL(@Parent_ID, 0) = 0 AND @UseMemberSecurity <> 1) OR @RootSecured=1 OR ISNULL(@Parent_ID, 0) <> 0 SET @SQL = @SQL + N'  
                        mdm.' + quotename(@HierarchyView) + N' tHR '  
                IF @UseMemberSecurity = 1 SET @SQL = @SQL + N'      
                    LEFT JOIN membersresolved AS SR  
                        ON SR.Member_ID = tHR.Child_ID  
                        AND SR.MemberType_ID = tHR.ChildType_ID'  
                IF @UseMemberSecurity = 2 SET @SQL = @SQL + N'      
                    LEFT JOIN membersresolved AS SR  
                        ON SR.Member_ID = tHR.Child_ID  
                        AND SR.MemberType_ID = tHR.ChildType_ID  
                        AND tHR.ChildType_ID = 1'  
                SET @SQL = @SQL + N'  
                    WHERE   
                        tHR.Version_ID = @VersionID   
                        AND tHR.Hierarchy_ID = @HierarchyID'  
                  IF ISNULL(@Parent_ID, 0) > 0 OR @RootSecured=1 OR (ISNULL(@Parent_ID, 0) = 0 AND @UseMemberSecurity <> 1) SET @SQL = @SQL + N'  
                        AND ((tHR.Parent_ID IS NULL AND NULLIF(@ParentID, 0) IS NULL) OR (tHR.Parent_ID = @ParentID))'  
                IF @IncludeDeny <> 1 AND @UseMemberSecurity <> 0 SET @SQL = @SQL + N'  
                        AND ISNULL(SR.Privilege_ID,@MemberPrivilegeID ) <> 1'  
                IF @UseMemberSecurity = 2 SET @SQL = @SQL + N'   
                        AND ISNULL(SR.Privilege_ID,0) <> CASE   
                                WHEN tHR.ChildType_ID = 2 THEN -1   
                                WHEN tHR.ChildType_ID = 1 THEN 0  
                            END'  
                -- Add @EntityMemberTypeID  
                IF @EntityMemberTypeID > 0 SET @SQL += N'     
                        AND tHR.ChildType_ID = @EntityMemberTypeID'     
                  
                SET @SQL = @SQL + N'  
                    ORDER BY SortOrder'  
  
                IF @ReturnXML=1  
                    SET @SQL = @SQL + N'  
                    FOR XML PATH(''MemberData''),ELEMENTS,ROOT(''ArrayOfMemberData'');'  
  
                SET @ParamList = N'  
                     @EntityID                 INT  
                    ,@EntityMemberTypeID       INT  
                    ,@EntityMUID               UNIQUEIDENTIFIER   
                    ,@EntityName               NVARCHAR(100)  
                    ,@HierarchyID              INT  
                    ,@ModelLeafPrivilegeID     INT  
                    ,@MemberPrivilegeID        INT  
                    ,@ModelPrivilegeID         INT  
                    ,@UserID                   INT  
                    ,@VersionID                INT  
                    ,@ParentID                 INT  
                    ,@HierarchyMUID               UNIQUEIDENTIFIER';  
                                                                 
                EXEC sp_executesql   
                     @SQL  
                    ,@ParamList  
                    ,@Entity_ID  
                    ,@EntityMemberTypeID  
                    ,@EntityMUID  
                    ,@strEntityName  
                    ,@Hierarchy_ID  
                    ,@ModelLeafPrivilege_ID  
                    ,@MemberPrivilege_ID  
                    ,@ModelPrivilege_ID  
                    ,@User_ID  
                    ,@Version_ID   
                    ,@Parent_ID  
                    ,@HierarchyMUID;  
            END; --if  
        END; --if  
          
    --Criterion 2: process Derived Hierarchy  
    ELSE IF @HierarchyType_ID = @DerivedHierarchyType_ID   
        BEGIN      
            SET @ViewName = N'viw_SYSTEM_' + CAST(@Model_ID AS NVARCHAR(35)) + N'_' + CAST(@Hierarchy_ID AS NVARCHAR(35)) + N'_PARENTCHILD_DERIVED'  
            IF OBJECT_ID(N'mdm.'+@ViewName,N'V') IS NULL  
                BEGIN  
                    RAISERROR('MDSERR100102|A view is required.', 16, 1);  
                    RETURN;    
                END  
            SELECT     @SecurityTable    = SecurityTable FROM mdm.tblEntity WHERE ID = @Entity_ID;  
              
            SET @MemberSecurityCTE = '  
                            --Member security cte  
                            WITH ms as  
                            (  
                                SELECT  
                                    Version_ID,  
                                    CASE WHEN EN_ID IS NULL THEN HP_ID ELSE EN_ID END AS Member_ID,  
                                    MemberType_ID,  
                                    Privilege_ID,  
                                    SecurityRole_ID  
                                FROM  
                                    mdm.' + quotename(@SecurityTable) + N' X  
                                INNER JOIN [mdm].[viw_SYSTEM_SECURITY_USER_ROLE] U ON X.SecurityRole_ID = U.Role_ID   
                                    AND U.User_ID = ' + CONVERT(NVARCHAR(30), @User_ID) + '  
                            ),  
                            msr as   
                            (  
                                SELECT   
                                    ROW_NUMBER() OVER (PARTITION BY Version_ID,Member_ID,MemberType_ID ORDER BY SecurityRole_ID,Privilege_ID ASC) AS RN  
                                    , *   
                                FROM ms  
                            ),  
                            membersresolved as  
                            (  
                            SELECT   
                                *   
                            FROM   
                                msr X   
                            WHERE X.RN = 1   
                            ),  
                            TopMostSecuredNodes as  
                            (  
                            SELECT Version_ID,Hierarchy_ID, Entity_ID,Member_ID,MemberType_ID,Privilege_ID   
                            FROM mdm.tblSecurityRoleAccessMember X  
                            INNER JOIN [mdm].[viw_SYSTEM_SECURITY_USER_ROLE] U ON X.Role_ID = U.Role_ID   
                                    AND U.User_ID = ' + CONVERT(NVARCHAR(30), @User_ID) + '  
                            WHERE Hierarchy_ID=' + CONVERT(NVARCHAR(30), @Hierarchy_ID) + ' AND HierarchyType_ID = ' + CONVERT(NVARCHAR(30), @HierarchyType_ID) + '  
                            )    ';  
            SET @SQL =  CASE WHEN @UseMemberSecurity <> 0 THEN + @MemberSecurityCTE ELSE + ' ' END + N'  
                SELECT TOP ' + @RowLimitText + N'               
                    tHR.Child_ID                AS Child_ID,   
                    CONVERT(INT,ChildType_ID)    AS ChildType_ID,  
                    tHR.Entity_ID,   
                    NextEntity_ID,   
                    tHR.Entity_ID as ChildEntity_ID,   
                    Entity_MUID as ChildEntity_MUID,  
                    NextEntity_ID as ParentEntity_ID,    
                    NextEntity_MUID as ParentEntity_MUID,  
                    tHR.Item_ID,  
                    tHR.Item_MUID as RelationshipId,   
                    tHR.ItemType_ID as RelationshipTypeId,   
                    tHR.ItemType_ID,   
                    tHR.NextItem_ID,   
                    tHR.NextItemType_ID,   
                    tHR.ParentItem_ID,   
                    tHR.ParentItemType_ID,   
                    tHR.AttributeEntity_ID,   
                    tHR.AttributeEntityValue,   
                    CASE  
                        WHEN tHR.ItemType_ID = 3 THEN tHR.NextItem_ID  
                        WHEN tHR.ItemType_ID = 2 AND tHR.NextItemType_ID = 2 THEN tHR.Item_ID  
                        ELSE ''''  
                    END Hierarchy_ID,   
                    tHR.ChildCode Code,   
                    tHR.ChildName Name,   
                    tHR.ParentCode ParentCode,   
                    tHR.ParentName ParentName,   
                    tHR.ParentType_ID,  
                    ParentVisible,   
                    @HierarchyID  NextHierarchy_ID,   
                    1 NextHierarchyType_ID,   
                    tHR.Level,'  
                    SET @SQL = @SQL + N' @ModelPrivilegeID  AS ModelPrivilege_ID, '  
                    IF @UseMemberSecurity <> 0 BEGIN  
                        SET @SQL = @SQL + N'CONVERT(INTEGER,ISNULL(';  
                        IF  @RootSecured = 0 AND ISNULL(@Parent_ID, 0) = 0 BEGIN  
                            SET @SQL = @SQL + N'SU';    
                        END ELSE BEGIN  
                            SET @SQL = @SQL + N'SR';                      
                        END  
                        SET @SQL = @SQL + N'.Privilege_ID, @MemberPrivilegeID )) AS Privilege_ID ';                      
                    END ELSE BEGIN  
                        SET @SQL = @SQL + ' @ModelPrivilegeID AS Privilege_ID ';  
                    END  
                    SET @SQL = @SQL + N' FROM '           
                    IF @RootSecured=0 AND ISNULL(@Parent_ID, 0) = 0 AND @UseMemberSecurity <> 0   
                        SET @SQL += N' TopMostSecuredNodes AS SU           
                        INNER JOIN mdm.' + quotename(@ViewName) + N' AS tHR   
                            ON SU.Entity_ID = tHR.Entity_ID   
                            AND SU.MemberType_ID = tHR.ChildType_ID   
                            AND SU.Member_ID = tHR.Child_ID  
                            --AND tHR.NextItem_ID = @ParentItemID   
                            --AND tHR.NextItemType_ID = @ParentItemTypeID   
                            AND SU.Hierarchy_ID = @HierarchyID   
                            AND SU.Privilege_ID <> 1 -- deny access';  
                    IF (ISNULL(@Parent_ID, 0) = 0 AND @UseMemberSecurity = 0) OR ISNULL(@Parent_ID, 0) <> 0 OR @RootSecured=1   
                        SET @SQL = @SQL + N' mdm.' + quotename(@ViewName) + N' AS tHR '  
                    IF ISNULL(@Parent_ID, 0) = 0 AND @UseMemberSecurity = 1 AND @RootSecured<>1 SET @SQL = @SQL + N'   
                    LEFT JOIN membersresolved AS SR  
                            ON SR.Member_ID = tHR.Child_ID  
                            AND SR.MemberType_ID = tHR.ChildType_ID'  
                    IF (ISNULL(@Parent_ID, 0) <> 0 AND @UseMemberSecurity = 1) OR (@RootSecured=1 AND @UseMemberSecurity = 1) SET @SQL = @SQL + N'      
                    LEFT JOIN membersresolved AS SR  
                            ON SR.Member_ID = tHR.Child_ID  
                            AND SR.MemberType_ID = tHR.ChildType_ID '  
                    IF @UseMemberSecurity = 2 SET @SQL = @SQL + N'      
                    LEFT JOIN membersresolved AS SR  
                            ON SR.Member_ID = tHR.Child_ID  
                            AND SR.MemberType_ID = tHR.ChildType_ID'  
                SET @SQL = @SQL + N' WHERE '  
                IF ISNULL(@Parent_ID, 0) > 0 OR (ISNULL(@Parent_ID, 0) = 0 AND @UseMemberSecurity = 0) OR @RootSecured=1 SET @SQL = @SQL + N'tHR.Item_ID = @ItemID AND  
                    tHR.ItemType_ID = @ItemTypeID  AND  
                    tHR.Parent_ID = @ParentID AND '  
                IF ISNULL(@Parent_ID, 0) > 0 AND @ParentItem_ID=@Item_ID AND @ItemType_ID=@ParentItemType_ID AND @ItemType_ID<>2 SET @SQL = @SQL + N'   
                    tHR.ParentItem_ID = @ParentItemID  AND  
                    tHR.ParentItemType_ID = @ParentItemTypeID  AND '  
                SET @SQL = @SQL + N' tHR.Version_ID = @VersionID '  
                IF @UseMemberSecurity = 2 SET @SQL = @SQL + N' AND ISNULL(SR.Privilege_ID,0) <> CASE   
                                                                                                        WHEN tHR.ChildType_ID = 2 THEN -1   
                                                                                                        WHEN tHR.ChildType_ID = 1 THEN 0  
                                                                                                    END'  
  
                IF @AnchorNullRecursions = 1 SET @SQL = @SQL +    
                    N'AND (tHR.Child_ID NOT IN (SELECT tHR2.Child_ID   
                         FROM mdm.' + quotename(@ViewName) + N' AS tHR2  
                         WHERE tHR2.Version_ID = @VersionID AND tHR2.Parent_ID <> 0))'  
                                                                                                      
                IF @IncludeDeny <> 1 AND @UseMemberSecurity <> 0 SET @SQL = @SQL + N' AND ISNULL(SR.Privilege_ID, @MemberPrivilegeID ) <> 1 '  
                IF ISNULL(@Parent_ID, 0) > 0 AND @ParentItem_ID=@Item_ID AND @ItemType_ID=@ParentItemType_ID AND @ItemType_ID<>2 SET @SQL = @SQL + N' AND tHR.Level >=   
                        (  
                        SELECT   
                            MAX(Level) FROM mdm.' + quotename(@ViewName) + N'   
                        WHERE   
                            Item_ID = @ItemID  AND   
                            ItemType_ID = @ItemTypeID  AND   
                            Parent_ID = @ParentID  AND   
                            ParentItem_ID = @ParentItemID  AND  
                            ParentItemType_ID = @ParentItemTypeID AND  
                            Version_ID = @VersionID   
                        )'  
                SET @SQL = @SQL + N' ORDER BY SortItem '  
                   
                SET @ParamList = N'@HierarchyID          INT  
                                ,@ModelPrivilegeID    INT  
                                ,@MemberPrivilegeID   INT  
                                ,@UserID              INT  
                                ,@VersionID           INT  
                                ,@EntityID            INT  
                                ,@ItemID              INT  
                                ,@ItemTypeID          INT  
                                ,@ParentID            INT   
                                ,@ParentItemID        INT  
                                ,@ParentItemTypeID    INT'  
  
                IF @ReturnXML = 1  
                    SET @SQL = @SQL + N' FOR XML PATH(''MemberData''),ELEMENTS,ROOT(''ArrayOfMemberData'');';  
  
                PRINT(@SQL);  
                EXEC sp_executesql   
                     @SQL  
                    ,@ParamList  
                    ,@Hierarchy_ID  
                    ,@ModelPrivilege_ID  
                    ,@MemberPrivilege_ID  
                    ,@User_ID  
                    ,@Version_ID  
                    ,@Entity_ID  
                    ,@Item_ID  
                    ,@ItemType_ID  
                    ,@Parent_ID  
                    ,@ParentItem_ID  
                    ,@ParentItemType_ID;  
                      
                   
        END  
  
    --Criterion 3: process Collection or Collection members  
    ELSE IF @HierarchyType_ID = @CollectionType_ID    
        BEGIN  
            SELECT      
                @EntityTable = EntityTableName,   
                @HierarchyParentTable = HierarchyParentTableName,   
                @CollectionMemberTable = CollectionMemberTableName,   
                @CollectionTable = CollectionTableName  
            FROM    
                [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Item_ID  
  
            IF @Hierarchy_ID = 0 --List all Collections  
                BEGIN  
                    --Are the table variables we want to use not null?   
                    IF @CollectionTable IS NULL  
                    BEGIN  
                        RAISERROR('MDSERR100105|A required schema object for this call is missing. Verify that the Collection table exists for this entity.', 16, 1);  
                        RETURN;    
                    END  
                  
                    SET @SQL =   
                    N'  
                    SELECT  TOP ' + @RowLimitText + N'  
                        tCN.ID Member_ID,   
                        3 MemberType_ID,   
                        tCN.ID Hierarchy_ID,   
                        tCN.ID SortOrder,   
                        tCN.Code Code,   
                        tCN.Name Name,   
                        CONVERT(DECIMAL(18, 2), 0) Weight,   
                        tCN.ID AS Child_ID,   
                        CONVERT(INT,3) ChildType_ID,   
                        tCN.ID NextHierarchy_ID,   
                        2 NextHierarchyType_ID,  
                        @ModelPrivilegeID  ModelPrivilege_ID,  
                        @ModelPrivilegeID  Privilege_ID  
                    FROM   
                        mdm.' + quotename(@CollectionTable) + N' tCN                           
                    WHERE   
                        tCN.Version_ID = @VersionID  AND   
                        tCN.Status_ID = 1  
                    ORDER BY tCN.ID  
                    '  
                    SET @ParamList = N'@ModelPrivilegeID    INT  
                                    ,@VersionID   INT'  
                    --PRINT(@SQL);  
                    IF @ReturnXML=1  
                    BEGIN  
                        SET @SQL = @SQL + N' FOR XML PATH(''MemberData''),ELEMENTS,ROOT(''ArrayOfMemberData'');'  
                    END  
                    EXEC sp_executesql @SQL, @ParamList  
                                ,@ModelPrivilege_ID  
                                ,@Version_ID  
                                  
                          
                END  
            ELSE  --List members in a Collection  
                BEGIN  
                    --Are the table variables we want to use not null?   
                    IF @HierarchyParentTable IS NULL   
                    BEGIN  
                        RAISERROR('MDSERR100107|A required schema object for this call is missing. Verify that the Hierarchy Parent table exists for this entity.', 16, 1);  
                        RETURN;    
                    END  
                    IF @CollectionMemberTable IS NULL   
                    BEGIN  
                        RAISERROR('MDSERR100106|A required schema object for this call is missing. Verify that the Collection Member table exists for this entity.', 16, 1);  
                        RETURN;    
                    END  
                    IF @EntityTable IS NULL   
                    BEGIN  
                        RAISERROR('MDSERR100103|A required schema object for this call is missing. Verify that the Entity table exists for this entity.', 16, 1);  
                        RETURN;    
                    END  
                    IF @CollectionTable IS NULL   
                    BEGIN  
                        RAISERROR('MDSERR100105|A required schema object for this call is missing. Verify that the Collection table exists for this entity.', 16, 1);  
                        RETURN;    
                    END  
                  
                    SET @SQL =   
                    N'  
                    SELECT  TOP ' + @RowLimitText + N'  
  
                        @EntityID ChildEntity_ID,  
                        @EntityMUID ChildEntity_MUID,   
                        @EntityID ParentEntity_ID,    
                        @EntityMUID ParentEntity_MUID,  
                        ''ROOT'' ParentCode,   
                        '''' ParentName,  
                        2 as ParentType_ID,   
                        CASE    
                            WHEN tCM.ChildType_ID = 1 THEN tEN.ID  
                            WHEN tCM.ChildType_ID = 2 THEN tHP.ID  
                            WHEN tCM.ChildType_ID = 3 THEN tCN.ID  
                        END Member_ID,   
                        tCM.ChildType_ID MemberType_ID,   
                        CASE    
                            WHEN tCM.ChildType_ID = 1 THEN 0  
                            WHEN tCM.ChildType_ID = 2 THEN tHP.Hierarchy_ID  
                            WHEN tCM.ChildType_ID = 3 THEN tCN.ID  
                        END Hierarchy_ID,   
                        tCM.SortOrder,   
                        CASE    
                            WHEN tCM.ChildType_ID = 1 THEN tEN.Code  
                            WHEN tCM.ChildType_ID = 2 THEN tHP.Code  
                            WHEN tCM.ChildType_ID = 3 THEN tCN.Code  
                        END Code,   
                        CASE    
                            WHEN tCM.ChildType_ID = 1 THEN tEN.Name   
                            WHEN tCM.ChildType_ID = 2 THEN tHP.Name  
                            WHEN tCM.ChildType_ID = 3 THEN tCN.Name   
                        END Name,   
                        CONVERT(DECIMAL(18, 2), tCM.Weight) Weight,   
                        CASE tCM.ChildType_ID WHEN 1 THEN tCM.Child_EN_ID WHEN 2 THEN tCM.Child_HP_ID WHEN 3 THEN tCM.Child_CN_ID END AS Child_ID,  
                        CONVERT(INT,tCM.ChildType_ID) ChildType_ID,   
                        CASE    
                            WHEN tCM.ChildType_ID = 1 THEN 0  
                            WHEN tCM.ChildType_ID = 2 THEN tHP.Hierarchy_ID  
                            WHEN tCM.ChildType_ID = 3 THEN tCN.ID  
                        END NextHierarchy_ID,   
                        CASE    
                            WHEN tCM.ChildType_ID = 3 THEN 2  
                            ELSE 0  
                        END NextHierarchyType_ID,  
                        @ModelPrivilegeID  ModelPrivilege_ID,  
                        CASE WHEN tCM.ChildType_ID=1 AND @ModelLeafPrivilegeID =1 THEN @ModelLeafPrivilegeID ELSE   
                        CASE WHEN tCM.ChildType_ID=2 AND @ModelConsolidatedPrivilegeID =1  THEN @ModelConsolidatedPrivilegeID ELSE @ModelPrivilegeID END  END AS Privilege_ID,    
                        @EntityMUID RelationshipId,  
                        4 RelationshipTypeId                      
                    FROM   
                        mdm.' + quotename(@CollectionMemberTable) + N' AS tCM';  
  
                    --Direct assignment of expression > 4000 nchars truncates nvarchar(max) to nvarchar(4000). Workaround is to concatenate.  
                    --Details here: http://connect.microsoft.com/SQLServer/feedback/details/283368/nvarchar-max-concatenation-yields-silent-truncation  
                    SET @SQL += N'  
                                LEFT JOIN mdm.' + quotename(@EntityTable) + N' AS tEN   
                                ON tCM.Child_EN_ID = tEN.ID   
                                AND tCM.Version_ID = tEN.Version_ID   
                                AND tEN.Version_ID = @VersionID    
                                AND tCM.Parent_CN_ID = @HierarchyID   
                                AND tCM.ChildType_ID = 1   
                                AND tEN.Status_ID = 1    
                            LEFT JOIN mdm.' + quotename(@HierarchyParentTable) + N' AS tHP   
                                ON tCM.Child_HP_ID = tHP.ID   
                                AND tCM.Version_ID = tHP.Version_ID   
                                AND tHP.Version_ID = @VersionID   
                                AND tCM.Parent_CN_ID = @HierarchyID    
                                AND tCM.ChildType_ID = 2   
                                AND tHP.Status_ID = 1    
                            LEFT JOIN mdm.' + quotename(@CollectionTable) + N' AS tCN   
                                ON tCM.Child_CN_ID = tCN.ID    
                                AND tCM.Version_ID = tCN.Version_ID   
                                AND tCN.Version_ID = @VersionID   
                                AND tCM.Parent_CN_ID = @HierarchyID    
                                AND tCM.ChildType_ID = 3   
                                AND tCN.Status_ID = 1    
                    WHERE   
                        tCM.Version_ID = @VersionID AND   
                        tCM.Status_ID = 1 AND   
                        tCM.Parent_CN_ID = @HierarchyID AND  
                        (tEN.ID IS NOT NULL OR tHP.ID IS NOT NULL OR tCN.ID IS NOT NULL)  
                    ORDER BY tCM.SortOrder';  
                      
  
                    SET @ParamList = N'@EntityID   INT  
                                ,@EntityMUID        UNIQUEIDENTIFIER  
                                ,@ModelPrivilegeID  INT  
                                ,@ModelLeafPrivilegeID        INT  
                                ,@ModelConsolidatedPrivilegeID        INT  
                                ,@VersionID         INT  
                                ,@HierarchyID      INT'  
                      
                    IF @ReturnXML=1  
                        SET @SQL = @SQL + N' FOR XML PATH(''MemberData''),ELEMENTS,ROOT(''ArrayOfMemberData'');';  
  
                    --PRINT(@SQL);  
                    EXEC sp_executesql @SQL, @ParamList  
                                ,@Entity_ID  
                                ,@EntityMUID  
                                ,@ModelPrivilege_ID  
                                ,@ModelLeafPrivilege_ID  
                                ,@ModelConsolidatedPrivilege_ID  
                                ,@Version_ID  
                                ,@Hierarchy_ID  
                      
                END; --if  
        END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
