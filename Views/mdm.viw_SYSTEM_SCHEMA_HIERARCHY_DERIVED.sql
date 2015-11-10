SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED]  
/*WITH SCHEMABINDING*/  
AS  
  
SELECT  
    tMod.ID                     Model_ID,   
    tMod.MUID                   Model_MUID,   
    tMod.Name                   Model_Name,    
    tMod.IsSystem               Model_IsSystem,    
    tHir.ID                     Hierarchy_ID,   
    tHir.MUID                   Hierarchy_MUID,   
    tHir.Name                   Hierarchy_Name,  
    tHir.AnchorNullRecursions   Hierarchy_AnchorNullRecursions,         
    Hierarchy_Label  = N'Derived: ' + tMod.Name + ': ' + tHir.Name,   
    --  
    CASE tLevels.Levels WHEN NULL THEN 0 ELSE tLevels.Levels END Levels  ,  
    --  
    usrE.ID EnteredUser_ID,  
    usrE.MUID EnteredUser_MUID,  
    usrE.UserName EnteredUser_UserName,  
    tHir.EnterDTM EnteredUser_DTM,  
    usrL.ID LastChgUser_ID,  
    usrL.MUID LastChgUser_MUID,  
    usrL.UserName LastChgUser_UserName,  
    tHir.LastChgDTM LastChgUser_DTM  
FROM  
    mdm.tblModel tMod   
    JOIN mdm.tblDerivedHierarchy tHir ON tMod.ID = tHir.Model_ID   
    JOIN mdm.tblUser usrE ON tHir.EnterUserID = usrE.ID  
    JOIN mdm.tblUser usrL ON tHir.LastChgUserID = usrL.ID  
    LEFT JOIN (SELECT DerivedHierarchy_ID, MAX(Level_ID) Levels FROM mdm.tblDerivedHierarchyDetail GROUP BY DerivedHierarchy_ID) tLevels ON tHir.ID = tLevels.DerivedHierarchy_ID
GO
