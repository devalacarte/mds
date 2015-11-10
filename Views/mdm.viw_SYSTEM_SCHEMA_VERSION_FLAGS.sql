SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT * FROM mdm.viw_SYSTEM_SCHEMA_VERSION_FLAGS  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_VERSION_FLAGS]  
/*WITH SCHEMABINDING*/  
AS  
SELECT   
	F.ID,  
	F.MUID,  
	F.Model_ID,  
	M.MUID Model_MUID,  
	M.Name Model_Name,  
	M.IsSystem Model_IsSystem,  
	F.Status_ID,  
	CAST(F.CommittedOnly_ID AS BIT) AS IsCommittedOnly,  
	F.Name,  
	F.Description,  
    ISNULL(V.ID, 0) as AssignedVersion_ID,  
    ISNULL(V.MUID,0x0) as AssignedVersion_MUID,  
    ISNULL(V.Name,N'') as AssignedVersion_Name,  
	usrE.ID EnteredUser_ID,  
	usrE.MUID EnteredUser_MUID,  
	usrE.UserName EnteredUser_UserName,  
	F.EnterDTM EnteredUser_DTM,  
	usrL.ID LastChgUser_ID,  
	usrL.MUID LastChgUser_MUID,  
	usrL.UserName LastChgUser_UserName,  
	F.LastChgDTM LastChgUser_DTM  
FROM   
	mdm.tblModelVersionFlag F  
	INNER JOIN mdm.tblModel M ON F.Model_ID = M.ID  
	INNER JOIN mdm.tblUser usrE ON F.EnterUserID = usrE.ID  
	INNER JOIN mdm.tblUser usrL ON F.LastChgUserID = usrL.ID  
	LEFT JOIN mdm.tblModelVersion V ON F.ID = V.VersionFlag_ID
GO
