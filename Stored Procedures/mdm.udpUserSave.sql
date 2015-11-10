SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
New: mdm.udpUserSave 1, NULL, 'S-1-5-21-124325095-708259737-1543119021-192248','DOMAIN\user', 1, 'Joe User','Marketing Manager','joe.user@domain.com'  
Update: mdm.udpUserSave 1, 4, 'S-1-5-21-124325095-708259737-1543119021-192248','DOMAIN\user', 1, 'Joe User','Marketing Manager','joe.user@domain.com'  
select * from mdm.tblUser  
  
If @User_ID is not specified, an attempt will be made to find a matching  
record by @SID and @UserName. If found, that record will be updated rather  
than inserting a duplicate user.  
*/  
CREATE PROCEDURE [mdm].[udpUserSave]  
(  
   @SystemUser_ID    INT,                   -- Person performing save  
   @User_ID          INT = NULL,            -- Existing record to update or NULL  
   @SID              NVARCHAR(250) = NULL,  -- Security identifier  
   @UserName         NVARCHAR(100) = NULL,  -- Username  
   @Status_ID        INT = NULL,            -- 1=Active, 2=Delete, 3=Copy  
   @DisplayName      NVARCHAR(256) = NULL,  
   @Description      NVARCHAR(500) = NULL,  
   @EmailAddress     NVARCHAR(100) = NULL,  
   @Return_ID        INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @NewUser_ID	INT  
    DECLARE @Role_ID	INT  
    DECLARE @NewRole_ID INT  
  
    -- If no @User_ID is specified, attempt to find a record to update  
    -- based on security identifier and user name.  
    IF @User_ID IS NULL  
       BEGIN  
          SELECT   
             @User_ID = ID  
          FROM  
             mdm.tblUser  
          WHERE  
             ((SID IS NULL AND @SID IS NULL) OR SID = @SID)  
             AND UserName = @UserName  
       END  
  
    IF (@Status_ID = 1) AND (EXISTS (SELECT ID FROM mdm.tblUser WHERE ID = @User_ID))  
       BEGIN  
           
          UPDATE  
             mdm.tblUser  
          SET  
             Status_ID = ISNULL(@Status_ID,Status_ID),  
             SID = ISNULL(@SID, SID),  
             UserName = ISNULL(@UserName, UserName),  
             DisplayName = ISNULL(@DisplayName,DisplayName),  
             Description = ISNULL(@Description,Description),  
             EmailAddress = ISNULL(@EmailAddress,EmailAddress),  
             LastChgUserID = @SystemUser_ID,  
             LastChgDTM = GETUTCDATE()  
          FROM  
             mdm.tblUser  
          WHERE  
             ID = @User_ID  
         
          SELECT @Return_ID = @User_ID  
            
          SELECT	@Role_ID = Role_ID  
            FROM	mdm.tblSecurityAccessControl  
            WHERE	Principal_ID = @User_ID  
            AND		PrincipalType_ID = 1;		    
            
          UPDATE mdm.tblSecurityRole SET [Name] = CAST(N'Role for User ' + @UserName AS NVARCHAR(115)) WHERE ID = @Role_ID  
            
          UPDATE mdm.tblSecurityAccessControl SET Description = CAST(@UserName + N' User' AS NVARCHAR(110)) WHERE Role_ID = @Role_ID  
            
       END  
    ELSE  
       BEGIN  
          INSERT INTO mdm.tblUser  
             (  
             [Status_ID],  
             [SID],  
             [UserName],  
             [DisplayName],  
             [Description],  
             [EmailAddress],  
             [LastLoginDTM],  
             [EnterDTM],  
             [EnterUserID],  
             [LastChgDTM],  
             [LastChgUserID]  
             )  
          SELECT  
             1,  
             @SID,  
             @UserName,  
             ISNULL(@DisplayName,N''),  
             ISNULL(@Description,N''),     
             ISNULL(@EmailAddress,N''),  
             NULL,  
             GETUTCDATE(),  
             @SystemUser_ID,  
             GETUTCDATE(),  
             @SystemUser_ID      
  
          SELECT @NewUser_ID=SCOPE_IDENTITY()  
  
          IF @Status_ID = 3 BEGIN  
            -- Copy User's group assignments  
            INSERT	INTO mdm.tblUserGroupAssignment (UserGroup_ID, [User_ID], EnterUserID, LastChgUserID)  
            SELECT	UserGroup_ID, @NewUser_ID, @SystemUser_ID, @SystemUser_ID  
            FROM	mdm.tblUserGroupAssignment   
            WHERE	User_ID = @User_ID;  
  
            -- Copy User's function assignments  
            INSERT	INTO mdm.tblNavigationSecurity (Navigation_ID, Foreign_ID, ForeignType_ID, EnterUserID, LastChgUserID, Permission_ID)  
            SELECT	Navigation_ID, @NewUser_ID, ForeignType_ID, @SystemUser_ID, @SystemUser_ID, Permission_ID  
            FROM	mdm.tblNavigationSecurity  
            WHERE	Foreign_ID = @User_ID  
            AND		ForeignType_ID = 1;  
  
            -- Copy User's security assignments  
            SELECT	@Role_ID = Role_ID  
            FROM	mdm.tblSecurityAccessControl  
            WHERE	Principal_ID = @User_ID  
            AND		PrincipalType_ID = 1;  
  
            INSERT INTO mdm.tblSecurityRole (Name) VALUES (CAST(N'Role for User ' + @UserName AS NVARCHAR(115)))  
            SET @NewRole_ID = SCOPE_IDENTITY()  
  
            INSERT INTO mdm.tblSecurityAccessControl (PrincipalType_ID, Principal_ID, Role_ID, Description)   
            VALUES (1, @NewUser_ID, @NewRole_ID, CAST(@UserName + N' User' AS NVARCHAR(110)))  
  
            INSERT INTO mdm.tblSecurityRoleAccess (Role_ID, Object_ID, Privilege_ID, Model_ID, Securable_ID, Description, EnterDTM, EnterUserID, LastChgDTM, LastChgUserID)   
            SELECT	@NewRole_ID, Object_ID, Privilege_ID, Model_ID, Securable_ID, Description, GETUTCDATE(), @SystemUser_ID, GETUTCDATE(), @SystemUser_ID  
            FROM	mdm.tblSecurityRoleAccess  
            WHERE	Role_ID = @Role_ID  
  
            INSERT INTO mdm.tblSecurityRoleAccessMember (Role_ID, Object_ID, Privilege_ID, Version_ID, Entity_ID, ExplicitHierarchy_ID,DerivedHierarchy_ID, HierarchyType_ID, Item_ID, ItemType_ID, Member_ID, MemberType_ID, Description, IsInitialized, EnterDTM, EnterUserID, LastChgDTM, LastChgUserID)   
            SELECT	@NewRole_ID, Object_ID, Privilege_ID, Version_ID, Entity_ID, CASE HierarchyType_ID WHEN 0 THEN Hierarchy_ID ELSE NULL END,CASE HierarchyType_ID WHEN 1 THEN Hierarchy_ID ELSE NULL END, HierarchyType_ID, Item_ID, ItemType_ID, Member_ID, MemberType_ID, Description, IsInitialized, GETUTCDATE(), @SystemUser_ID, GETUTCDATE(), @SystemUser_ID  
            FROM	mdm.tblSecurityRoleAccessMember  
            WHERE	Role_ID = @Role_ID  
          END  
  
          SELECT @Return_ID = @NewUser_ID  
  
       END  
  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR500055|The user cannot be saved. A database error occurred.', 16, 1);  
            RETURN(1)       
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
