SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES WHERE BusinessRule_ID = 130  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES]  
/*WITH SCHEMABINDING*/  
AS  
SELECT	  
		tProp.ID					Property_ID,  
		tBr.ID						BusinessRule_ID,  
		tBr.MUID					BusinessRule_MUID,  
		tBr.Name					BusinessRule_Name,  
		tBr.Status_ID               BusinessRule_Status,  
		tLogicalOperator.ID			LogicalOperator_ID,  
		tOpr.MUID					LogicalOperator_MUID,  
		tLogicalOperator.Name		LogicalOperator_Name,  
		tItem.ID					Item_ID,  
		tItem.MUID					Item_MUID,  
		tItem.ItemText				Item_Text,  
		tItem.Sequence				Item_Sequence,  
		tItem.BRItemAppliesTo_ID	Item_AppliesTo_ID,  
		tPropertyType.ID			PropertyType_ID,  
		tPropertyType.Name			PropertyType_Name,  
		tPropertyName.ID			PropertyName_ID,  
		tPropertyName.Name			PropertyName_Name,  
		tProp.Value					Property_Value,  
		tProp.Sequence				Property_Sequence,  
		tProp.IsLeftHandSide		Property_IsLeftHandSide,  
		tProp.Parent_ID				Property_Parent_ID,  
		tProp.SuppressText			Property_SuppressText  
  
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
		inner join (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = CAST(N'lstBRLogicalOperator' AS NVARCHAR(50))) tLogicalOperator  
			ON tOpr.LogicalOperator_ID = tLogicalOperator.ID
GO
