SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_CHANGEVALUE_INHERITANCE  
	SELECT * FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_CHANGEVALUE_INHERITANCE WHERE Model_ID = 9 AND EntityID = 80 AND AttributeName = '2 Digit Code'  
  
	select * from mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC  
	select * from mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_CHANGEVALUE_INHERITANCE]  
/*WITH SCHEMABINDING*/  
AS  
--Get the Code attributes where inheritance rules exists  
SELECT	  
		ap.Model_ID,   
		ap.Entity_ID AS EntityID,  
		ap.Entity_Name AS EntityName,   
		ap.Attribute_ID AS AttributeID,  
		ap.Attribute_Name AS AttributeName,  
		ap.Attribute_DBAEntity_ID,  
		ap.Attribute_DBAEntity_Name  
from	mdm.tblBRItemProperties p inner join  
		mdm.tblBRItem bi   
			on	p.BRItem_ID = bi.ID   
			and bi.BRItemAppliesTo_ID in (SELECT AppliesTo_ID FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES WHERE BRSubType = N'Change value'   
			AND (BRItemType_ID = 14 OR BRItemType_ID = 16)) -- Equals, Equals concatenated  
			and p.PropertyType_ID = 2 -- Attribute  
			and p.IsLeftHandSide = 0  
		inner join mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC ac  
			on ac.Attribute_ID = cast(p.Value as int)  
			and ac.Attribute_DBAEntity_ID > 0  
		inner join mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC ap  
			on ap.Entity_ID = ac.Attribute_DBAEntity_ID  
			and ap.Attribute_Name = N'Code'  
union  
-- and any other attribute that concatenates into other attributes  
select	  
		ap.Model_ID,  
		ap.Attribute_Entity_ID,  
		ap.Attribute_Entity_Name,  
		ap.Attribute_ID,  
		ap.Attribute_Name,  
		ap.Attribute_DBAEntity_ID,  
		ap.Attribute_DBAEntity_Name  
FROM	mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES ap  
WHERE	ap.Item_AppliesTo_ID = (SELECT AppliesTo_ID FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES WHERE BRSubType = N'Change value' AND BRItemType_ID = 16) -- Equals concatenated  
AND		ap.Property_IsLeftHandSide = 0  
AND		ap.PropertyType_ID = 2 -- Attribute  
AND		EXISTS (  
			SELECT	a.Attribute_DBAEntity_ID  
			FROM	mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES  a  
			WHERE	EXISTS (SELECT   
				AppliesTo_ID   
				FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES   
				WHERE   
				AppliesTo_ID=a.Item_AppliesTo_ID   
				AND BRSubType = N'Change value'   
				AND (BRItemType_ID = 14 OR BRItemType_ID = 16)) -- Equals, Equals concatenated  
			AND		a.PropertyType_ID = 2  
			and		a.Property_IsLeftHandSide = 0  
			and		a.Attribute_DBAEntity_ID > 0  
			AND		a.Attribute_DBAEntity_ID=ap.Attribute_Entity_ID  
			)  
union  
-- Get any associated DBA inheritance attributes (PropertyType_ID = 4)  
select	  
		ap.Model_ID,  
		ap.Attribute_Entity_ID,  
		ap.Attribute_Entity_Name,  
		ap.Attribute_ID,  
		ap.Attribute_Name,  
		dba_e.ID,  
		dba_e.Name  
FROM	mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES ap  
		inner join mdm.tblBRItemProperties dba_p   
			on	ap.Property_Parent_ID = dba_p.ID  
			AND	ap.Property_IsLeftHandSide = 0  
			AND	ap.PropertyType_ID = 2 -- Attribute  
		inner join mdm.tblAttribute dba   
			on	cast(dba_p.Value AS INT) = dba.ID   
			and dba_p.PropertyType_ID = 4  -- DBA attribute  
		inner join mdm.tblEntity dba_e  
			on	dba.Entity_ID = dba_e.ID  
		WHERE EXISTS   
				(SELECT AppliesTo_ID   
				FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES   
				WHERE BRSubType = N'Change value'   
				AND (BRItemType_ID = 14 OR BRItemType_ID = 16)  
				AND AppliesTo_ID = ap.Item_AppliesTo_ID  
				) -- Equals, Equals concatenated
GO
