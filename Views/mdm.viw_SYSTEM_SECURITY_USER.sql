SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER]  
--SELECT * FROM mdm.viw_SYSTEM_SECURITY_USER  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
    tUserAccess.User_ID,  
    tRole.Role_ID,  
    tRole.Model_ID,   
    tRole.Model_PrivilegeID,   
    tRole.Model_IsExplicit,  
    tRole.Entity_ID,   
    tRole.Entity_PrivilegeID,   
    tRole.Entity_IsExplicit,  
    tRole.MemberType_ID,   
    tRole.MemberType_PrivilegeID,   
    tRole.MemberType_IsExplicit,  
    tRole.Attribute_ID,   
    tRole.Attribute_PrivilegeID,   
    tRole.Attribute_IsExplicit,  
    tRole.Privilege_ID,   
    tUserAccess.IsUserGroupAssignment  
FROM  
    mdm.viw_SYSTEM_SECURITY_ROLE tRole  
    JOIN mdm.viw_SYSTEM_SECURITY_USER_ROLE tUserAccess ON tRole.Role_ID = tUserAccess.Role_ID
GO
