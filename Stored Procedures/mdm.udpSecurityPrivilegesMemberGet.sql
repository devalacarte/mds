SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpSecurityPrivilegesMemberGet 1,27,1,1, 8,13,0, -1,2  
EXEC mdm.udpSecurityPrivilegesMemberGet 1,18,1,1, 8,13,0, -1,2  
EXEC mdm.udpSecurityPrivilegesMemberGet 1,10,2,1, 8,13,0, -1,2  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesMemberGet]  
   (  
    @SystemUser_ID                INT,  
    @Principal_ID                INT,  
    @PrincipalType_ID            INT,  
    @IncludeGroupAssignments    BIT,  
    @Model_ID                INT,  
    @Hierarchy_ID                INT,  
    @HierarchyType_ID            INT,  
    @Member_ID                    INT,   
    @MemberType_ID                INT   
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
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
  
    SET NOCOUNT ON  
  
    INSERT INTO #tblPrivileges  
    EXEC mdm.udpSecurityPrivilegesMemberSummaryGet @SystemUser_ID, @Principal_ID, @PrincipalType_ID, @IncludeGroupAssignments, @Model_ID, @Hierarchy_ID, @HierarchyType_ID  
  
    IF EXISTS(SELECT 1 FROM    #tblPrivileges WHERE Member_ID = @Member_ID AND    MemberType_ID = @MemberType_ID)  
        SELECT    TOP 1   
            RoleAccess_ID,  
            Privilege_ID,  
            Privilege_Name,  
            Entity_ID,  
            Hierarchy_Name,  
            Member_ID,  
            MemberType_ID,  
            Member_Name,  
            ISNULL(SourceUserGroup_ID,-1) SourceUserGroup_ID,  
            IsModelAdministrator  
        FROM  
            #tblPrivileges  
        WHERE  
            Member_ID = @Member_ID  
        AND    MemberType_ID = @MemberType_ID  
    ELSE  
        SELECT   
            0                RoleAccess_ID,              
            99                Privilege_ID,  
            N'Unassigned or inferred privilege' Privilege_Name,  
            0                Entity_ID,  
            N''                Hierarchy_Name,  
            @Member_ID        Member_ID,   
            @MemberType_ID    MemberType_ID,  
            N''                Member_Name,  
            -1                SourceUserGroup_ID  
  
    SET NOCOUNT OFF  
END --proc
GO
