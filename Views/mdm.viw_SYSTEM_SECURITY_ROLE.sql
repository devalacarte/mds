SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_ROLE]  
/*WITH SCHEMABINDING*/  
AS  
--Model permissions  
SELECT   
    tModSec.Role_ID,  
    tModSec.Model_ID,   
    tModSec.Privilege_ID Model_PrivilegeID,   
    1 Model_IsExplicit,  
    0 Entity_ID,   
    99 Entity_PrivilegeID,   
    0 Entity_IsExplicit,   
    0 MemberType_ID,   
    99 MemberType_PrivilegeID,   
    0 MemberType_IsExplicit,  
    0 Attribute_ID,   
    99 Attribute_PrivilegeID,   
    0 Attribute_IsExplicit,  
    tModSec.Privilege_ID Privilege_ID  
FROM   
   mdm.tblSecurityRoleAccess  tModSec   
WHERE Object_ID = 1 AND Status_ID = 1  
  
--Entity permissions (leaf member, consolidation, and collection member type security is defined at the entity level; i.e., the Securable_ID represents the entity)  
UNION  
SELECT   
    tEntSec.Role_ID,  
    tEnt.Model_ID,  
    CASE tEntSec.Privilege_ID WHEN 1 THEN NULL ELSE 99 END Model_PrivilegeID,  
    0 Model_IsExplicit,  
    tEnt.ID Entity_ID,  
    tEntSec.Privilege_ID Entity_PrivilegeID,  
    1 Entity_IsExplicit,  
    0 MemberType_ID,  
    99 MemberType_PrivilegeID,  
    0 MemberType_IsExplicit,  
    0 Attribute_ID,  
    99 Attribute_PrivilegeID,  
    0 Attribute_IsExplicit,  
    tEntSec.Privilege_ID Privilege_ID  
FROM mdm.tblEntity tEnt  
JOIN mdm.tblSecurityRoleAccess tEntSec  
     ON Object_ID = 3 AND Status_ID = 1   
     AND tEnt.ID = tEntSec.Securable_ID  
  
--Member type permissions (leaf member, consolidation, and collection member type security is defined at the entity level; i.e., the Securable_ID represents the entity)  
UNION  
SELECT   
    tTypSec.Role_ID,  
    tEnt.Model_ID,  
    CASE tTypSec.Privilege_ID WHEN 1 THEN NULL ELSE 99 END Model_PrivilegeID,  
    0 Model_IsExplicit,  
    tEnt.ID Entity_ID,  
    CASE tTypSec.Privilege_ID WHEN 1 THEN NULL ELSE 99 END Entity_PrivilegeID,  
    0 Entity_IsExplicit,  
    Object_ID-7 MemberType_ID,  
    tTypSec.Privilege_ID MemberType_PrivilegeID,  
    1 MemberType_IsExplicit,  
    0 Attribute_ID,  
    99 Attribute_PrivilegeID,  
    0 Attribute_IsExplicit,  
    tTypSec.Privilege_ID Privilege_ID  
FROM mdm.tblEntity tEnt  
JOIN mdm.tblSecurityRoleAccess tTypSec   
  ON Object_ID BETWEEN 8 AND 10 AND Status_ID = 1    
  AND tEnt.ID = tTypSec.Securable_ID  
  
UNION  
--Attribute permissions  
SELECT   
    tAttSec.Role_ID,  
    tEnt.Model_ID,   
    CASE tAttSec.Privilege_ID WHEN 1 THEN NULL ELSE 99 END Model_PrivilegeID,   
    0 Model_IsExplicit,  
    tAtt.Entity_ID,   
    CASE tAttSec.Privilege_ID WHEN 1 THEN NULL ELSE 99 END Entity_PrivilegeID,   
    0 Entity_IsExplicit,  
    tAtt.MemberType_ID,   
    CASE tAttSec.Privilege_ID WHEN 1 THEN NULL ELSE 99 END MemberType_PrivilegeID,   
    0 MemberType_IsExplicit,  
    tAtt.ID Attribute_ID,   
    tAttSec.Privilege_ID Attribute_PrivilegeID,   
    1 Attribute_IsExplicit,  
    tAttSec.Privilege_ID Privilege_ID   
FROM mdm.tblAttribute tAtt  
JOIN mdm.tblSecurityRoleAccess tAttSec   
  ON Object_ID = 4 AND Status_ID = 1    
  AND tAtt.ID = tAttSec.Securable_ID  
JOIN mdm.tblEntity tEnt ON tAtt.Entity_ID = tEnt.ID
GO
