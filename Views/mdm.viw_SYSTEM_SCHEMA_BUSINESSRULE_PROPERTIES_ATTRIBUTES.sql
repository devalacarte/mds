SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES WHERE BusinessRule_ID = 130  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES ORDER BY BusinessRule_ID  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES]  
/*WITH SCHEMABINDING*/  
AS  
SELECT	  
		tProp.ID					Property_ID,  
		tBr.ID						BusinessRule_ID,  
		tBr.MUID					BusinessRule_MUID,  
		tBr.Name					BusinessRule_Name,  
		tBr.Status_ID               BusinessRule_Status,  
		tItem.ID					Item_ID,  
		tItem.MUID					Item_MUID,  
		tItem.BRItemAppliesTo_ID	Item_AppliesTo_ID,  
		tProp.PropertyType_ID		,  
		tProp.Value					Property_Value,  
		tProp.Sequence				Property_Sequence,  
		tProp.IsLeftHandSide		Property_IsLeftHandSide,  
		tProp.Parent_ID				Property_Parent_ID,  
		tPropParent.PropertyType_ID	Property_Parent_PropertyType_ID,  
		tPropParent.PropertyName_ID	Property_Parent_PropertyName_ID,  
		tAtt.Model_ID				,  
		tAtt.Model_MUID				,  
		tAtt.Entity_ID				Attribute_Entity_ID,  
		tAtt.Entity_MUID			Attribute_Entity_MUID,  
		tAtt.Entity_Name			Attribute_Entity_Name,  
		tAtt.Attribute_ID,  
		tAtt.Attribute_MUID,  
		tAtt.Attribute_Name,  
		tAtt.Attribute_Column,  
		tAtt.Attribute_MemberType_ID,  
		tAtt.Attribute_DBAEntity_ID,  
		tAtt.Attribute_DBAEntity_MUID,  
		tAtt.Attribute_DBAEntity_Name,  
		tAtt.Attribute_ChangeTrackingGroup  
  
FROM	  
		mdm.tblBRItemProperties tProp   
		inner join mdm.tblBRItem tItem   
			ON tProp.BRItem_ID = tItem.ID  
		inner join mdm.tblBRLogicalOperatorGroup tOpr   
			on tItem.BRLogicalOperatorGroup_ID = tOpr.ID   
		inner join mdm.tblBRBusinessRule tBr   
			on tOpr.BusinessRule_ID = tBr.ID   
		inner join (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = CAST(N'lstBRItemPropertyType' AS NVARCHAR(50))) tPropertyType  
			ON tProp.PropertyType_ID = tPropertyType.ID  
		inner join (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = CAST(N'lstBRItemPropertyName' AS NVARCHAR(50))) tPropertyName  
			ON tProp.PropertyName_ID = tPropertyName.ID  
		INNER JOIN mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES tAtt  
			ON (tProp.PropertyType_ID = 2 /*Attribute property */ OR tProp.PropertyType_ID = 4) /*DBA property */  
            AND CAST(tAtt.Attribute_ID AS NVARCHAR(MAX)) = tProp.Value  
        LEFT JOIN mdm.tblBRItemProperties tPropParent  
            ON tProp.Parent_ID = tPropParent.ID
GO
