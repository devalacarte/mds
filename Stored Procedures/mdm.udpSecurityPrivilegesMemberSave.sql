SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
EXEC mdm.udpSecurityPrivilegesMemberSave 1, 12, 1, 'cthompson', 'User', 1, 2, 1, 'Account'  
  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesMemberSave]  
(  
    @SystemUser_ID      INT,  
    @Principal_ID       INT,  
    @PrincipalType_ID   INT,  
    @Principal_Name     NVARCHAR(50) = NULL,  
    @PrincipalType_Name NVARCHAR(20) = NULL,  
    @RoleAccess_ID      INT,  
    @Object_ID          INT,  
    @Privilege_ID       INT,  
    @Version_ID         INT,  
    @Entity_ID          INT,  
    @Hierarchy_ID       INT,  
    @HierarchyType_ID   SMALLINT,  
    @Item_ID            INT,  
    @ItemType_ID        INT,  
    @Member_ID          INT,  
    @MemberType_ID      INT,  
    @Securable_Name     NVARCHAR(100) = NULL,  
    @Return_ID          INT = NULL OUTPUT,  
    @Return_MUID        UNIQUEIDENTIFIER = NULL OUTPUT   
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @Role_ID            INT;  
    DECLARE @Description        NVARCHAR(100);  
  
    SELECT  @Role_ID = Role_ID  
    FROM    mdm.tblSecurityAccessControl  
    WHERE   Principal_ID = @Principal_ID  
    AND     PrincipalType_ID = @PrincipalType_ID  
  
  
    IF @Principal_Name IS NULL BEGIN  
        IF @PrincipalType_ID = 1 BEGIN  
            SELECT @Principal_Name = mdm.udfUserNameGetByUserID(@Principal_ID)  
        END ELSE BEGIN  
            SELECT @Principal_Name = Name FROM mdm.tblUserGroup WHERE ID = @Principal_ID  
        END   
    END  
  
    IF @PrincipalType_Name IS NULL BEGIN  
        IF @PrincipalType_ID = 1 BEGIN  
            SELECT @PrincipalType_Name = N'User'  
        END ELSE BEGIN  
            SELECT @PrincipalType_Name = N'Group'  
        END   
    END  
  
    IF @Role_ID IS NULL BEGIN  
        --Create a new user account role for this user.  
        INSERT INTO mdm.tblSecurityRole (Name, EnterUserID, LastChgUserID) VALUES (N'Role for ' + @PrincipalType_Name + N' ' + @Principal_Name, @SystemUser_ID, @SystemUser_ID)  
        SET @Role_ID = SCOPE_IDENTITY()  
  
        INSERT INTO mdm.tblSecurityAccessControl (PrincipalType_ID, Principal_ID, Role_ID, Description, EnterUserID, LastChgUserID)   
        VALUES (@PrincipalType_ID, @Principal_ID, @Role_ID, @Principal_Name + N' ' + @PrincipalType_Name, @SystemUser_ID, @SystemUser_ID)  
    END   
  
    SELECT    @Description = @Securable_Name + N' ' + o.Name + N' (' + p.Name + N')'  
    FROM    mdm.tblSecurityObject o   
            INNER JOIN mdm.tblSecurityPrivilege p   
                ON o.ID = @Object_ID AND p.ID = @Privilege_ID  
  
    IF IsNull(@RoleAccess_ID, 0) > 0 BEGIN  
        IF EXISTS(SELECT 1 FROM mdm.tblSecurityRoleAccessMember WHERE ID = @RoleAccess_ID) BEGIN  
                IF @Privilege_ID = 4 -- delete  
                    EXEC mdm.udpSecurityPrivilegesMemberDeleteByRoleAccessID @SystemUser_ID, @RoleAccess_ID  
                ELSE BEGIN  
                    DECLARE @ExistingUserRoleAccess_ID INT  
                    DECLARE @RoleAccessPrincipalType_ID INT  
                    SELECT @RoleAccessPrincipalType_ID = PrincipalType_ID FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER WHERE RoleAccess_ID = @RoleAccess_ID  
                    IF @PrincipalType_ID = 1 AND @RoleAccessPrincipalType_ID = 2 BEGIN  
                        -- Create a user override of a user group privilege.  First see if the user already has an existing override explicit record.  
                        -- If so update it.  If not create a new one.  
                        SELECT    @ExistingUserRoleAccess_ID = RoleAccess_ID   
                        FROM    mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER rac   
                        WHERE    rac.Object_ID        = @Object_ID   
                        and        rac.Entity_ID        = @Entity_ID  
                        and        rac.Hierarchy_ID     = @Hierarchy_ID  
                        and        rac.HierarchyType_ID = @HierarchyType_ID  
                        and        rac.Item_ID          = @Item_ID  
                        and        rac.ItemType_ID      = @ItemType_ID  
                        and        rac.Member_ID        = @Member_ID  
                        and        rac.MemberType_ID    = @MemberType_ID  
                        and        rac.Principal_ID      = @Principal_ID  
                        AND        rac.PrincipalType_ID  = 1   
  
                        IF IsNull(@ExistingUserRoleAccess_ID, 0) = 0  
                            INSERT INTO mdm.tblSecurityRoleAccessMember (Role_ID, Object_ID, Privilege_ID, Version_ID, Entity_ID, ExplicitHierarchy_ID,DerivedHierarchy_ID, HierarchyType_ID, Item_ID, ItemType_ID, Member_ID, MemberType_ID, Description, EnterUserID, LastChgUserID)  
                                SELECT @Role_ID, Object_ID, @Privilege_ID, Version_ID, Entity_ID, CASE @HierarchyType_ID WHEN 0 THEN @Hierarchy_ID ELSE NULL END,CASE @HierarchyType_ID WHEN 1 THEN @Hierarchy_ID ELSE NULL END, HierarchyType_ID, Item_ID, ItemType_ID, Member_ID, MemberType_ID, Description, @SystemUser_ID, @SystemUser_ID FROM mdm.tblSecurityRoleAccessMember WHERE ID = @RoleAccess_ID  
                        ELSE  
                            UPDATE mdm.tblSecurityRoleAccessMember SET Privilege_ID = @Privilege_ID WHERE ID = @RoleAccess_ID   
                    END ELSE   
                        UPDATE mdm.tblSecurityRoleAccessMember SET Privilege_ID = @Privilege_ID WHERE ID = @RoleAccess_ID   
                END  
        END ELSE  
    BEGIN  
                INSERT INTO mdm.tblSecurityRoleAccessMember (Role_ID, Object_ID, Privilege_ID, Version_ID, Entity_ID, ExplicitHierarchy_ID,DerivedHierarchy_ID, HierarchyType_ID, Item_ID, ItemType_ID, Member_ID, MemberType_ID, Description, EnterUserID, LastChgUserID)  
                    VALUES(@Role_ID, @Object_ID, @Privilege_ID, @Version_ID, @Entity_ID, CASE @HierarchyType_ID WHEN 0 THEN @Hierarchy_ID ELSE NULL END,CASE @HierarchyType_ID WHEN 1 THEN @Hierarchy_ID ELSE NULL END, @HierarchyType_ID, @Item_ID, @ItemType_ID, @Member_ID, @MemberType_ID, @Description, @SystemUser_ID, @SystemUser_ID)  
                SELECT @RoleAccess_ID = SCOPE_IDENTITY()          
    END  
  
    END ELSE  
    BEGIN  
        INSERT INTO mdm.tblSecurityRoleAccessMember (Role_ID, Object_ID, Privilege_ID, Version_ID, Entity_ID, ExplicitHierarchy_ID,DerivedHierarchy_ID, HierarchyType_ID, Item_ID, ItemType_ID, Member_ID, MemberType_ID, Description, EnterUserID, LastChgUserID)  
            VALUES(@Role_ID, @Object_ID, @Privilege_ID, @Version_ID, @Entity_ID, CASE @HierarchyType_ID WHEN 0 THEN @Hierarchy_ID ELSE NULL END,CASE @HierarchyType_ID WHEN 1 THEN @Hierarchy_ID ELSE NULL END, @HierarchyType_ID, @Item_ID, @ItemType_ID, @Member_ID, @MemberType_ID, @Description, @SystemUser_ID, @SystemUser_ID)  
            SELECT @RoleAccess_ID = SCOPE_IDENTITY()          
    END  
            
          SELECT @Return_ID = @RoleAccess_ID  
          SELECT @Return_MUID = (SELECT MUID FROM mdm.tblSecurityRoleAccessMember WHERE ID = @RoleAccess_ID)  
  
    SET NOCOUNT OFF  
  
    --Put a msg onto the SB queue to process member security  
    EXEC mdm.udpSecurityMemberQueueSave   
        @Role_ID    = @Role_ID, -- update member count cache only for the user(s) that pertain(s) to the specified role.  
        @Version_ID = @Version_ID,   
        @Entity_ID  = @Entity_ID;  
  
END --proc
GO
