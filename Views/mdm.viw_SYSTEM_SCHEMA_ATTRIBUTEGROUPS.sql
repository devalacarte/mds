SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTEGROUPS  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_ATTRIBUTEGROUPS]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
	tGrp.ID,  
	tGrp.Name,  
	tGrp.MUID,			  
	tMod.ID           Model_ID,  
	tMod.Name         Model_Name,  
	tMod.MUID			Model_MUID,  
	tEnt.ID           Entity_ID,   
	tEnt.Name         Entity_Name,   
	tEnt.MUID			Entity_MUID,  
	FullName = tMod.Name + N':' + tEnt.Name + N':' + tMemberType.Name + N':' + tGrp.Name,  
	tGrp.MemberType_ID,  
  	MemberType_Name = tMemberType.Name,  
	tGrp.SortOrder,  
	IsNameCodeFrozen = tGrp.FreezeNameCode,   
	tGrp.IsSystem,  
	usrE.ID EnteredUser_ID,  
	usrE.MUID EnteredUser_MUID,  
	usrE.UserName EnteredUser_UserName,  
	tGrp.EnterDTM EnteredUser_DTM,  
	usrL.ID LastChgUser_ID,  
	usrL.MUID LastChgUser_MUID,  
	usrL.UserName LastChgUser_UserName,  
	tGrp.LastChgDTM LastChgUser_DTM  
FROM  
	mdm.tblEntity tEnt  
	JOIN mdm.tblAttributeGroup tGrp ON tEnt.ID = tGrp.Entity_ID  
	JOIN mdm.tblEntityMemberType tMemberType ON tGrp.MemberType_ID = tMemberType.ID  
	JOIN mdm.tblModel tMod ON tEnt.Model_ID = tMod.ID  
	JOIN mdm.tblUser usrE ON tGrp.EnterUserID = usrE.ID  
	JOIN mdm.tblUser usrL ON tGrp.LastChgUserID = usrL.ID
GO
