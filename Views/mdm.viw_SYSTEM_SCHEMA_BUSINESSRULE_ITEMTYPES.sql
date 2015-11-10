SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES WHERE ApplyToCategoryID = 2 AND BRSubTypeIsVisible = 1 order by DisplaySequence, DisplaySubSequence  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES WHERE BRSubType = 'Validation' order by brtype, brsubtype, priority  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES WHERE BRSubType = 'Validation'  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES WHERE BRItemType_ID = 28  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES]  
/*WITH SCHEMABINDING*/  
AS  
SELECT	  
		apl.ID AS AppliesTo_ID,  
		apl.ApplyTo_ID,  
		lrt.ID AS ApplyToCategoryID,  
		lrt.Name AS ApplyToCategory,  
		p.OptionID AS BRTypeID,  
		p.ListOption AS BRType,  
		c.ID AS BRSubTypeID,  
		c.Name AS BRSubType,  
		1 AS BRSubTypeIsVisible,  
		apl.BRItemType_ID,  
		t.Name AS BRItemTypeName,  
		t.Description BRItemTypeDesc,  
		c.ID AS DisplaySequence,  
		isnull(apl.Sequence,-1) AS DisplaySubSequence,  
		t.PropertyDelimiter,  
		t.Priority  
FROM	mdm.tblBRItemTypeAppliesTo apl INNER JOIN  
		mdm.tblBRItemType t ON t.ID = apl.BRItemType_ID INNER JOIN  
		mdm.tblListRelationship lr ON lr.ID = apl.ApplyTo_ID INNER JOIN  
		mdm.tblListRelationshipType lrt ON lrt.ID = lr.ListRelationshipType_ID and lrt.ID = 1 INNER JOIN  
		mdm.tblList p ON p.OptionID = lr.Parent_ID AND p.ListCode = N'lstBRType' INNER JOIN  
		mdm.tblEntityMemberType c ON c.ID = lr.Child_ID   
			  
UNION   
SELECT	  
		apl.ID AS AppliesTo_ID,  
		apl.ApplyTo_ID,  
		lrt.ID AS ApplyToCategoryID,  
		lrt.Name AS ApplyToCategory,  
		p.OptionID AS BRTypeID,  
		p.ListOption AS BRType,  
		c.OptionID AS BRSubTypeID,  
		c.ListOption AS BRSubType,  
		c.IsVisible AS BRSubTypeIsVisible,  
		apl.BRItemType_ID,  
		t.Name AS BRItemTypeName,  
		t.Description BRItemTypeDesc,  
		c.Seq AS DisplaySequence,  
		isnull(apl.Sequence,-1) AS DisplaySubSequence,  
		t.PropertyDelimiter,  
		t.Priority  
FROM	mdm.tblBRItemTypeAppliesTo apl INNER JOIN  
		mdm.tblBRItemType t ON t.ID = apl.BRItemType_ID INNER JOIN  
		mdm.tblListRelationship lr ON lr.ID = apl.ApplyTo_ID INNER JOIN  
		mdm.tblListRelationshipType lrt ON lrt.ID = lr.ListRelationshipType_ID and lrt.ID = 2 INNER JOIN  
		mdm.tblList p ON p.OptionID = lr.Parent_ID AND p.ListCode = N'lstBRItemTypeCategory' INNER JOIN  
		mdm.tblList c ON c.OptionID = lr.Child_ID AND c.ListCode = N'lstBRItemTypeSubCategory'  
UNION  
SELECT	  
		apl.ID AS AppliesTo_ID,  
		apl.ApplyTo_ID,  
		lrt.ID AS ApplyToCategoryID,  
		lrt.Name AS ApplyToCategory,  
		p.OptionID AS BRTypeID,  
		p.ListOption AS BRType,  
		c.OptionID AS BRSubTypeID,  
		c.ListOption AS BRSubType,  
		c.IsVisible AS BRSubTypeIsVisible,  
		apl.BRItemType_ID,  
		t.Name AS BRItemTypeName,  
		t.Description BRItemTypeDesc,  
		c.Seq AS DisplaySequence,  
		isnull(apl.Sequence,-1) AS DisplaySubSequence,  
		t.PropertyDelimiter,  
		t.Priority  
FROM	mdm.tblBRItemTypeAppliesTo apl INNER JOIN  
		mdm.tblBRItemType t ON t.ID = apl.BRItemType_ID INNER JOIN  
		mdm.tblListRelationship lr ON lr.ID = apl.ApplyTo_ID INNER JOIN  
		mdm.tblListRelationshipType lrt ON lrt.ID = lr.ListRelationshipType_ID and lrt.ID = 3 INNER JOIN  
		mdm.tblList p ON p.OptionID = lr.Parent_ID AND p.ListCode = N'lstAttributeType' INNER JOIN  
		mdm.tblList c ON c.OptionID = lr.Child_ID AND c.ListCode = N'lstDataType'
GO
