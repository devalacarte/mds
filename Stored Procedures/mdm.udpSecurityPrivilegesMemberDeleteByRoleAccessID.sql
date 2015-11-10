SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
EXEC mdm.udpSecurityPrivilegesMemberDeleteByRoleAccessID 1, 100  
  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesMemberDeleteByRoleAccessID]  
(  
    @SystemUser_ID      INT,  
    @RoleAccess_ID      INT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @Role_ID        INT;  
    DECLARE @Version_ID     INT;  
    DECLARE @Entity_ID      INT;  
  
    SELECT   
        @Role_ID=Role_ID,  
        @Version_ID=Version_ID,  
        @Entity_ID=Entity_ID  
    FROM mdm.tblSecurityRoleAccessMember   
    WHERE ID = @RoleAccess_ID;  
  
    DELETE FROM mdm.tblSecurityRoleAccessMember WHERE ID = @RoleAccess_ID;  
  
    --Put a msg onto the SB queue to process member security  
    EXEC mdm.udpSecurityMemberQueueSave   
        @Role_ID    = @Role_ID, -- update member count cache only for the user(s) that pertain(s) to the specified role.  
        @Version_ID = @Version_ID,   
        @Entity_ID  = @Entity_ID;  
          
    SET NOCOUNT OFF  
END --proc
GO
