SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
    SELECT * FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL   
  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
         ra.ID        RoleAccess_ID  
        ,ra.MUID    RoleAccess_MUID  
        ,ra.Role_ID  
        ,ac.Principal_ID  
        ,CASE ac.PrincipalType_ID WHEN 1 THEN u.MUID ELSE ug.MUID END AS Principal_MUID  
        ,ac.PrincipalType_ID  
        ,CASE ac.PrincipalType_ID WHEN 1 THEN u.UserName ELSE ug.Name END AS Principal_Name  
        ,ra.[Object_ID]  
        ,so.Name [Object_Name]  
        ,ra.Model_ID  
        ,mdl.MUID Model_MUID  
        ,mdl.Name Model_Name  
        ,ra.Securable_ID  
        ,CASE   
            WHEN ra.Object_ID = 1 THEN --Model  
                (SELECT MUID FROM mdm.tblModel WHERE ID = ra.Securable_ID)  
            WHEN ra.Object_ID = 3 OR ra.Object_ID = 8 OR ra.Object_ID = 9 OR ra.Object_ID = 10 THEN --Entity  
                (SELECT MUID FROM mdm.tblEntity WHERE ID = ra.Securable_ID)  
            WHEN ra.Object_ID = 4 THEN --Attribute  
                (SELECT MUID FROM mdm.tblAttribute WHERE ID = ra.Securable_ID)  
            WHEN ra.Object_ID = 5 THEN --Attribute Group  
                (SELECT MUID FROM mdm.tblAttributeGroup WHERE ID = ra.Securable_ID)  
            END Securable_MUID  
        ,mdm.udfSecurableNameGetByObjectID(ra.Object_ID, ra.Securable_ID) Securable_Name  
        ,ra.Privilege_ID  
        ,IsNull(lcu.DisplayName,N'') AS LastChgUser  
        ,ra.LastChgDTM  
        ,CASE ac.PrincipalType_ID WHEN 1 THEN (Select [IsAdministrator] from mdm.viw_SYSTEM_SECURITY_USER_MODEL where User_ID=Principal_ID and ID=Model_ID)  ELSE 0 END AS IsModelAdministrator  
FROM    mdm.tblSecurityRole r  
        inner join mdm.tblSecurityAccessControl ac   
            on    r.ID = ac.Role_ID  
        inner join mdm.tblSecurityRoleAccess ra  
            on    ra.Role_ID = r.ID  
        inner join mdm.tblSecurityObject so  
            on ra.Object_ID = so.ID  
        inner join mdm.tblModel mdl  
            on    ra.Model_ID = mdl.ID  
        LEFT OUTER JOIN mdm.tblUser lcu   
            ON ra.LastChgUserID = lcu.ID  
        LEFT JOIN mdm.tblUserGroup ug   
            ON ac.PrincipalType_ID = 2 AND ac.Principal_ID = ug.ID  
        LEFT JOIN mdm.tblUser u   
            ON ac.PrincipalType_ID = 1 AND ac.Principal_ID = u.ID
GO
GRANT SELECT ON  [mdm].[viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL] TO [mds_exec]
GO
