SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Attribute_DBAEntity_ID > 0  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Entity_ID = 23  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Entity_ID = 31 AND Attribute_MemberType_ID = 1  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Entity_ID = 23 AND Attribute_Name = 'Weight'  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Attribute_ID = 1067  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_ATTRIBUTES]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
	tMod.ID						Model_ID,   
	tMod.MUID					Model_MUID,      
	tMod.Name					Model_Name,  
	tEnt.ID						Entity_ID,   
	tEnt.MUID					Entity_MUID,  
	tEnt.Name					Entity_Name,   
	tAtt.ID						Attribute_ID,  
	tAtt.MUID					Attribute_MUID,  
	tAtt.Name					Attribute_Name,  
	Attribute_FullyQualifiedName = tMod.Name + N':' + tEnt.Name + N':' + tMemberType.Name + N':' + tAtt.Name,  
	tAtt.DisplayName			Attribute_DisplayName,  
	tAtt.DisplayWidth			Attribute_DisplayWidth,  
	tAtt.ChangeTrackingGroup	Attribute_ChangeTrackingGroup,  
	tAtt.TableColumn			Attribute_Column,  
	tAtt.IsSystem				Attribute_IsSystem,  
	tAtt.IsReadOnly				Attribute_IsReadOnly,  
	tAtt.IsCode					Attribute_IsCode,  
	tAtt.IsName					Attribute_IsName,  
	tMemberType.ID				Attribute_MemberType_ID,  
	CONVERT(INT, + CONVERT(NVARCHAR,tEnt.ID) + convert(NVARCHAR, tAtt.MemberType_ID) )  AS Attribute_MemberType_FullyQualifiedID,  
	tMemberType.Name			Attribute_MemberType_Name,  
	tAttributeType.OptionID		Attribute_Type_ID,  
	tAttributeType.ListOption	Attribute_Type_Name,  
	CASE WHEN tDBAEnt.ID IS NULL THEN 0 ELSE tDBAEnt.ID END Attribute_DBAEntity_ID,     
	CASE WHEN tDBAEnt.MUID IS NULL  THEN 0x0 ELSE tDBAEnt.MUID END Attribute_DBAEntity_MUID,  
	CASE WHEN tDBAEnt.Name IS NULL THEN N'' ELSE tDBAEnt.Name END Attribute_DBAEntity_Name,   
	CASE WHEN tDBAEnt.IsFlat IS NULL THEN 1 ELSE tDBAEnt.IsFlat END Attribute_DBAEntity_IsFlat,   
	CASE WHEN tDBAEnt.EntityTable IS NULL THEN N'' ELSE tDBAEnt.EntityTable END Attribute_DBAEntity_EntityTable,   
	tDataType.OptionID			Attribute_DataType_ID,  
	tDataType.ListOption		Attribute_DataType_Name,  
	tAtt.DataTypeInformation	Attribute_DataType_Information,   
	tAtt.InputMask_ID			Attribute_DataMask_ID,  
	tDataMask.ListOption		Attribute_DataMask_Name,  
	(SELECT ViewName FROM mdm.viw_SYSTEM_SCHEMA_VIEWS   
		WHERE Entity_ID = tAtt.Entity_ID   
		AND MemberType_ID=tAtt.MemberType_ID   
		AND DisplayType_ID =0) Entity_TableName,  
	CASE tAtt.MemberType_ID  
		WHEN 1 THEN tEnt.EntityTable   
		WHEN 2 THEN tEnt.HierarchyParentTable   
		WHEN 3 THEN tEnt.CollectionTable   
		WHEN 4 THEN tEnt.HierarchyTable   
		WHEN 5 THEN tEnt.CollectionMemberTable   
		WHEN 6 THEN tEnt.SecurityTable  
		ELSE N'' END  Entity_PhysicalTableName ,  
	CASE tAtt.MemberType_ID  
		WHEN 1 THEN tEnt.StagingBase + N'_Leaf'  
		WHEN 2 THEN tEnt.StagingBase + N'_Consolidated'  
	END Entity_StagingTableName,  
	tEnt.StagingBase			Entity_StagingBase,  
	tAtt.SortOrder				Attribute_SortOrder,  
	usrE.ID						EnteredUser_ID,  
	usrE.MUID					EnteredUser_MUID,  
	usrE.UserName				EnteredUser_UserName,  
	tAtt.EnterDTM				EnteredUser_DTM,  
	usrL.ID						LastChgUser_ID,  
	usrL.MUID					LastChgUser_MUID,  
	usrL.UserName				LastChgUser_UserName,  
	tAtt.LastChgDTM				LastChgUser_DTM  
FROM  
	mdm.tblModel tMod   
	JOIN mdm.tblEntity tEnt ON tMod.ID = tEnt.Model_ID   
	JOIN mdm.tblAttribute tAtt ON tEnt.ID = tAtt.Entity_ID   
	JOIN  mdm.tblEntityMemberType tMemberType ON tAtt.MemberType_ID = tMemberType.ID  
	JOIN mdm.tblList tAttributeType ON tAttributeType.ListCode = N'lstAttributeType' AND tAtt.AttributeType_ID = tAttributeType.OptionID  
	JOIN mdm.tblList tDataType ON tDataType.ListCode = N'lstDataType' AND tAtt.DataType_ID = tDataType.OptionID  
	JOIN mdm.tblUser usrE ON tAtt.EnterUserID = usrE.ID  
	JOIN mdm.tblUser usrL ON tAtt.LastChgUserID = usrL.ID  
	LEFT OUTER JOIN mdm.tblList tDataMask ON tDataMask.ListCode = N'lstInputMask' AND tAtt.InputMask_ID = tDataMask.OptionID AND tAtt.DataType_ID = tDataMask.Group_ID  
	LEFT OUTER JOIN mdm.tblEntity tDBAEnt ON tAtt.DomainEntity_ID = tDBAEnt.ID
GO
