SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    SELECT * FROM mdm.viw_SYSTEM_SECURITY_USER_MODEL;  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_MODEL]  
/*WITH SCHEMABINDING*/  
AS  
-- Determine Model effective permissions.  In order for a user to be a model administrator he  
-- must have total update permission for all model metadata components and all member data.  If    
-- read only and/or update member permissions exists for hierarchy parent nodes then those nodes   
-- are the only ones the user is allowed to see, thus the other nodes are restricted.  In this  
-- case the user would not be a model administrator.  The only exception to this is if the member   
-- permission is update on the root node.  
  
WITH modelPerm AS  
(  
    SELECT  
         ssu.[User_ID]  
        ,ssu.Model_ID  
        ,MIN(ssu.Model_PrivilegeID) Model_Privilege_ID -- Get the user's effective model permission  
        ,MAX(CASE ssu.Privilege_ID WHEN 2/*Update*/ THEN 0 ELSE 1 END) HasNonUpdatePermission -- Determine if the user has any non-Update permission on any model object (e.g. Model, Entity, Attribute, etc). Used for determining if the user is a model admin  
     FROM mdm.viw_SYSTEM_SECURITY_USER ssu  
     GROUP BY  
         ssu.[User_ID]  
        ,ssu.Model_ID  
),  
memberPerm AS  
(  
    SELECT DISTINCT  
         usr.[User_ID]  
        ,mv.Model_ID  
     FROM mdm.tblSecurityRoleAccessMember sra  
     INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_ROLE usr  
        ON sra.Role_ID = usr.Role_ID  
     LEFT JOIN mdm.tblModelVersion mv  
        ON sra.Version_ID = mv.ID  
     WHERE  
            sra.Member_ID <> 0/*ROOT*/   
        OR (sra.Member_ID = 0/*ROOT*/ AND sra.Privilege_ID <> 2/*Update*/) -- User can have update on ROOT and still be model admin  
)  
SELECT   
     modelPerm.[User_ID] [User_ID]  
    ,modelPerm.Model_ID ID  
    ,modelPerm.Model_Privilege_ID Privilege_ID  
    ,CASE WHEN modelPerm.Model_Privilege_ID = 2/*Update*/ -- User must have update permission on model to be model admin   
          AND modelPerm.HasNonUpdatePermission = 0 -- If the user has any non-Update model (object) permission, then the user is not a model admin    
          AND memberPerm.Model_ID IS NULL           -- If the user has any member permissions (except for Update on ROOT), then the user is not a model admin    
     THEN 1 ELSE 0 END AS IsAdministrator  
FROM modelPerm  
LEFT JOIN memberPerm  
    ON     modelPerm.[User_ID] = memberPerm.[User_ID]  
       AND modelPerm.Model_ID  = memberPerm.Model_ID  
WHERE modelPerm.[User_ID] > 1 -- Exclude the super user from this query. It will be added in the below UNION clause.  
  
     
-- Add the super user with admin rights to all models  
UNION  
SELECT   
    1, --super user ID  
    ID,   
    2, --Always granted update access to all Models  
    1  
FROM   
    mdm.tblModel
GO
GRANT SELECT ON  [mdm].[viw_SYSTEM_SECURITY_USER_MODEL] TO [mds_exec]
GO
