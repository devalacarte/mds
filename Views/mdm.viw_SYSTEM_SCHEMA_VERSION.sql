SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT * FROM mdm.viw_SYSTEM_SCHEMA_VERSION  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_VERSION]  
/*WITH SCHEMABINDING*/  
AS  
SELECT   
   V.ID,  
   V.MUID,  
   V.Model_ID,  
   M.MUID Model_MUID,  
   M.Name Model_Name,  
   M.IsSystem Model_IsSystem,  
   V.Status_ID,  
   L.ListOption as Status,  
   V.Display_ID as VersionNbr,  
   V.Name,  
   V.Description,  
   ISNULL(V.VersionFlag_ID, 0) as VersionFlag_ID,  
   ISNULL(F.MUID, CONVERT(UNIQUEIDENTIFIER, 0x0)) as Flag_MUID,  
   F.Name as Flag,  
   ISNULL(V2.ID,0) AS CopiedFrom_ID,  
   ISNULL(V2.MUID, CONVERT(UNIQUEIDENTIFIER, 0x0)) AS CopiedFrom_MUID,  
   V2.Name + N'(#' + CONVERT(NVARCHAR(100),V2.Display_ID) + N')' as CopiedFrom,  
   usrE.ID EnteredUser_ID,  
   usrE.MUID EnteredUser_MUID,  
   usrE.UserName EnteredUser_UserName,  
   V.EnterDTM EnteredUser_DTM,  
   usrL.ID LastChgUser_ID,  
   usrL.MUID LastChgUser_MUID,  
   usrL.UserName LastChgUser_UserName,  
   V.LastChgDTM LastChgUser_DTM  
FROM   
	mdm.tblModelVersion V  
	INNER JOIN mdm.tblModel M ON V.Model_ID = M.ID  
	INNER JOIN mdm.tblList L ON L.ListCode = N'lstVersionStatus' AND L.OptionID = V.Status_ID  
	INNER JOIN mdm.tblUser usrE ON V.EnterUserID = usrE.ID  
	INNER JOIN mdm.tblUser usrL ON V.LastChgUserID = usrL.ID  
	LEFT JOIN mdm.tblModelVersionFlag F ON F.ID = V.VersionFlag_ID  
	LEFT JOIN mdm.tblModelVersion AS V2 ON V.AsOfVersion_ID = V2.ID
GO
