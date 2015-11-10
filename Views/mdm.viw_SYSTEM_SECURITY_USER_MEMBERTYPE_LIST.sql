SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
    SELECT * FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE_LIST ORDER BY User_ID, Entity_ID, ID  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_MEMBERTYPE_LIST]  
/*WITH SCHEMABINDING*/  
AS  
SELECT   
    tEntSec.User_ID         User_ID,  
    tEntSec.ID              Entity_ID,  
    tMbrTyp.MemberType_ID   ID,  
    tEntSec.Privilege_ID    Privilege_ID  
FROM   
    mdm.viw_SYSTEM_SECURITY_USER_ENTITY tEntSec  
    INNER JOIN   
    (  
        SELECT  
            ID  Entity_ID,  
            1   MemberType_ID -- Leaf  
        FROM mdm.tblEntity  
        UNION  
        SELECT  
            ID,  
            2 -- Consolidated  
        FROM mdm.tblEntity  
        WHERE HierarchyTable <> N''  
        UNION  
        SELECT  
            ID,  
            3 -- Collection  
        FROM mdm.tblEntity  
        WHERE HierarchyTable <> N''  
    ) tMbrTyp   
    ON tMbrTyp.Entity_ID = tEntSec.ID
GO
