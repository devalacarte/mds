SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_ENTITY]  
/*WITH SCHEMABINDING*/  
AS  
/*  
Determines the effective permissions for each entity. Effective permissions are determined based on the following:  
  
1) If the Model privilege is DENY use it  
2) Else if the Model privilege is explicitly assigned and the Entity privilege is Inferred or NULL, use the Model privilege  
3) Else if the Entity does not have any privileges (i.e. the Entity privilege record is NULL), try the following:  
    A) Check for an inferred privilege from contained Attribute,  
    B) Check for an inferred privilege from a referring Entity that uses this Entity as a DBA.  
4) Else if the Entity Privilege is NOT (NULL or Inferred), it was explicitly assigned so use it directly (this is the final ELSE statement).  
  
*/  
SELECT   
    tSec.User_ID,  
    tSec.Model_ID,  
    tSec.ID,  
    MIN(tSec.Privilege_ID) Privilege_ID,  
    tSec.Is_Entity_DBA,  
    tSec.DBA_MemberType_ID  
FROM   
    (  
    SELECT    
        tModSec.User_ID,    
        tModSec.ID Model_ID,     
        tEnt.ID,  
        Is_Entity_DBA =   
            CASE      
                WHEN refEntity.Is_Entity_DBA = 1 THEN 1  
                WHEN attr.Is_Entity_DBA = 1 THEN 1  
                ELSE 0  
                END,  
        DBA_MemberType_ID =  
            CASE   
                WHEN refEntity.Is_Entity_DBA = 1 THEN refEntity.DBA_MemberType_ID  
                WHEN attr.Is_Entity_DBA = 1 THEN attr.DBA_MemberType_ID  
                ELSE NULL  
                END,    
        Privilege_ID =     
            CASE     
                WHEN tModSec.Privilege_ID = 1     
                     OR (tExp.Entity_PrivilegeID IS NULL AND tModSec.Privilege_ID <> 99)     
                     OR (tExp.Entity_PrivilegeID = 99 AND tModSec.Privilege_ID <> 99)     
                     THEN tModSec.Privilege_ID     
                WHEN tExp.Entity_PrivilegeID IS NULL AND attr.Entity_PrivilegeID = 99     
                     THEN attr.Entity_PrivilegeID    
                WHEN tExp.Entity_PrivilegeID IS NULL AND refEntity.EntityPrivilege_ID = 99  
                    THEN refEntity.EntityPrivilege_ID  
                ELSE tExp.Entity_PrivilegeID    
            END     
    FROM       
        mdm.tblEntity tEnt      
        -- Check Model security      
        JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL tModSec       
        ON tModSec.ID = tEnt.Model_ID      
  
        LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER tExp       
        ON tEnt.ID = tExp.Entity_ID AND tModSec.User_ID = tExp.User_ID      
   
        -- Check attribute level security    
        LEFT  JOIN     
            (SELECT vAttr.Entity_ID,   
                    vAttr.Model_ID,  
                    vUsr.User_ID,  
                    Attribute_DBAEntity_ID,   
                    vAttr.Attribute_ID,   
                    vUsr.Entity_PrivilegeID,  
                    1 Is_Entity_DBA,  
                    vAttr.Attribute_MemberType_ID DBA_MemberType_ID  
             FROM     
                (SELECT Entity_ID,   
                        Model_ID,  
                        Attribute_DBAEntity_ID,   
                        Attribute_ID,  
                        Attribute_MemberType_ID   
                 FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC    
                 WHERE Attribute_DBAEntity_ID IS NOT NULL) vAttr   
             INNER JOIN mdm.viw_SYSTEM_SECURITY_USER vUsr   
                ON vUsr.Attribute_ID = vAttr.Attribute_ID ) attr      
             ON attr.Attribute_DBAEntity_ID = tEnt.ID AND attr.Model_ID = tEnt.Model_ID    
             AND attr.User_ID = tModSec.User_ID  
               
        -- Check for implied read-access due to referring entity access   
        -- (referring entity is host of DBA whose members are in the current entity).  
        -- Added a check on the MemberType because model privileges at the MemberType level can also impact   
        -- Dba entity access.  
        LEFT JOIN   
            (SELECT ssu.User_ID,     
                    ssab.Attribute_DBAEntity_ID Entity_ID,     
                    99 EntityPrivilege_ID,    
                    1 Is_Entity_DBA,    
                    ssab.Attribute_MemberType_ID DBA_MemberType_ID     
                FROM     
                    mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC ssab     
                    INNER JOIN mdm.viw_SYSTEM_SECURITY_USER ssu     
                        ON ssu.Entity_ID = ssab.Entity_ID    
                    WHERE ssu.Entity_IsExplicit = 1  OR ssu.MemberType_IsExplicit =1  
                    AND ssu.Entity_PrivilegeID IN (2,3)  OR ssu.MemberType_PrivilegeID IN (2,3)  
                    AND ssab.Attribute_DBAEntity_ID IS NOT NULL ) refEntity  
        ON refEntity.Entity_ID = tEnt.ID and refEntity.User_ID = tModSec.User_ID  
    
    ) tSec    
  
WHERE   
    tSec.Privilege_ID IS NOT NULL   
GROUP BY   
    tSec.User_ID,  
    tSec.Model_ID,  
    tSec.ID,  
    tSec.Is_Entity_DBA,  
    tSec.DBA_MemberType_ID
GO
