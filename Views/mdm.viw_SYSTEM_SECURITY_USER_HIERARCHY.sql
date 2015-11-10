SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_HIERARCHY]  
/*WITH SCHEMABINDING*/  
AS  
SELECT   
    tEntSec.User_ID,  
    tHir.Entity_ID,  
    tHir.ID,  
    MIN(tEntSec.Privilege_ID) Privilege_ID  
FROM   
    mdm.tblHierarchy tHir  
    INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_ENTITY tEntSec   
        ON tEntSec.ID = tHir.Entity_ID AND  
           NULLIF(tEntSec.Privilege_ID, 99) IS NOT NULL -- Do not inherit empty or inferred permission  
GROUP BY   
    tEntSec.User_ID,  
    tHir.Entity_ID,  
    tHir.ID
GO
