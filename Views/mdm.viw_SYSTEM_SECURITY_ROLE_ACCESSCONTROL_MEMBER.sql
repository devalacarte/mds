SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT * FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER]  
/*WITH SCHEMABINDING*/  
AS  
SELECT     ra.ID AS RoleAccess_ID, ra.MUID AS RoleAccess_MUID, ra.Role_ID, ac.Principal_ID, ac.PrincipalType_ID,     
                      CASE ac.PrincipalType_ID WHEN 1 THEN u.MUID ELSE ug.MUID END AS Principal_MUID,     
                      CASE ac.PrincipalType_ID WHEN 1 THEN u.UserName ELSE ug.Name END AS Principal_Name,   
                      ra.Version_ID, modv.MUID AS Version_MUID, modv.Name as Version_Name, ra.Object_ID,     
                      ent.Model_ID, mod.MUID AS Model_MUID, mod.Name as Model_Name, ra.Entity_ID, ent.MUID AS Entity_MUID, ent.Name as Entity_Name,   
                      ra.Hierarchy_ID, ISNULL(hi.MUID, dh.MUID) AS Hierarchy_MUID, ISNULL(hi.Name, dh.Name) AS Hierarchy_Name,ra.HierarchyType_ID,   
                      ra.Item_ID, ra.ItemType_ID, ra.Member_ID, ra.MemberType_ID, ra.Privilege_ID, ISNULL(lcu.DisplayName, N'') AS LastChgUser,     
                      ra.LastChgDTM    
FROM        mdm.tblSecurityRole AS r   
            INNER JOIN mdm.tblSecurityAccessControl AS ac ON r.ID = ac.Role_ID  
            INNER JOIN mdm.tblSecurityRoleAccessMember AS ra ON ra.Role_ID = r.ID  
            LEFT OUTER JOIN mdm.tblHierarchy AS hi ON ra.Hierarchy_ID = hi.ID and ra.HierarchyType_ID = 0  
            LEFT OUTER JOIN mdm.tblDerivedHierarchy as dh on ra.Hierarchy_ID = dh.ID and ra.HierarchyType_ID = 1  
            LEFT OUTER JOIN mdm.tblEntity AS ent ON ra.Entity_ID = ent.ID   
            LEFT OUTER JOIN mdm.tblModel AS mod ON ent.Model_ID = mod.ID  
            LEFT OUTER JOIN mdm.tblModelVersion AS modv ON ra.Version_ID = modv.ID  
            LEFT OUTER JOIN mdm.tblUser AS lcu ON ra.LastChgUserID = lcu.ID   
            LEFT OUTER JOIN mdm.tblUserGroup AS ug ON ac.PrincipalType_ID = 2 AND ac.Principal_ID = ug.ID   
            LEFT OUTER JOIN mdm.tblUser AS u ON ac.PrincipalType_ID = 1 AND ac.Principal_ID = u.ID
GO
GRANT SELECT ON  [mdm].[viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER] TO [mds_exec]
GO
