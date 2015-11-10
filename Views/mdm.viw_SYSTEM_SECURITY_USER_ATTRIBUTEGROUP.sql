SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_ATTRIBUTEGROUP]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
    tRol.User_ID,  
    tAtt.Entity_ID,  
    tAtt.MemberType_ID,  
    tAtt.ID,   
    MIN(tAcc.Privilege_ID) Privilege_ID  
FROM   
    mdm.tblAttributeGroup tAtt  
    INNER JOIN mdm.tblSecurityRoleAccess tAcc  
        ON tAcc.Securable_ID = tAtt.ID AND  
           tAcc.Privilege_ID IS NOT NULL AND  
           tAcc.Object_ID = 5 /*AttriubteGroup*/ AND   
           tAcc.Status_ID = 1  
    LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ROLE tRol  
        ON tRol.Role_ID = tAcc.Role_ID  
WHERE  
    tRol.User_ID > 1 AND -- exclude the super user, which is handled below  
  
    -- Exclude users that do not have access to the owning member type.  
    NULLIF(  
       (SELECT MIN(tTypSec.Privilege_ID)   
        FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE tTypSec   
        WHERE   
            tTypSec.User_ID     = tRol.User_ID AND   
            tTypSec.Entity_ID   = tAtt.Entity_ID AND   
            tTypSec.ID          = tAtt.MemberType_ID)  
        , 1 /*Deny*/) IS NOT NULL  
GROUP BY   
    tRol.User_ID,  
    tAtt.Entity_ID,  
    tAtt.MemberType_ID,  
    tAtt.ID  
UNION  
  
-- Grant the super user access to all attribute groups  
SELECT  
    1 User_ID, -- super user ID  
    tAtt.Entity_ID,  
    tAtt.MemberType_ID,  
    tAtt.ID,   
    2 /*Update*/ Privilege_ID  
FROM mdm.tblAttributeGroup tAtt
GO
