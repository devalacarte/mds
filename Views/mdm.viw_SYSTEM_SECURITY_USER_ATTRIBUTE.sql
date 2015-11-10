SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
NOTE: This view can return multiple rows per user, entity, member type, and ID.  Each row represents   
the permission for each attribute permission ranking.  Deny permissions are ranked higher  
  
Rank    Permission  
----    ---------------------  
1       Member Type - Deny  
3       Domain Entity - Deny  
3       Attribute - Deny  
4       Attribute - Update/Read  
7       Referred Entity Access for Name/Code (Read)  
8       Member Type - Update/Read  
  
SELECT * FROM mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTE WHERE User_ID = 118  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_ATTRIBUTE]  
/*WITH SCHEMABINDING*/  
AS  
SELECT   
    User_ID,  
    Entity_ID,  
    MemberType_ID,  
    ID,  
    Rank,  
    MIN(Privilege_ID) Privilege_ID  
FROM   
    (  
    -- Select and rank any attributes affected by a Member Type permission.  
    SELECT  
        vTypSec.User_ID,  
        vTypSec.Entity_ID,   
        vTypSec.ID MemberType_ID,   
        tAtt.ID,   
        vTypSec.Privilege_ID Privilege_ID,  
        Rank = CASE WHEN vTypSec.Privilege_ID = 1 THEN 1 ELSE 8 END,  
        tAtt.IsSystem  
    FROM   
        mdm.tblAttribute tAtt  
        JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE vTypSec   
            ON  vTypSec.Entity_ID = tAtt.Entity_ID   
            AND vTypSec.ID = tAtt.MemberType_ID  
  
    UNION    
  
    -- Disallow access to any domain-based attribute who's domain entity has Deny permission.  
    SELECT    
        ent.User_ID,  
        tAtt.Entity_ID,  
        tAtt.MemberType_ID Attribute_MemberType_ID,  
        tAtt.ID,  
        1 Privilege_ID, -- Deny  
        2 Rank,  
        tAtt.IsSystem  
    FROM  
        mdm.tblAttribute tAtt  
        INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_ENTITY ent  
            ON  
                    tAtt.DomainEntity_ID = ent.ID  
                AND ent.Privilege_ID = 1 -- Deny  
  
    UNION  
  
    -- Select and rank any attributes affected by an Attribute permission.  
    SELECT  
        vUsrSec.User_ID,  
        vUsrSec.Entity_ID,   
        vUsrSec.MemberType_ID,   
        vUsrSec.Attribute_ID ID,   
        vUsrSec.Attribute_PrivilegeID Privilege_ID,  
        Rank = CASE WHEN vUsrSec.Attribute_PrivilegeID = 1 THEN 3 ELSE 4 END,  
        0  
    FROM  
        mdm.viw_SYSTEM_SECURITY_USER vUsrSec  
    WHERE  
        vUsrSec.Attribute_ID > 0   
              
    UNION  
    --select and rank any name/code attributes affected by an implicit referring entity privilege  
    SELECT  
        ssue.User_ID,  
        ssa.Entity_ID,   
        ssa.Attribute_MemberType_ID,   
        ssa.Attribute_ID ID,   
        3 Privilege_ID,  
        7 Rank,  
        ssa.Attribute_IsSystem  
    FROM  
        mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES ssa    
        INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_ENTITY ssue    
            ON ssue.ID = ssa.Entity_ID    
        WHERE (ssa.Attribute_IsCode = 1 OR ssa.Attribute_IsName = 1)   
            AND ssue.Privilege_ID = 99   
            AND ssue.Is_Entity_DBA = 1  
            AND ssue.DBA_MemberType_ID = ssa.Attribute_MemberType_ID	  
) a  
WHERE  
    Privilege_ID < 99 OR (Privilege_ID=99 AND IsSystem=1)  
    --Privilege_ID IS NOT NULL   
GROUP BY   
    User_ID,  
    Entity_ID,  
    MemberType_ID,  
    ID,  
    Rank
GO
