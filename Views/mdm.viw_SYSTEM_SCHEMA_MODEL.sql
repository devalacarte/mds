SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_MODEL  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_MODEL]  
/*WITH SCHEMABINDING*/  
AS  
SELECT	  
	mod.ID,  
	mod.MUID,  
	mod.Name,  
	mod.IsSystem,  
	usrE.ID EnteredUser_ID,  
	usrE.MUID EnteredUser_MUID,  
	usrE.UserName EnteredUser_UserName,  
	mod.EnterDTM EnteredUser_DTM,  
	usrL.ID LastChgUser_ID,  
	usrL.MUID LastChgUser_MUID,  
	usrL.UserName LastChgUser_UserName,  
	mod.LastChgDTM LastChgUser_DTM  
  
FROM  
	mdm.tblModel [mod]   
	INNER JOIN mdm.tblUser usrE  
		ON mod.EnterUserID = usrE.ID  
	INNER JOIN mdm.tblUser usrL  
		ON mod.LastChgUserID = usrL.ID
GO
