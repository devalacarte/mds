SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SUBSCRIPTION_CTG_BUSINESS_RULES]    
AS    
--This view displays all business rules that relate to a change tracking group  
SELECT mdl.Name AS Model_Name,   
	ent.Name AS Entity_Name,   
	CASE br.ForeignType_ID  
		WHEN 1 THEN N'Leaf'  
		WHEN 2 THEN N'Consolidated'  
	END AS MemberType,   
	br.Name AS BusinessRule_Name,   
	RIGHT(bri.[ItemText],2) AS ChangeTrackingGroup   
FROM mdm.tblBRItem bri  
    INNER JOIN mdm.tblBRLogicalOperatorGroup brl ON brl.ID = bri.BRLogicalOperatorGroup_ID  
    INNER JOIN mdm.tblBRBusinessRule br ON br.ID = brl.BusinessRule_ID  
    INNER JOIN mdm.tblEntity ent ON ent.ID = br.Foreign_ID  
    INNER JOIN mdm.tblModel mdl ON mdl.ID = ent.Model_ID  
    WHERE bri.BRItemAppliesTo_ID = 238 -- Business rules that are applied to a tracking group.
GO
