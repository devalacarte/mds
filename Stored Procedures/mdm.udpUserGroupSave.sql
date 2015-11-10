SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpUserGroupSave 1,1,1,'Administrators','Administrators for all of MDS'  
select * from mdm.tblUserGroup  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupSave]  
(  
    @SystemUser_ID		INT,                   -- Person performing save  
    @UserGroup_ID		INT = NULL,            -- Existing record to update or NULL  
    @UserGroupType_ID	INT = NULL,            -- The type for the user group.  
    @Status_ID			INT = NULL,            -- 1=Active, 2=Delete, 3=Copy  
    @SID				NVARCHAR(250) = NULL,  -- Security identifier  
    @Name				NVARCHAR(355) = NULL,  
    @Description		NVARCHAR(256) = NULL,  
    @Return_ID			INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @NewUserGroup_ID	INT  
    DECLARE @Role_ID			INT  
    DECLARE @NewRole_ID			INT  
  
    -- If no @UserGroup_ID is specified, attempt to find a record to update  
    -- based on security identifier and group name.  
    IF @UserGroup_ID IS NULL  
       BEGIN  
          SELECT   
             @UserGroup_ID = ID  
          FROM  
             mdm.tblUserGroup  
          WHERE  
             ((SID IS NULL AND @SID IS NULL) OR SID = @SID)  
             AND Name = @Name  
       END  
  
    IF (@Status_ID = 1 AND EXISTS(SELECT 1 FROM mdm.tblUserGroup WHERE ID = @UserGroup_ID)) BEGIN  
      
        UPDATE mdm.tblUserGroup SET  
            UserGroupType_ID = ISNULL(@UserGroupType_ID, UserGroupType_ID),  
            Status_ID = ISNULL(@Status_ID, Status_ID),  
            [SID] = ISNULL(@SID, [SID]),  
            [Name] = ISNULL(@Name, [Name]),  
            [Description] = ISNULL(@Description, [Description]),  
            LastChgUserID = @SystemUser_ID,  
            LastChgDTM = GETUTCDATE()  
        FROM mdm.tblUserGroup  
        WHERE ID = @UserGroup_ID;  
  
        SET @Return_ID = @UserGroup_ID;  
          
        SELECT	@Role_ID = Role_ID  
            FROM	mdm.tblSecurityAccessControl  
            WHERE	Principal_ID = @UserGroup_ID  
            AND		PrincipalType_ID = 2;  
        UPDATE mdm.tblSecurityRole SET [Name] = N'Role for Group ' + @Name WHERE ID = @Role_ID  
        UPDATE mdm.tblSecurityAccessControl SET [Description] = CAST(@Name + N' Group' AS NVARCHAR(110)) WHERE Role_ID = @Role_ID  
    END ELSE BEGIN  
      
        INSERT INTO mdm.tblUserGroup  
        (  
            [UserGroupType_ID],  
            [Status_ID],  
            [SID],  
            [Name],  
            [Description],  
            [EnterUserID],  
            [LastChgUserID]  
        )  
        SELECT  
            @UserGroupType_ID,  
            1,  
            @SID,  
            ISNULL(@Name, N''),  
            ISNULL(@Description, N''),  
            @SystemUser_ID,  
            @SystemUser_ID;  
  
        SET @NewUserGroup_ID = SCOPE_IDENTITY();  
        SET @Return_ID = @NewUserGroup_ID;  
  
        IF @Status_ID = 3 BEGIN  
            -- Copy User group's user assignments  
            INSERT	INTO mdm.tblUserGroupAssignment (UserGroup_ID, [User_ID], EnterUserID, LastChgUserID)  
            SELECT	@NewUserGroup_ID, [User_ID], @SystemUser_ID, @SystemUser_ID  
            FROM	mdm.tblUserGroupAssignment   
            WHERE	UserGroup_ID = @UserGroup_ID;  
  
            -- Copy User group's function assignments  
            INSERT	INTO mdm.tblNavigationSecurity (Navigation_ID, Foreign_ID, ForeignType_ID, EnterUserID, LastChgUserID, Permission_ID)  
            SELECT	Navigation_ID, @NewUserGroup_ID, ForeignType_ID, @SystemUser_ID, @SystemUser_ID, Permission_ID  
            FROM	mdm.tblNavigationSecurity  
            WHERE	Foreign_ID = @UserGroup_ID  
            AND		ForeignType_ID = 2;  
  
            -- Copy User group's security assignments  
            SELECT	@Role_ID = Role_ID  
            FROM	mdm.tblSecurityAccessControl  
            WHERE	Principal_ID = @UserGroup_ID  
            AND		PrincipalType_ID = 2;  
  
            INSERT INTO mdm.tblSecurityRole (Name) VALUES (N'Role for Group ' + @Name)  
            SET @NewRole_ID = SCOPE_IDENTITY()  
  
            INSERT INTO mdm.tblSecurityAccessControl (PrincipalType_ID, Principal_ID, Role_ID, Description)   
            VALUES (2, @NewUserGroup_ID, @NewRole_ID, CAST(@Name + N' Group' AS NVARCHAR(110)))  
  
            INSERT INTO mdm.tblSecurityRoleAccess (Role_ID, Object_ID, Privilege_ID, Model_ID, Securable_ID, Description, EnterDTM, EnterUserID, LastChgDTM, LastChgUserID)   
            SELECT	@NewRole_ID, Object_ID, Privilege_ID, Model_ID, Securable_ID, Description, GETUTCDATE(), @SystemUser_ID, GETUTCDATE(), @SystemUser_ID  
            FROM	mdm.tblSecurityRoleAccess  
            WHERE	Role_ID = @Role_ID  
  
            INSERT INTO mdm.tblSecurityRoleAccessMember (Role_ID, Object_ID, Privilege_ID, Version_ID, Entity_ID, ExplicitHierarchy_ID,DerivedHierarchy_ID, HierarchyType_ID, Item_ID, ItemType_ID, Member_ID, MemberType_ID, Description, EnterDTM, EnterUserID, LastChgDTM, LastChgUserID)   
            SELECT	@NewRole_ID, Object_ID, Privilege_ID, Version_ID, Entity_ID, CASE HierarchyType_ID WHEN 0 THEN Hierarchy_ID ELSE NULL END,CASE HierarchyType_ID WHEN 1 THEN Hierarchy_ID ELSE NULL END, HierarchyType_ID, Item_ID, ItemType_ID, Member_ID, MemberType_ID, Description, GETUTCDATE(), @SystemUser_ID, GETUTCDATE(), @SystemUser_ID  
            FROM	mdm.tblSecurityRoleAccessMember  
            WHERE	Role_ID = @Role_ID  
        END; --if  
  
    END; --if  
  
    IF @@ERROR <> 0 BEGIN  
        RAISERROR('MDSERR500060|The group cannot be saved. A database error occurred.', 16, 1);  
        RETURN(1)	      
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
