SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpSecurityPrivilegesMemberSummaryGet 1,27,1,1  
EXEC mdm.udpSecurityPrivilegesMemberSummaryGet 1,11,1,1,6,10,0  
EXEC mdm.udpSecurityPrivilegesMemberSummaryGet 1,18,1,1,Null,Null,Null  
EXEC mdm.udpSecurityPrivilegesMemberSummaryGet 1,118,1,1,Null,Null,Null  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesMemberSummaryGet]  
   (  
    @SystemUser_ID                INT,  
    @Principal_ID                INT,  
    @PrincipalType_ID            INT,  
    @IncludeGroupAssignments    BIT = NULL,  
    @Model_ID                INT = NULL,  
    @Hierarchy_ID                INT = NULL,  
    @HierarchyType_ID            INT = NULL  
   )  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
    DECLARE @ParamList      NVARCHAR(MAX)  
    DECLARE @Version_ID int  
    , @Entity_ID INT  
    , @Member_ID INT  
    , @MemberType_ID INT  
    , @TableName    sysname  
    CREATE Table #tblMemberIDs (  
        ID                        INT IDENTITY (1, 1) NOT NULL,   
        Version_ID                INT,  
        Entity_ID                INT,  
        Member_ID                INT,  
        MemberType_ID            INT,  
        TableName                NVARCHAR(100) COLLATE database_default  
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
  
    INSERT INTO #tblMemberIDs (Version_ID, Entity_ID, Member_ID, MemberType_ID, TableName)  
    SELECT    DISTINCT Version_ID, Entity_ID, Member_ID, MemberType_ID, CASE WHEN HierarchyType_ID = 1 AND Member_ID = 0 THEN mdm.udfTableNameGetByID(Entity_ID, 1) ELSE mdm.udfTableNameGetByID(Entity_ID, MemberType_ID) END  
    FROM    mdm.udfSecurityUserExplicitMemberPermissions( @Principal_ID, @PrincipalType_ID, @IncludeGroupAssignments, NULL) xp  
  
    INSERT INTO #tblPrivileges  
    SELECT   
        xp.RoleAccess_ID,  
        xp.RoleAccess_MUID,  
        sp.ID                   Privilege_ID,  
        sp.Name                    Privilege_Name,  
        xp.Principal_ID,  
        xp.Principal_MUID,  
        xp.PrincipalType_ID,  
        xp.Principal_Name,  
        xp.Version_ID,  
        xp.Version_MUID,  
        xp.Version_Name,  
        xp.Model_ID,  
        xp.Model_MUID,  
        xp.Model_Name,  
        xp.Entity_ID,  
        xp.Entity_MUID,  
        xp.Entity_Name,  
        xp.Hierarchy_ID,  
        xp.Hierarchy_MUID,  
        xp.HierarchyType_ID ,       
        case xp.HierarchyType_ID  
            when 0 then (select DISTINCT Hierarchy_Label from mdm.viw_SYSTEM_SCHEMA_MODELS where Hierarchy_ID = xp.Hierarchy_ID)  
            when 1 then (select DISTINCT Hierarchy_Label from mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED where Hierarchy_ID = xp.Hierarchy_ID)  
        end As Hierarchy_Name,  
        xp.Member_ID,  
        xp.MemberType_ID,  
        NULL Member_Name,  
        xp.SourceUserGroup_Name,  
        xp.SourceUserGroup_ID,  
        modSec.IsAdministrator    IsModelAdministrator  
    FROM  
        mdm.udfSecurityUserExplicitMemberPermissions( @Principal_ID, @PrincipalType_ID, @IncludeGroupAssignments, NULL) xp  
        INNER JOIN mdm.tblSecurityObject so   
            ON    xp.Object_ID = so.ID  
            AND    ((@Model_ID IS NULL) OR (xp.Model_ID =@Model_ID))  
            AND    ((@Hierarchy_ID IS NULL ) OR (xp.Hierarchy_ID = @Hierarchy_ID))  
            AND    ((@HierarchyType_ID IS NULL) OR (xp.HierarchyType_ID = @HierarchyType_ID))  
        INNER JOIN mdm.tblSecurityPrivilege sp  
              ON xp.Privilege_ID = sp.ID  
        INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL modSec  
            ON modSec.User_ID = @SystemUser_ID AND modSec.ID = xp.Model_ID  
  
  
    --Update the Member_Name column  
    WHILE EXISTS(SELECT 1 FROM #tblMemberIDs)  
    BEGIN  
  
    
       SELECT TOP 1   
          @ID = ID  
          ,@Version_ID =Version_ID  
          ,@Member_ID=Member_ID  
          ,@Entity_ID =Entity_ID  
          ,@TableName =TableName  
          ,@MemberType_ID= MemberType_ID  
       FROM #tblMemberIDs ORDER BY ID  
         
        SET @ParamList = N'  
              @Version_ID INT  
            , @Entity_ID INT  
            , @Member_ID INT  
            , @MemberType_ID INT';  
              
             SET  @SQL= N'UPDATE #tblPrivileges  
          SET   Member_Name = CASE #tblPrivileges.SourceUserGroup_Name WHEN Null THEN CASE WHEN Name IS NULL THEN Code + '' *''  ELSE Code + ''{'' + Name + ''} *'' END ELSE CASE WHEN Name IS NULL THEN Code ELSE Code + ''{'' + Name + ''}'' END END  
          FROM  mdm.' + quotename(@TableName) + N' T  
          WHERE T.Version_ID = @Version_ID  
          AND   T.ID = @Member_ID  
          AND   #tblPrivileges.Entity_ID = @Entity_ID  
          AND   #tblPrivileges.MemberType_ID = @MemberType_ID  
          AND   #tblPrivileges.Member_ID = @Member_ID '  
  
       EXEC sp_executesql @SQL,@ParamList, @Version_ID = @Version_ID,@Member_ID=@Member_ID,@Entity_ID=@Entity_ID,@MemberType_ID=@MemberType_ID  
  
       DELETE FROM #tblMemberIDs WHERE ID = @ID  
    END  
  
    UPDATE #tblPrivileges SET Member_Name = N'ROOT' WHERE Member_ID = 0  
    UPDATE #tblPrivileges SET Member_Name = N'UNUSED' WHERE Member_ID = -1  
  
    SELECT   
    RoleAccess_ID            ,  
        RoleAccess_MUID ,   
        Privilege_ID            ,  
        Privilege_Name            ,  
        Principal_ID ,   
        Principal_MUID ,   
        PrincipalType_ID ,   
        Principal_Name ,  
        Version_ID ,   
        Version_MUID ,   
        Version_Name ,   
        Model_ID ,   
        Model_MUID ,   
        Model_Name ,   
        Entity_ID ,   
        Entity_MUID ,   
        Entity_Name ,   
        Hierarchy_ID ,   
        Hierarchy_MUID ,   
        HierarchyType_ID ,       
        Hierarchy_Name            ,  
        Member_ID                ,  
        MemberType_ID            ,  
        Member_Name                ,  
        SourceUserGroup_Name    ,  
        SourceUserGroup_ID        ,  
        IsModelAdministrator      
    FROM #tblPrivileges  
    ORDER BY Model_Name, Version_Name, Member_Name  
  
    SET NOCOUNT OFF  
END
GO
