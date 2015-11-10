SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    SELECT * FROM mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY_DERIVED ORDER BY User_ID  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_HIERARCHY_DERIVED]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
    tModSec.User_ID,  
    tHir.Model_ID,  
    tHir.ID,  
    MIN(tModSec.Privilege_ID) Privilege_ID  
FROM   
    mdm.tblDerivedHierarchy tHir  
    INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL tModSec  
        ON tModSec.ID = tHir.Model_ID AND  
           NULLIF(tModSec.Privilege_ID, 99) IS NOT NULL -- Do not inherit empty or inferred permission  
GROUP BY  
    tModSec.User_ID,  
    tHir.Model_ID,  
    tHir.ID
GO
