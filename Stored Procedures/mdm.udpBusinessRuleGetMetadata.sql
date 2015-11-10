SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpBusinessRuleGetMetadata 1,1,32  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleGetMetadata]  
	(  
   	@BRType_ID     	INT,  
	@BRSubType_ID	INT,  
	@Foreign_ID		INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE	  
        @BRItemTypeCategoryActions INT = 2,  
        @PublishableStatus mdm.IdList,  
        @ParentAttributeProperty INT = 3,  
        @AttributeProperty INT = 2,  
        @ValuePropertyName_ID INT = 1;  
      
    INSERT INTO @PublishableStatus (ID)    
        SELECT OptionID FROM mdm.tblList   
        WHERE ListCode = CAST(N'lstBRStatus' AS NVARCHAR(50)) AND Group_ID = 1  -- Group_ID = 1 indicates publishable.  
  
	-- Business Rules Conditions  
	SELECT	  
		br.ID As RuleID,  
		br.RuleConditionText,  
		br.RuleConditionSQL  
	FROM	  
	    mdm.tblBRBusinessRule br INNER JOIN  
		mdm.tblListRelationship lr ON   
			br.ForeignType_ID = lr.ID AND  
			br.Foreign_ID = @Foreign_ID AND  
			lr.Parent_ID = @BRType_ID AND  
			lr.Child_ID = @BRSubType_ID INNER JOIN   
		@PublishableStatus ps ON   
		    br.Status_ID = ps.ID	  
	ORDER BY  
	    br.Priority  
  
  
	-- Business Rule Actions  
	SELECT	  
		br.ID As RuleID,  
		br.Name AS RuleName,  
		br.RuleConditionText,  
		bri.ID AS RuleItemID,  
		brit.ID AS RuleItemTypeID,  
		bri.ItemText AS RuleItemText,  
		bri.ItemSQL AS RuleItemSQL,  
		bri.AnchorName AS RuleItemAnchorName,   
		bri.AnchorDataType AS RuleItemAnchorSQLDataType,   
		bri.AnchorAttributeType AS RuleItemAnchorAttributeType,   
		a.DomainEntity_ID AS RuleItemAnchorAttributeDomainEntityID,   
		hier.Value AS RuleItemHierarchyID,  
		c.ListOption AS RuleItemSubCategory,  
		c.OptionID AS RuleItemSubCategoryID  
	FROM	  
		mdm.tblBRBusinessRule br INNER JOIN  
		mdm.tblListRelationship lr ON   
			br.ForeignType_ID = lr.ID AND  
			br.Foreign_ID = @Foreign_ID AND  
			lr.Parent_ID = @BRType_ID AND  
			lr.Child_ID = @BRSubType_ID INNER JOIN   
		@PublishableStatus ps ON br.Status_ID = ps.ID INNER JOIN    
		tblBRLogicalOperatorGroup grp ON br.ID = grp.BusinessRule_ID INNER JOIN   
		mdm.tblBRItem bri ON grp.ID = bri.BRLogicalOperatorGroup_ID INNER JOIN  
		mdm.tblBRItemTypeAppliesTo aply ON aply.ID = bri.BRItemAppliesTo_ID INNER JOIN  
		mdm.tblBRItemType brit ON aply.BRItemType_ID = brit.ID INNER JOIN  
		mdm.tblListRelationship lr2 ON lr2.ID = aply.ApplyTo_ID and lr2.ListRelationshipType_ID = @BRItemTypeCategoryActions INNER JOIN  
		mdm.tblList c on lr2.Child_ID = c.OptionID AND lr2.ChildListCode = c.ListCode AND c.IsVisible = 1 INNER JOIN  
		mdm.tblList p on lr2.Parent_ID = p.OptionID AND lr2.ParentListCode = p.ListCode AND p.OptionID = @BRItemTypeCategoryActions INNER JOIN  
		mdm.tblAttribute a ON a.Entity_ID = br.Foreign_ID AND a.Name = bri.AnchorName AND br.ForeignType_ID = a.MemberType_ID  
		LEFT OUTER JOIN (SELECT DISTINCT BRItem_ID, Value from mdm.tblBRItemProperties where PropertyType_ID = @ParentAttributeProperty) hier  
            ON bri.ID = hier.BRItem_ID  
	ORDER BY  
	    br.Priority,  
		c.OptionID,  
		brit.Priority  
  
    -- Business rule attribute value properties  
    SELECT	  
		    br.ID As RuleID,  
		    bri.ID AS RuleItemID,  
		    attributes.Name AS RuleValueAttributeName  
	    FROM	  
		    mdm.tblBRBusinessRule br   
		    INNER JOIN @PublishableStatus ps ON br.Status_ID = ps.ID   
		    INNER JOIN mdm.tblBRLogicalOperatorGroup grp ON br.ID = grp.BusinessRule_ID   
		    INNER JOIN mdm.tblBRItem bri ON grp.ID = bri.BRLogicalOperatorGroup_ID   
		    INNER JOIN mdm.tblBRItemTypeAppliesTo aply ON aply.ID = bri.BRItemAppliesTo_ID   
		    INNER JOIN mdm.tblBRItemType brit ON aply.BRItemType_ID = brit.ID  
		    INNER JOIN mdm.tblBRItemProperties brip ON bri.ID = brip.BRItem_ID  
            INNER JOIN mdm.tblAttribute attributes ON attributes.Entity_ID = br.Foreign_ID AND attributes.ID = brip.Value AND br.ForeignType_ID = attributes.MemberType_ID  
	    WHERE   
            brip.PropertyType_ID = @AttributeProperty AND  
	        brip.PropertyName_ID = @ValuePropertyName_ID  
        --The order by clause ensures that the list of attributes always come out in the same order  
        ORDER BY  
            br.Priority,  
            bri.ID,  
            attributes.ID  
  
	SET NOCOUNT OFF  
END --proc
GO
