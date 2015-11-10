SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpSecurityPrivilegesSummaryGet 118,1,1,0  
EXEC mdm.udpSecurityPrivilegesSummaryGet 1,11,1,1,NULL  
EXEC mdm.udpSecurityPrivilegesSummaryGet 1,11,1,1,6  
EXEC mdm.udpSecurityPrivilegesSummaryGet 1,1,2,1  
EXEC mdm.udpSecurityPrivilegesSummaryGet 118,27,1,1,NULL  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesSummaryGet]  
   (  
	@SystemUser_ID				INT,  
	@Principal_ID				INT,  
	@PrincipalType_ID			INT,  
	@IncludeGroupAssignments	BIT = NULL,  
	@Model_ID				INT = NULL  
   )  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SELECT   
		 xp.RoleAccess_ID  
		,xp.RoleAccess_MUID  
		,sp.ID					Privilege_ID  
		,sp.Name				Privilege_Name  
		,xp.[Object_ID]         ObjectType_ID  
		,xp.[Object_Name]       ObjectType_Name  
		,xp.ID					Securable_ID  
		,xp.MUID				Securable_MUID  
		,xp.Name				Securable_Name  
		,xp.Model_ID			Model_ID  
		,xp.Model_MUID			Model_MUID  
		,models.Name	Model_Name  
		,xp.SourceUserGroup_ID  
		,xp.SourceUserGroup_MUID  
		,xp.SourceUserGroup_Name  
		,modSec.IsAdministrator	IsModelAdministrator  
	FROM  
		mdm.udfSecurityUserExplicitPermissions(@Principal_ID, @PrincipalType_ID, @IncludeGroupAssignments,NULL) xp  
		INNER JOIN mdm.tblSecurityPrivilege sp  
			ON xp.Privilege_ID = sp.ID  
		INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL modSec  
			ON	((@Model_ID IS NULL) OR (xp.Model_ID = @Model_ID))  
			AND modSec.User_ID = @SystemUser_ID AND modSec.ID = xp.Model_ID AND modSec.IsAdministrator = 1  
			   INNER JOIN mdm.tblModel models  
			On ((@Model_ID IS NULL) OR (xp.Model_ID = @Model_ID))   
			and models.ID = xp.Model_ID   
	ORDER BY sp.ID, Securable_Name  
  
  
	SET NOCOUNT OFF  
END --proc
GO
