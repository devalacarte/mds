SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
Create PROCEDURE [mdm].[udpSecurityPrivilegesDeleteByRoleAccessMUID]  
(  
	@RoleAccess_MUID		UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
	  
	DELETE FROM mdm.tblSecurityRoleAccess WHERE MUID = @RoleAccess_MUID  
  
	SET NOCOUNT OFF  
END --proc
GO
