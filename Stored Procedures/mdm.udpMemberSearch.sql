SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
*** NOTE: ANY CHANGES TO THE COLUMNS RETURNED IN THIS PROCEDURE MUST BE MADE IN THE COMPANION STORED PROCEDURE: mdm.udpSecurityHierarchyMemberSearchPrivilegesGet.    
  
  
EXEC mdm.udpMemberSearch @User_ID =1, @Version_ID = 3, @Hierarchy_ID = 1, @HierarchyType_ID = 0, @Entity_ID = 1, @SearchTerm = 'it''s'  
EXEC mdm.udpMemberSearch @User_ID =1, @Version_ID = 3, @Hierarchy_ID = 1, @HierarchyType_ID = 0, @Entity_ID = 1, @SearchTerm = '%profit%'  
--Derived Hierarchy  
EXEC mdm.udpMemberSearch @User_ID =1, @Version_ID = 19, @Hierarchy_ID = 7, @HierarchyType_ID = 1, @Entity_ID = 0, @SearchTerm = 'BK%'  
*/  
CREATE PROCEDURE [mdm].[udpMemberSearch]  
(  
    @User_ID            INT,  
    @Version_ID         INT,  
    @Hierarchy_ID       INT,  
    @HierarchyType_ID   SMALLINT,  
    @Entity_ID          INT,  
    @SearchTerm         NVARCHAR(500)  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
  
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED   
    DECLARE @ParamList          NVARCHAR(MAX),  
    @SQLString                  NVARCHAR(MAX),  
    @TempCNName                 NVARCHAR(100),  
    @Entity_Muid                UNIQUEIDENTIFIER,  
    @Hierarchy_Muid             UNIQUEIDENTIFIER,  
    @ViewName                   sysname,  
    @SecurityTable              NVARCHAR(262),  
    @Model_ID                   INT,  
    @LeafPrivilege_ID           INT,  
    @ConsolidatedPrivilege_ID   INT,  
    @CollectionPrivilege_ID     INT,  
    @PrivilegeID                INT,  
    @UseMemberSecurity          INT,  
    @MemberSecurityCTE          NVARCHAR(MAX)  
      
    --SELECT @LeafPrivilege_ID = mdm.udfSecurityUserMemberDefault(@User_ID, @Entity_ID, 3, 1)  
    --SELECT @ConsolidatedPrivilege_ID = mdm.udfSecurityUserMemberDefault(@User_ID, @Entity_ID, 3, 2)  
    --SELECT @CollectionPrivilege_ID = mdm.udfSecurityUserMemberDefault(@User_ID, @Entity_ID, 3, 3)  
    --PERF - moved these calls to a udp to decrease the execution plan compile time.  
    EXEC mdm.udpSecurityUserMemberDefault @User_ID = @User_ID, @Item_ID = @Entity_ID, @Object_ID = 3, @MemberType_ID = 1, @Privilege_ID = @LeafPrivilege_ID OUTPUT;  
    EXEC mdm.udpSecurityUserMemberDefault @User_ID = @User_ID, @Item_ID = @Entity_ID, @Object_ID = 3, @MemberType_ID = 2, @Privilege_ID = @ConsolidatedPrivilege_ID OUTPUT;  
    EXEC mdm.udpSecurityUserMemberDefault @User_ID = @User_ID, @Item_ID = @Entity_ID, @Object_ID = 3, @MemberType_ID = 3, @Privilege_ID = @CollectionPrivilege_ID OUTPUT;  
  
  
    SET @SearchTerm = @SearchTerm  
    -------------------------------------------------------------------------------------  
    --Figure out if Member security is used, and how to apply it *this may be passed in*  
    -------------------------------------------------------------------------------------  
    SET @UseMemberSecurity=mdm.udfUseMemberSecurity(@User_ID,@Version_ID,3,@Hierarchy_ID,@HierarchyType_ID,@Entity_ID,NULL,NULL)  
      
    IF @UseMemberSecurity <> 0  
    BEGIN  
        IF @Entity_ID IS NULL --When searching a derived hierarchy the entity might not be passed in  
        BEGIN  
            --Get the topmist entity in the DH  
            SET @Entity_ID =   
            (  
                  
            SELECT TOP 1   
                        CASE   
                            WHEN ForeignType_ID = 0 THEN Foreign_ID   
                            WHEN ForeignType_ID = 1 THEN A.DomainEntity_ID   
                            WHEN ForeignType_ID = 2 THEN H.Entity_ID   
                            WHEN ForeignType_ID = 3 THEN A.DomainEntity_ID   
                        END AS Entity_ID   
                    FROM   
                        mdm.tblDerivedHierarchyDetail D   
                    LEFT JOIN mdm.tblHierarchy H ON H.ID = D.Foreign_ID   
                    LEFT JOIN mdm.tblAttribute A ON A.ID = D.Foreign_ID   
                    WHERE   
                        DerivedHierarchy_ID=@Hierarchy_ID Order By Entity_ID ASC  
            )  
        END  
        SET @SecurityTable = mdm.udfTableNameGetByID(@Entity_ID, 6);  
    END      
      
    IF @LeafPrivilege_ID = 99 OR @LeafPrivilege_ID = NULL SET @LeafPrivilege_ID = 2  
    IF @ConsolidatedPrivilege_ID = 99 SET @ConsolidatedPrivilege_ID = 2  
  
      
    --These cte's are selectively added to the overall query based on if member security is needed to be applied   
    SET @MemberSecurityCTE = N'  
    -- Preloading the user''s roles into a table var is better for perf than directly joining with viw_SYSTEM_SECURITY_USER_ROLE.   
    -- Testing on large (~1M members) data sets showed that using a table var is slightly (10-20%) faster than using a temp table.  
    DECLARE @SecurityRoles TABLE(RoleID INT PRIMARY KEY);  
    INSERT INTO @SecurityRoles  
    SELECT Role_ID FROM mdm.[viw_SYSTEM_SECURITY_USER_ROLE] WHERE User_ID = @User_ID;  
  
    WITH ms as  
    (  
        SELECT  
            CASE WHEN EN_ID IS NULL THEN HP_ID ELSE EN_ID END AS Member_ID,  
            MemberType_ID,  
            Privilege_ID  
        FROM mdm.' + QUOTENAME(@SecurityTable) + N' X  
        INNER JOIN @SecurityRoles R  
            ON X.SecurityRole_ID = R.RoleID  
        WHERE   
            X.Version_ID = @Version_ID  
    ),  
    msr as   
    (  
        SELECT   
            ROW_NUMBER() OVER (PARTITION BY ms.Member_ID,ms.MemberType_ID ORDER BY Privilege_ID ASC) AS RN   
            , ms.*  
        FROM ms  
    ),  
    membersresolved as  
    (  
        SELECT X.*  
        FROM msr X  
        WHERE X.RN = 1  
    )';  
    IF @HierarchyType_ID = 0 --Standard  
       BEGIN  
          SELECT @ViewName   = mdm.udfViewNameGetByID(@Entity_ID, 4, 0)  
          SELECT @Entity_Muid=MUID FROM mdm.tblEntity WHERE ID=@Entity_ID  
          SELECT @Hierarchy_Muid=MUID FROM mdm.tblHierarchy WHERE ID=@Hierarchy_ID  
  
          SELECT @SQLString = CASE @UseMemberSecurity WHEN 1 THEN @MemberSecurityCTE ELSE '' END + N'   
                   SELECT TOP 500  
                      Child_Code AS Code,  
                      Child_Name AS Name,  
                      CONVERT(int,T.ChildType_ID) AS ChildType_ID,  
                      @Entity_Muid AS ChildEntity_MUID,  
                      Parent_Code AS ParentCode,  
                      Parent_Name AS ParentName,  
                      2 AS ParentType_ID,  
                      @Entity_Muid AS ParentEntity_MUID,  
                      @Hierarchy_Muid AS RelationshipId,  
                      2 AS RelationshipTypeId, --2 is Hierarchy ItemType '  
                      IF @UseMemberSecurity <> 0 SET @SQLString = @SQLString + N'  
                        CONVERT(INTEGER,ISNULL(SR.Privilege_ID, @LeafPrivilege_ID)) AS Privilege_ID'  
                      ELSE IF @UseMemberSecurity = 0 SET @SQLString = @SQLString + N'  
                        @LeafPrivilege_ID AS Privilege_ID'  
                      SET @SQLString = @SQLString + N'  
                        
                   FROM   
                      mdm.' + quotename(@ViewName) + N' T '                          
                   IF @UseMemberSecurity <> 0 SET @SQLString = @SQLString + N'   
                   LEFT JOIN membersresolved SR  
                        ON SR.MemberType_ID = T.ChildType_ID   
                        AND SR.Member_ID = T.Child_ID'  
                                          
                   SELECT @SQLString = @SQLString + N'  
                   WHERE   
                      T.Version_ID = @Version_ID AND   
                      Hierarchy_ID = @Hierarchy_ID AND '  
                   IF @UseMemberSecurity <> 0   
                   BEGIN   
                        SET @SQLString += N'  
                        COALESCE(SR.Privilege_ID, 0) <> 1 AND  
                        (SR.Privilege_ID IS NOT NULL OR T.ChildType_ID <> 1) AND';  
                   END  
                   SELECT @SQLString = @SQLString + N'  
                      (  
                          Child_Code LIKE @SearchTerm  
                       OR Child_Name LIKE @SearchTerm  
                      )  
                    ORDER BY T.Child_ID'  
  
                   SET @ParamList = CAST(N'@Entity_ID   INT   
                        , @LeafPrivilege_ID             INT   
                        , @User_ID                      INT   
                        , @Version_ID                   INT   
                        , @SearchTerm                   NVARCHAR(500)  
                        , @ConsolidatedPrivilege_IDx    INT   
                        , @Hierarchy_ID                 INT  
                        , @Entity_Muid                    UNIQUEIDENTIFIER  
                        , @Hierarchy_Muid               UNIQUEIDENTIFIER' AS NVARCHAR(max))  
                  
                EXEC sp_executesql @SQLString, @ParamList  
                        ,@Entity_ID  
                        ,@LeafPrivilege_ID  
                        ,@User_ID  
                        ,@Version_ID  
                        ,@SearchTerm  
                        ,@ConsolidatedPrivilege_ID  
                        ,@Hierarchy_ID  
                        ,@Entity_Muid  
                        ,@Hierarchy_Muid  
                     
       END  
    ELSE IF @HierarchyType_ID = 1 --Derived  
       BEGIN  
  
          SELECT @Model_ID = Model_ID FROM mdm.tblDerivedHierarchy WHERE ID = @Hierarchy_ID  
          SELECT @PrivilegeID = Privilege_ID FROM mdm.udfSecurityUserHierarchyDerivedList(@User_ID, @Model_ID) WHERE ID = @Hierarchy_ID  
          SELECT @ViewName = CAST(N'viw_SYSTEM_' + CONVERT(NVARCHAR(25),@Model_ID) + N'_' + CONVERT(NVARCHAR(25),@Hierarchy_ID) + N'_PARENTCHILD_DERIVED' AS sysname)  
  
            
            SELECT @SQLString = CASE @UseMemberSecurity WHEN 1 THEN @MemberSecurityCTE ELSE '' END + N'   
            SELECT TOP 500  
                ChildCode as Code,  
                ChildName as Name,  
                ChildType_ID,  
                Entity_MUID as ChildEntity_MUID,  
                ParentCode as ParentCode,  
                ParentName as ParentName,      
                ParentType_ID,                                              
                Item_MUID as RelationshipId,  
                ItemType_ID AS RelationshipTypeId,  
                NextItem_ID,  
                NextItemType_ID,    
                AttributeEntity_ID,  
                ParentEntity_MUID,'  
                IF @UseMemberSecurity <> 0 SET @SQLString = @SQLString + N'  
                CONVERT(INTEGER,ISNULL(SR.Privilege_ID, @LeafPrivilege_ID)) AS Privilege_ID'  
                ELSE IF @UseMemberSecurity = 0 SET @SQLString = @SQLString + N'  
                @LeafPrivilege_ID AS Privilege_ID'  
            SET @SQLString = @SQLString + N'      
            FROM   
              mdm.' + quotename(@ViewName) + N' T '                     
            IF @UseMemberSecurity <> 0 SET @SQLString = @SQLString + N'   
                    INNER JOIN membersresolved SR  
                            ON SR.Member_ID = T.Child_ID  
                            AND SR.MemberType_ID = T.ChildType_ID '  
            SELECT @SQLString = @SQLString + N'  
                   WHERE   
                      T.Version_ID = @Version_ID AND '  
                      IF @UseMemberSecurity <> 0 SET @SQLString = @SQLString + N'ISNULL(SR.Privilege_ID,@LeafPrivilege_ID) <> 1 AND'  
            SELECT @SQLString = @SQLString + N'  
                      T.ItemType_ID <> 3 AND    
                      (  
                      ChildCode LIKE @SearchTerm  
                      OR  
                      ChildName LIKE @SearchTerm  
                      ) ORDER BY Item_ID  
                   '  
              
                   SET @ParamList = CAST(N'  
                          @User_ID                INT  
                         ,@LeafPrivilege_ID       INT    
                         ,@Version_ID             INT   
                         ,@PrivilegeID            INT  
                         ,@SearchTerm             NVARCHAR(500)'  AS NVARCHAR(max))  
                   EXEC sp_executesql @SQLString, @ParamList  
                        ,@User_ID  
                        ,@LeafPrivilege_ID  
                        ,@Version_ID  
                        ,@PrivilegeID  
                        ,@SearchTerm  
                          
       END  
    ELSE IF @HierarchyType_ID = 2 --Collection  
       BEGIN  
          SELECT @TempCNName = mdm.udfViewNameGetByID(@Entity_ID,3,1)  
                  
          SELECT @SQLString = @MemberSecurityCTE + N'   
                   SELECT TOP 500  
                      ID,  
                      Code as Code,  
                      Name as Name,  
                      3 as MemberType_ID,  
                      @Entity_ID  as Item_ID,  
                      1 as ItemType_ID,  
                      @Entity_ID  as NextItem_ID,  
                      1 as NextItemType_ID,  
                      @CollectionPrivilegeID as ModelPrivilege_ID,   
                      ISNULL(SR.Privilege_ID,2) as Privilege_ID   
                   FROM   
                      mdm.' + quotename(@TempCNName) + N' T  
                             LEFT JOIN membersresolved SR  
                                    ON SR.Member_ID = T.ID  
                                    AND SR.MemberType_ID = 3  
                                                  
                   WHERE   
                      T.Version_ID = @Version_ID AND  
                      ISNULL(SR.Privilege_ID,@CollectionPrivilegeID) <> 1 AND   
                      (  
                      Code LIKE @SearchTerm  
                      OR  
                      Name LIKE @SearchTerm  
                      )  ORDER BY ID              
                   '  
                     
                   SET @ParamList = CAST(N'@Entity_ID       INT   
                        , @CollectionPrivilegeID       INT   
                        , @User_ID                     INT   
                        , @Version_ID                  INT   
                        , @SearchTerm                  NVARCHAR(500)'  AS NVARCHAR(max))  
                          
                   EXEC sp_executesql @SQLString, @ParamList  
                        ,@Entity_ID  
                        ,@CollectionPrivilege_ID  
                        ,@User_ID  
                        ,@Version_ID  
                        ,@SearchTerm  
                          
                     
                     
       END  
  
    SET NOCOUNT OFF  
END --proc
GO
