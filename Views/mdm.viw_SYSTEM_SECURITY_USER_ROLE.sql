SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_ROLE]  
/*WITH SCHEMABINDING*/  
AS  
/*  
  PrincipalType_ID = 1 -- User  
  PrincipalType_ID = 2 -- User Group  
*/  
SELECT --Users  
   Principal_ID User_ID,   
   Role_ID,  
   0 IsUserGroupAssignment  
FROM   
   mdm.tblSecurityAccessControl   
WHERE   
   PrincipalType_ID = 1  
UNION   
SELECT --Users derived from group assignments   
   User_ID,   
   Role_ID,  
   1  
FROM   
   mdm.tblUserGroupAssignment tAssign  
   INNER JOIN mdm.tblSecurityAccessControl tRole ON tAssign.UserGroup_ID = tRole.Principal_ID and tRole.PrincipalType_ID = 2
GO
