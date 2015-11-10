SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
exec mdm.udpSecurityPrivilegesMemberSummaryEffectiveGet @SystemUser_ID=1,@Principal_ID=2,@PrincipalType_ID=1,  
@Model_ID=NULL,@Hierarchy_ID=NULL,@HierarchyType_ID=null  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesMemberSummaryEffectiveGet]  
   (  
    @SystemUser_ID                INT,  
    @Principal_ID                INT,  
    @PrincipalType_ID            INT,  
    @Model_ID                    INT = NULL,  
    @Hierarchy_ID                INT = NULL,  
    @HierarchyType_ID            INT = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
  
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  
  
    CREATE Table #tblMemberIDs (  
        ID                        INT IDENTITY (1, 1) NOT NULL,   
        Version_ID                INT,  
        Entity_ID                INT,  
        Member_ID                INT,  
        MemberType_ID            INT,  
        TableName                NVARCHAR(100) COLLATE database_default,  
        Hierarchy_ID            INT,  
        HierarchyType_ID        INT  
    )  
  
    CREATE TABLE #tblPrivileges(  
        RoleAccess_ID           INT,  
        RoleAccess_MUID         UNIQUEIDENTIFIER,  
        Privilege_ID            INT,  
        Privilege_Name          NVARCHAR(250) COLLATE database_default,  
        Principal_ID            INT,  
        Principal_MUID          UNIQUEIDENTIFIER,  
        PrincipalType_ID        INT,  
        Principal_Name          NVARCHAR(250) COLLATE database_default,  
        Version_ID              INT,  
        Version_MUID            UNIQUEIDENTIFIER,  
        Version_Name            NVARCHAR(50) COLLATE database_default,  
        Model_ID                INT,  
        Model_MUID              UNIQUEIDENTIFIER,  
        Model_Name              NVARCHAR(50) COLLATE database_default,  
        Entity_ID               INT,  
        Entity_MUID             UNIQUEIDENTIFIER,  
        Entity_Name             NVARCHAR(50) COLLATE database_default,  
        Hierarchy_ID            INT,  
        Hierarchy_MUID          UNIQUEIDENTIFIER,  
        HierarchyType_ID        INT,  
        Hierarchy_Name          NVARCHAR(250) COLLATE database_default,    
        Member_ID               INT,  
        MemberType_ID           INT,  
        Member_Name             NVARCHAR(250) COLLATE database_default NULL,  
        SourceUserGroup_Name    NVARCHAR(250) COLLATE database_default NULL,  
        SourceUserGroup_ID      INT NULL,  
        IsModelAdministrator    BIT  
    );  
  
    DECLARE @ID               INT  
    DECLARE @SQL              NVARCHAR(MAX)  
  
    INSERT INTO #tblMemberIDs (Version_ID, Entity_ID, Member_ID, MemberType_ID, TableName,Hierarchy_ID,HierarchyType_ID)  
    SELECT DISTINCT Version_ID, Entity_ID, Member_ID, MemberType_ID,   
            CASE WHEN HierarchyType_ID = 1 AND Member_ID = 0 THEN mdm.udfTableNameGetByID(CASE WHEN ItemType_ID = 2 THEN Item_ID ELSE Entity_ID END, 1)   
            ELSE mdm.udfTableNameGetByID(CASE WHEN ItemType_ID = 2 THEN Item_ID ELSE Entity_ID END, MemberType_ID) END,  
            Hierarchy_ID,  
            HierarchyType_ID  
    FROM mdm.udfSecurityUserExplicitMemberPermissions( @Principal_ID, @PrincipalType_ID, 1, NULL) xp  
  
    INSERT INTO #tblPrivileges  
        SELECT  
            0 RoleAccess_ID,  
            NULL RoleAccess_MUID,  
            NULL Privilege_ID,  
            NULL Privilege_Name,  
            rac.Principal_ID,  
            rac.Principal_MUID,  
            rac.PrincipalType_ID,  
            rac.Principal_Name,  
            rac.Version_ID,  
            rac.Version_MUID,  
            rac.Version_Name,  
            rac.Model_ID,  
            rac.Model_MUID,  
            rac.Model_Name,  
            rac.Entity_ID,  
            rac.Entity_MUID,  
            rac.Entity_Name,  
            rac.Hierarchy_ID,  
            rac.Hierarchy_MUID,  
            rac.HierarchyType_ID,  
            case HierarchyType_ID  
                when 0 then (select DISTINCT Hierarchy_Label from mdm.viw_SYSTEM_SCHEMA_MODELS where Hierarchy_ID = rac.Hierarchy_ID)  
                when 1 then (select DISTINCT Hierarchy_Label from mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED where Hierarchy_ID = rac.Hierarchy_ID)  
            end As Hierarchy_Name,  
            Member_ID,  
            MemberType_ID,  
            NULL Member_Name,  
            NULL SourceUserGroup_Name,  
            NULL SourceUserGroup_ID,  
            0     IsModelAdministrator  
        FROM    mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER rac INNER JOIN mdm.tblSecurityObject so ON rac.Object_ID = so.ID  
        WHERE   rac.PrincipalType_ID = @PrincipalType_ID  
        AND     rac.Principal_ID = @Principal_ID  
        AND     ((@Model_ID IS NULL) OR (rac.Model_ID = @Model_ID))  
        AND     ((@Hierarchy_ID IS NULL) OR (rac.Hierarchy_ID = @Hierarchy_ID))  
        AND     ((@HierarchyType_ID IS NULL) OR (rac.HierarchyType_ID = @HierarchyType_ID))  
  
        UNION  
  
        SELECT  
            0 RoleAccess_ID,  
            NULL RoleAccess_MUID,  
            NULL Privilege_ID,  
            NULL Privilege_Name,  
            rac.Principal_ID,  
            rac.Principal_MUID,  
            rac.PrincipalType_ID,  
            rac.Principal_Name,  
            rac.Version_ID,  
            rac.Version_MUID,  
            rac.Version_Name,  
            rac.Model_ID,  
            rac.Model_MUID,  
            rac.Model_Name,  
            rac.Entity_ID,  
            rac.Entity_MUID,  
            rac.Entity_Name,  
            rac.Hierarchy_ID,  
            rac.Hierarchy_MUID,  
            rac.HierarchyType_ID,  
            case HierarchyType_ID  
                when 0 then (select DISTINCT Hierarchy_Label from mdm.viw_SYSTEM_SCHEMA_MODELS where Hierarchy_ID = rac.Hierarchy_ID)  
                when 1 then (select DISTINCT Hierarchy_Label from mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED where Hierarchy_ID = rac.Hierarchy_ID)  
            end As Hierarchy_Name,  
            Member_ID,  
            MemberType_ID,  
            NULL Member_Name,  
            NULL SourceUserGroup_Name,  
            NULL SourceUserGroup_ID,  
            0     IsModelAdministrator  
        FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER rac   
        INNER JOIN mdm.tblSecurityObject so ON rac.Object_ID = so.ID  
        INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_ROLE sur  
        on rac.Role_ID = sur.Role_ID   
        AND sur.User_ID = @Principal_ID  
        WHERE rac.PrincipalType_ID = 2  
        AND   ((@Model_ID IS NULL) OR (rac.Model_ID = @Model_ID))  
        AND   ((@Hierarchy_ID IS NULL) OR (rac.Hierarchy_ID = @Hierarchy_ID))  
        AND   ((@HierarchyType_ID IS NULL) OR (rac.HierarchyType_ID = @HierarchyType_ID))  
      
      
        DECLARE @ParamList      NVARCHAR(MAX)  
        DECLARE @Version_ID int  
        , @Entity_ID INT  
        , @Member_ID INT  
        , @MemberType_ID INT  
        , @TableName    sysname  
        , @TempHierarchy_ID    INT  
        , @TempHierarchyType_ID    INT  
  
  
        SET @ParamList =CAST(' @Version_IDx int  
            , @Entity_IDx INT  
            , @Member_IDx INT  
            , @MemberType_IDx TINYINT' AS NVARCHAR(max))  
  
  
    --Update the Member_Name column adn the Privilege_ID  
    WHILE EXISTS(SELECT 1 FROM #tblMemberIDs)  
    BEGIN  
       SELECT TOP 1   
          @ID = ID  
          ,@TableName = TableName  
          ,@Version_ID = Version_ID  
          ,@Entity_ID  = Entity_ID  
          ,@Member_ID= Member_ID  
          ,@MemberType_ID= MemberType_ID  
          ,@TempHierarchy_ID = Hierarchy_ID  
          ,@TempHierarchyType_ID = HierarchyType_ID  
        FROM #tblMemberIDs ORDER BY ID  
  
            
        SET @SQL= N'UPDATE #tblPrivileges  
        SET   Member_Name = CASE #tblPrivileges.SourceUserGroup_Name WHEN Null THEN CASE WHEN Name IS NULL THEN Code + '' *''  ELSE Code + ''{'' + Name + ''} *'' END ELSE CASE WHEN Name IS NULL THEN Code ELSE Code + ''{'' + Name + ''}'' END END  
        FROM  mdm.' + quotename(@TableName) + N' T  
        WHERE T.Version_ID = @Version_IDx   
        AND   T.ID = @Member_IDx  
        AND   #tblPrivileges.Entity_ID = @Entity_IDx  
        AND   #tblPrivileges.MemberType_ID = @MemberType_IDx   
        AND   #tblPrivileges.Member_ID = @Member_IDx'   
        
       EXEC sp_executesql @SQL, @ParamList, @Version_ID,@Entity_ID,@Member_ID,@MemberType_ID  
  
       DECLARE @TempPrivilege_ID INT=0;  
       EXEC mdm.udpSecurityMemberResolverGet @User_ID=@Principal_ID,@Version_ID=@Version_ID,@Hierarchy_ID=@TempHierarchy_ID,@HierarchyType_ID=@TempHierarchyType_ID,@Entity_ID=@Entity_ID,@Member_ID=@Member_ID,@MemberType_ID=@MemberType_ID,@Privilege_ID=@TempPrivilege_ID OUTPUT;  
       UPDATE #tblPrivileges SET Privilege_ID = @TempPrivilege_ID   
       WHERE Version_ID = @Version_ID  
        AND   Entity_ID = @Entity_ID  
        AND   MemberType_ID = @MemberType_ID  
        AND   Member_ID = @Member_ID   
         
       DELETE FROM #tblMemberIDs WHERE ID = @ID  
    END  
  
    UPDATE #tblPrivileges SET Member_Name = N'ROOT' WHERE Member_ID = 0  
    UPDATE #tblPrivileges SET Member_Name = N'UNUSED' WHERE Member_ID = -1  
   
   -- We need to aggregate privileges and return the minimum privileges (see TFS 376260).  
   -- for a user for a corresponding member type. Initially we were returning multiple privilegs   
   -- for a user ( Inherited and assigned) as duplicates. Added the group by clause and nulled out the role and principal muids as   
   -- these values are not significant for effective privileges which are computed values.  
    SELECT     
        0 RoleAccess_ID,    
        NULL RoleAccess_MUID,    
        MIN(xp.Privilege_ID) Privilege_ID,    
        (    
        SELECT Name FROM mdm.tblSecurityPrivilege WHERE ID = xp.Privilege_ID   
        ) Privilege_Name,     
        @Principal_ID Principal_ID,      
        NULL Principal_MUID,    
        @PrincipalType_ID PrincipalType_ID,      
        NULL Principal_Name,    
        Version_ID,    
        Version_MUID,    
        Version_Name,    
        Model_ID,    
        Model_MUID,    
        Model_Name,    
        Entity_ID,    
        Entity_MUID,    
        Entity_Name,    
        Hierarchy_Name,    
        HierarchyType_ID,    
        Hierarchy_ID,    
        Hierarchy_MUID,    
        Member_ID,    
        MemberType_ID,    
        Member_Name,    
        NULL SourceUserGroup_Name,    
        0 SourceUserGroup_ID,    
        modSec.IsAdministrator    IsModelAdministrator    
    FROM    
        #tblPrivileges xp    
        INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL modSec    
            ON modSec.User_ID = @SystemUser_ID AND modSec.ID = xp.Model_ID    
        Group By   
        xp.Privilege_ID,    
        Privilege_Name,          
        Version_ID,    
        Version_MUID,    
        Version_Name,    
        Model_ID,    
        Model_MUID,    
        Model_Name,    
        Entity_ID,    
        Entity_MUID,    
        Entity_Name,    
        Hierarchy_Name,    
        HierarchyType_ID,    
        Hierarchy_ID,    
        Hierarchy_MUID,    
        Member_ID,    
        MemberType_ID,    
        Member_Name,    
        SourceUserGroup_ID,    
        IsAdministrator    
  
    SET NOCOUNT OFF  
END --proc
GO
