SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, June 13, 2006  
Function   : mdm.udfSecurityUserExplicitPermissions  
Component  : Security  
Description: mdm.udfSecurityUserExplicitPermissions returns a list of objects and privileges available for a user (read, update, or deny).  
  
SELECT * FROM mdm.udfSecurityUserExplicitPermissions(1,11,1,0,NULL)  
SELECT * FROM mdm.udfSecurityUserExplicitPermissions(1,27,1,1,NULL)  
SELECT * FROM mdm.udfSecurityUserExplicitPermissions(2,1,1,NULL)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityUserExplicitPermissions]   
(  
	@Principal_ID				INT,  
	@PrincipalType_ID			INT,  
	@IncludeGroupAssignments	BIT,  
	@Object_ID					INT = NULL  
)  
RETURNS @UserPermissions TABLE   
(  
			RoleAccess_ID INT,   
			RoleAccess_MUID UNIQUEIDENTIFIER,   
			[Object_ID] INT,   
			[Object_Name] NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,  
			Model_ID INT,   
			Model_MUID UNIQUEIDENTIFIER,   
			ID INT,  
			MUID UNIQUEIDENTIFIER,   
			[Name] NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,  
			Privilege_ID INT,   
			SourceUserGroup_ID INT,   
			SourceUserGroup_MUID UNIQUEIDENTIFIER,   
			SourceUserGroup_Name NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,  
			LastChgUser NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,  
			LastChgDTM DATETIME2(3)  
)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
INSERT INTO @UserPermissions  
SELECT  
		rac.RoleAccess_ID,  
		rac.RoleAccess_MUID,  
		rac.[Object_ID],  
		rac.[Object_Name],  
		rac.Model_ID,  
		rac.Model_MUID,  
		rac.Securable_ID ID,  
		rac.Securable_MUID MUID,  
		rac.Securable_Name Name,  
		rac.Privilege_ID,  
		Null,  
		Null,  
		Null,  
		rac.LastChgUser,  
		rac.LastChgDTM  
FROM	mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL rac  
WHERE	rac.PrincipalType_ID = @PrincipalType_ID  
and		rac.Principal_ID = @Principal_ID  
and		rac.Object_ID = ISNULL(@Object_ID, rac.Object_ID)  
  
IF (@PrincipalType_ID = 1) AND (IsNull(@IncludeGroupAssignments,0) = 1) BEGIN  
	-- Explicit Object permissions inherited from group assignments  
	INSERT INTO @UserPermissions  
	SELECT  
			rac.RoleAccess_ID,  
			rac.RoleAccess_MUID,  
			rac.[Object_ID],  
			rac.[Object_Name],  
			rac.Model_ID,  
			rac.Model_MUID,  
			rac.Securable_ID ID,  
			rac.Securable_MUID MUID,  
			rac.Securable_Name Name,  
			rac.Privilege_ID,  
			rac.Principal_ID,  
			rac.Principal_MUID,  
			rac.Principal_Name,   
			rac.LastChgUser,  
			rac.LastChgDTM  
	FROM	mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL rac  
	WHERE	rac.PrincipalType_ID = 2  
	and		rac.Role_ID IN (SELECT Role_ID FROM mdm.viw_SYSTEM_SECURITY_USER_ROLE WHERE User_ID = @Principal_ID)  
	and		rac.Object_ID = ISNULL(@Object_ID, rac.Object_ID)  
  
END  
  
RETURN  
END
GO
