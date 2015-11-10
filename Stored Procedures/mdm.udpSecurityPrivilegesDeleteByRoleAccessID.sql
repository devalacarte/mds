SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpSecurityPrivilegesDeleteByRoleAccessID 100  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesDeleteByRoleAccessID]  
(  
	@RoleAccess_ID		INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DELETE FROM mdm.tblSecurityRoleAccess WHERE ID = @RoleAccess_ID  
  
	SET NOCOUNT OFF  
END --proc
GO
