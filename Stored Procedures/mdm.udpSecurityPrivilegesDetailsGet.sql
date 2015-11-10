SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpSecurityPrivilegesDetailsGet 1,1,1,124  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesDetailsGet]  
   (  
	@SystemUser_ID				INT,			-- Reserved for future use.  
	@Principal_ID				INT,			-- The Principal (user or user group) ID.  
	@PrincipalType_ID			INT,			-- Reserved for future use.  
	@RoleAccess_ID				INT	= NULL		-- Role Access ID.  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SELECT	  
		sp.ID       Privilege_ID,  
		sp.Name     Privilege_Name,  
		so.ID       ObjectType_ID,  
		so.Name     ObjectType_Name,  
		ra.Securable_ID,  
		mdm.udfSecurableNameGetByObjectID(ra.Object_ID, ra.Securable_ID) Securable_Name,  
		IsNull(eu.DisplayName,N'') AS EnterUserDisplayName,  
		ra.EnterDTM,  
		IsNull(lcu.DisplayName,N'') AS LastChgUserFullName,  
		ra.LastChgDTM,  
		IsNull(lcu.DisplayName,N'') + N' on ' + cast(ra.LastChgDTM as NVARCHAR(20)) AS LastChgBy,  
		grp.ID		SourceUserGroup_ID,  
		IsNull(grp.Name,N'')	SourceUserGroup_Name,  
		modSec.IsAdministrator	IsModelAdministrator  
	FROM  
		mdm.tblSecurityRoleAccess ra  
		INNER JOIN mdm.tblSecurityRole r   
			ON ra.Role_ID = r.ID  
		INNER JOIN mdm.tblSecurityAccessControl ac  
			ON ac.Role_ID = ra.Role_ID  
		INNER JOIN mdm.tblSecurityObject so   
			ON ra.Object_ID = so.ID  
		INNER JOIN mdm.tblSecurityPrivilege sp  
			ON ra.Privilege_ID = sp.ID  
		INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL modSec  
			ON modSec.User_ID = @SystemUser_ID AND modSec.ID = ra.Model_ID  
		LEFT OUTER JOIN mdm.tblUser eu ON ra.EnterUserID = eu.ID   
		LEFT OUTER JOIN mdm.tblUser lcu ON ra.LastChgUserID = lcu.ID  
		LEFT OUTER JOIN mdm.tblUserGroup grp  
			ON grp.ID = ac.Principal_ID and ac.PrincipalType_ID = 2  
	WHERE  
		ra.ID = @RoleAccess_ID  
			  
	SET NOCOUNT OFF  
END --proc
GO
