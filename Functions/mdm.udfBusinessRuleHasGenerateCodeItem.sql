SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT mdm.udfBusinessRuleHasGenerateCodeItem(1,1,12)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfBusinessRuleHasGenerateCodeItem]  
(  
    @BRType_ID     			INT,  
	@BRSubType_ID			INT,  
	@Foreign_ID				INT  
)   
RETURNS BIT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
DECLARE	@HasGenerateValueItems	BIT  
  
SELECT @HasGenerateValueItems = CASE WHEN EXISTS (  
		SELECT 1  
		FROM	  
			mdm.tblBRBusinessRule br   
				INNER JOIN mdm.tblListRelationship lr ON br.Status_ID = 1   
					AND br.ForeignType_ID = lr.ID   
					AND br.Foreign_ID = @Foreign_ID   
					AND lr.Parent_ID = @BRType_ID   
					AND lr.Child_ID = @BRSubType_ID   
				INNER JOIN mdm.tblBRLogicalOperatorGroup grp ON br.ID = grp.BusinessRule_ID   
				INNER JOIN mdm.tblBRItem bri ON grp.ID = bri.BRLogicalOperatorGroup_ID   
				INNER JOIN mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES typ   
					ON bri.BRItemAppliesTo_ID = typ.AppliesTo_ID   
					AND (LOWER(typ.BRItemTypeName) = 'generate value' OR LOWER(typ.BRItemTypeName) = 'concatenated value')  
				INNER JOIN mdm.tblBRItemProperties prop ON prop.BRItem_ID = bri.ID   
					AND prop.IsLeftHandSide = 1   
				INNER JOIN mdm.tblAttribute a ON CAST(prop.Value AS INTEGER) = a.ID   
					AND a.Name = N'Code'   
		)   
	THEN 1 ELSE 0 END  
  
Return @HasGenerateValueItems  
  
END --fn
GO
