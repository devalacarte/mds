SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpSecurityPrivilegesDeleteByPrincipalID 1,1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesDeleteByPrincipalID]  
(  
	@Principal_ID				INT,  
	@PrincipalType_ID			INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DELETE  
	FROM	mdm.tblSecurityRoleAccess  
	WHERE	ID IN (  
			select	ra.ID  
			from	mdm.tblSecurityAccessControl ac   
					inner join mdm.tblSecurityRoleAccess ra   
						on ac.PrincipalType_ID = @PrincipalType_ID  and ac.Principal_ID = @Principal_ID  
						and ra.Role_ID = ac.Role_ID)  
	   
	DELETE  
	FROM	mdm.tblSecurityRoleAccessMember  
	WHERE	ID IN (  
			select	ra.ID  
			from	mdm.tblSecurityAccessControl ac   
					inner join mdm.tblSecurityRoleAccessMember ra   
						on ac.PrincipalType_ID = @PrincipalType_ID  and ac.Principal_ID = @Principal_ID  
						and ra.Role_ID = ac.Role_ID)  
  
	SET NOCOUNT OFF  
END --proc
GO
