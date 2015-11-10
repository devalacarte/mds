SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
EXEC mdm.udpSecurityPrivilegesSave 1, 12, 1, 'cthompson', 'User', 1, 2, 1, 'Account', Null  
select * from mdm.tblSecurityRoleAccess  
select * from mdm.tblSecurityObject  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesSave]  
(  
    @SystemUser_ID        INT,  
    @Principal_ID        INT,  
    @PrincipalType_ID    INT,  
    @Principal_Name        NVARCHAR(100) = NULL,  
    @PrincipalType_Name NVARCHAR(20) = NULL,  
    @RoleAccess_ID        INT,  
    @Object_ID            INT,  
    @Privilege_ID        INT,  
    @Model_ID        INT,  
    @Securable_ID        INT,  
    @Securable_Name        NVARCHAR(100),  
    @RoleAccess_MUID    UNIQUEIDENTIFIER = NULL,  
    @Return_ID        INT = NULL OUTPUT,  
    @Return_MUID        UNIQUEIDENTIFIER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @Role_ID            INT  
    DECLARE @Description        NVARCHAR(100),  
    @NewUser_ID    INT  
  
    SELECT    @Role_ID = Role_ID  
    FROM    mdm.tblSecurityAccessControl  
    WHERE    Principal_ID = @Principal_ID  
    AND        PrincipalType_ID = @PrincipalType_ID  
  
    IF @Principal_Name IS NULL BEGIN  
        IF @PrincipalType_ID = 1 BEGIN  
            SELECT @Principal_Name = mdm.udfUserNameGetByUserID(@Principal_ID)  
        END ELSE BEGIN  
            SELECT @Principal_Name = [Name] FROM mdm.tblUserGroup WHERE ID = @Principal_ID  
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
        INSERT INTO mdm.tblSecurityRole ([Name], EnterUserID, LastChgUserID) VALUES (N'Role for ' + @PrincipalType_Name + N' ' + @Principal_Name, @SystemUser_ID, @SystemUser_ID)  
        SET @Role_ID = SCOPE_IDENTITY()  
  
        INSERT INTO mdm.tblSecurityAccessControl (PrincipalType_ID, Principal_ID, Role_ID, Description, EnterUserID, LastChgUserID)   
        VALUES (@PrincipalType_ID, @Principal_ID, @Role_ID, @Principal_Name + N' ' + @PrincipalType_Name, @SystemUser_ID, @SystemUser_ID)  
    END   
  
    IF IsNull(@Object_ID, 0) > 0   
        SELECT    @Description = @Securable_Name + N' ' + o.Name + N' (' + p.Name + N')'  
        FROM    mdm.tblSecurityObject o   
                INNER JOIN mdm.tblSecurityPrivilege p   
                    ON o.ID = @Object_ID AND p.ID = @Privilege_ID  
    ELSE  
        SELECT @Description = N''  
  
    IF IsNull(@RoleAccess_ID, 0) > 0 AND @RoleAccess_MUID IS NULL BEGIN  
        IF EXISTS(SELECT 1 FROM mdm.tblSecurityRoleAccess WHERE ID = @RoleAccess_ID) BEGIN  
                IF @Privilege_ID = 4 -- delete  
                    EXEC mdm.udpSecurityPrivilegesDeleteByRoleAccessID @RoleAccess_ID  
                ELSE BEGIN  
                    DECLARE @ExistingUserRoleAccess_ID INT  
                    DECLARE @RoleAccessPrincipalType_ID INT  
                    SELECT @RoleAccessPrincipalType_ID = PrincipalType_ID FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL WHERE RoleAccess_ID = @RoleAccess_ID  
                    IF @PrincipalType_ID = 1 AND @RoleAccessPrincipalType_ID = 2 BEGIN  
                        -- Create a user override of a user group privilege.  First see if the user already has an existing override explicit record.  
                        -- If so update it.  If not create a new one.  
                        SELECT @ExistingUserRoleAccess_ID = RoleAccess_ID   
                        FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL   
                        WHERE   
                            Securable_ID = @Securable_ID AND   
                            Object_ID = @Object_ID AND   
                            Principal_ID = @Principal_ID AND   
                            PrincipalType_ID = @PrincipalType_ID  
  
                        IF IsNull(@ExistingUserRoleAccess_ID, 0) = 0  
                            INSERT INTO mdm.tblSecurityRoleAccess (Role_ID, Object_ID, Model_ID, Privilege_ID, Securable_ID, Description, EnterUserID, LastChgUserID)  
                                SELECT @Role_ID, Object_ID, Model_ID, @Privilege_ID, Securable_ID, Description, @SystemUser_ID, @SystemUser_ID FROM mdm.tblSecurityRoleAccess WHERE ID = @RoleAccess_ID  
                        ELSE  
                            UPDATE mdm.tblSecurityRoleAccess SET Privilege_ID = @Privilege_ID WHERE ID = @ExistingUserRoleAccess_ID   
                    END ELSE   
                        UPDATE mdm.tblSecurityRoleAccess SET Privilege_ID = @Privilege_ID WHERE ID = @RoleAccess_ID   
                END  
        END ELSE  
            BEGIN  
            INSERT INTO mdm.tblSecurityRoleAccess (Role_ID, Object_ID, Model_ID, Privilege_ID, Securable_ID, Description, EnterUserID, LastChgUserID)  
                                        VALUES(@Role_ID, @Object_ID, @Model_ID, @Privilege_ID, @Securable_ID, @Description, @SystemUser_ID, @SystemUser_ID)  
            SELECT @NewUser_ID=SCOPE_IDENTITY()  
            END  
    END ELSE   
        BEGIN  
            SELECT @ExistingUserRoleAccess_ID = RoleAccess_ID   
            FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL   
            WHERE   
                Securable_ID = @Securable_ID AND   
                Object_ID = @Object_ID AND   
                Principal_ID = @Principal_ID AND   
                PrincipalType_ID = @PrincipalType_ID;  
  
            IF COALESCE(@ExistingUserRoleAccess_ID, 0) = 0  
            BEGIN  
                IF @RoleAccess_MUID IS NULL   
                BEGIN  
                    INSERT INTO mdm.tblSecurityRoleAccess (Role_ID, Object_ID, Model_ID, Privilege_ID, Securable_ID, Description, EnterUserID, LastChgUserID)  
                                                    VALUES(@Role_ID, @Object_ID, @Model_ID, @Privilege_ID, @Securable_ID, @Description, @SystemUser_ID, @SystemUser_ID)  
                END ELSE  
                BEGIN  
                    INSERT INTO mdm.tblSecurityRoleAccess (Role_ID, MUID, Object_ID, Model_ID, Privilege_ID, Securable_ID, Description, EnterUserID, LastChgUserID)  
                                                    VALUES(@Role_ID, @RoleAccess_MUID, @Object_ID, @Model_ID, @Privilege_ID, @Securable_ID, @Description, @SystemUser_ID, @SystemUser_ID)  
                END;  
            END ELSE   
            BEGIN  
                UPDATE mdm.tblSecurityRoleAccess   
                SET Privilege_ID = @Privilege_ID   
                WHERE ID = @ExistingUserRoleAccess_ID;  
            END;  
                                  
        SELECT @NewUser_ID=SCOPE_IDENTITY()  
        END  
  
            SELECT @Return_ID = @NewUser_ID  
          SELECT @Return_MUID = (SELECT MUID FROM mdm.tblSecurityRoleAccess WHERE ID = @NewUser_ID)  
      
    SET NOCOUNT OFF  
END --proc
GO
