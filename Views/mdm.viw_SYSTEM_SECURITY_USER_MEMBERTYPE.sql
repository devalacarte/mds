SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    SELECT * FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE ORDER BY User_ID, Entity_ID, ID  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_MEMBERTYPE]  
/*WITH SCHEMABINDING*/  
AS  
SELECT   
    User_ID,  
    Entity_ID,  
    ID,  
    MIN(Privilege_ID) Privilege_ID  
FROM   
    (  
    SELECT  
        tTyp.User_ID,  
        tTyp.Entity_ID,  
        tTyp.ID,  
        Privilege_ID =   
            CASE  
                WHEN tTyp.Privilege_ID = 1 -- The owning Entity has Deny permission.  
                    OR (tTyp.Privilege_ID <> 99 -- The owning Entity's permission is not inferred.  
                        AND NULLIF(tExp.MemberType_PrivilegeID, 99) IS NULL) -- The Member Type does not have an explicit privilege.  
                THEN tTyp.Privilege_ID -- use inherited Entity permission  
                ELSE tExp.MemberType_PrivilegeID -- use Member Type permission  
            END  
    FROM  
        mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE_LIST tTyp  
        LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER tExp  
            ON  
                tTyp.Entity_ID  = tExp.Entity_ID AND  
                tTyp.ID         = tExp.MemberType_ID AND  
                tTyp.User_ID    = tExp.User_ID  
    ) tSec  
WHERE   
    Privilege_ID IS NOT NULL   
GROUP BY   
    User_ID,  
    Entity_ID,  
    ID
GO
