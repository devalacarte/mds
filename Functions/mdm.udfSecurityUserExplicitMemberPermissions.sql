SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, June 13, 2006  
Function   : mdm.udfSecurityUserExplicitMemberPermissions  
Component  : Security  
Description: mdm.udfSecurityUserExplicitMemberPermissions returns a list of members and privileges available for a user (read, update, or deny).  
  
SELECT * FROM mdm.udfSecurityUserExplicitMemberPermissions(2,1,0,NULL)  
SELECT * FROM mdm.udfSecurityUserExplicitMemberPermissions(2,1,1,NULL) WHERE Entity_ID = 41  
SELECT * FROM mdm.udfSecurityUserExplicitMemberPermissions(2,1,1,12)  
SELECT * FROM mdm.udfSecurityUserExplicitMemberPermissions(11,1,1,NULL)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityUserExplicitMemberPermissions]   
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
			Principal_ID INT,   
			Principal_MUID UNIQUEIDENTIFIER,   
			PrincipalType_ID INT,   
			Principal_Name NVARCHAR(100) COLLATE DATABASE_DEFAULT,  
			Object_ID INT,   
			Version_ID INT,   
			Version_MUID UNIQUEIDENTIFIER,   
			Version_Name NVARCHAR(50) COLLATE DATABASE_DEFAULT,   
			Model_ID INT,   
			Model_MUID UNIQUEIDENTIFIER,   
			Model_Name NVARCHAR(50) COLLATE DATABASE_DEFAULT,   
			Entity_ID INT,   
			Entity_MUID UNIQUEIDENTIFIER,   
			Entity_Name NVARCHAR(50) COLLATE DATABASE_DEFAULT,   
			Hierarchy_ID INT,   
			Hierarchy_MUID UNIQUEIDENTIFIER,   
			HierarchyType_ID SMALLINT,   
			Item_ID INT,   
			ItemType_ID INT,   
			Member_ID INT,   
			MemberType_ID INT,   
			Privilege_ID INT,   
			SourceUserGroup_ID INT,   
			SourceUserGroup_Name NVARCHAR(100) COLLATE DATABASE_DEFAULT,  
			LastChgUser NVARCHAR(100) COLLATE DATABASE_DEFAULT,  
			LastChgDTM DATETIME2(3)  
)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
	-- Explicit Object permissions  
	INSERT INTO @UserPermissions  
	SELECT  
			rac.RoleAccess_ID,  
			rac.RoleAccess_MUID,  
			rac.Principal_ID ,   
			rac.Principal_MUID ,   
			rac.PrincipalType_ID,   
			rac.Principal_Name,  
			rac.Object_ID,  
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
			rac.Item_ID,  
			rac.ItemType_ID,  
			rac.Member_ID,  
			rac.MemberType_ID,  
			rac.Privilege_ID,  
			Null,  
			Null,  
			rac.LastChgUser,  
			rac.LastChgDTM  
	FROM	mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER rac  
	WHERE	rac.PrincipalType_ID = @PrincipalType_ID  
	and		rac.Principal_ID = @Principal_ID  
	and		rac.Object_ID = ISNULL(@Object_ID, rac.Object_ID)  
  
	IF (@PrincipalType_ID = 1) AND (IsNull(@IncludeGroupAssignments,0) = 1) BEGIN  
			INSERT INTO @UserPermissions  
			-- Explicit Object permissions inherited from group assignments  
			SELECT  
					DISTINCT  
  
					rac.RoleAccess_ID,  
					rac.RoleAccess_MUID,  
					rac.Principal_ID ,   
					rac.Principal_MUID ,   
					rac.PrincipalType_ID,   
					rac.Principal_Name,  
					rac.Object_ID,  
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
					rac.Item_ID,  
					rac.ItemType_ID,  
					rac.Member_ID,  
					rac.MemberType_ID,  
					rac.Privilege_ID,  
					rac.Principal_ID,  
					rac.Principal_Name,   
					rac.LastChgUser,  
					rac.LastChgDTM  
			FROM	mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER rac  
			WHERE	rac.PrincipalType_ID = 2  
			and		rac.Role_ID IN (SELECT Role_ID FROM mdm.viw_SYSTEM_SECURITY_USER_ROLE WHERE User_ID = @Principal_ID)  
			and		rac.Object_ID = ISNULL(@Object_ID, rac.Object_ID)  
		END  
  
	RETURN  
END --fn
GO
