SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
SELECT * FROM  mdm.viw_SYSTEM_SCHEMA_HIERARCHY_EXPLICIT  
  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_HIERARCHY_EXPLICIT]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
	tMod.ID           Model_ID,   
	tMod.MUID         Model_MUID,   
	tMod.Name         Model_Name,    
	tMod.IsSystem	  Model_IsSystem,    
	tEnt.ID           Entity_ID,  
	tEnt.MUID         Entity_MUID,  
	tEnt.Name         Entity_Name,  
	tEnt.IsSystem     Entity_IsSystem,  
	tHir.ID           Hierarchy_ID,   
	tHir.MUID         Hierarchy_MUID,   
	tHir.Name         Hierarchy_Name,  
	tHir.IsMandatory  Hierarchy_IsMandatory,   
	Hierarchy_Label  = N'Explicit: ' + tMod.Name + N': ' + tHir.Name,   
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
	mdm.tblHierarchy tHir  
	INNER JOIN mdm.tblEntity tEnt ON tEnt.ID = tHir.Entity_ID  
	INNER JOIN mdm.tblModel tMod ON tMod.ID = tEnt.Model_ID  
	INNER JOIN mdm.tblUser usrE ON tHir.EnterUserID = usrE.ID  
	INNER JOIN mdm.tblUser usrL ON tHir.LastChgUserID = usrL.ID
GO
