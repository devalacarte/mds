SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesMemberDeleteByRoleAccessMUID]  
(  
	@SystemUser_ID          INT,  
	@RoleAccess_MUID        UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @RoleAccess_ID		INT  
  
    SELECT @RoleAccess_ID = (SELECT ID from mdm.tblSecurityRoleAccessMember WHERE MUID = @RoleAccess_MUID)  
  
    EXEC mdm.udpSecurityPrivilegesMemberDeleteByRoleAccessID @SystemUser_ID,@RoleAccess_ID  
  
    SET NOCOUNT OFF  
END --proc
GO
