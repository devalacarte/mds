SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_BUSINESSRULES_HIERARCHY_CHANGEVALUE_INHERITANCE   
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_BUSINESSRULES_HIERARCHY_CHANGEVALUE_INHERITANCE]  
/*WITH SCHEMABINDING*/  
AS  
	SELECT  
	    DISTINCT   
	      br.Model_ID AS ModelID  
	     ,br.Entity_ID AS EntityID  
	     ,br.Entity_Name AS EntityName  
	     ,a.Name AS AttributeName  
	     ,a.TableColumn AS AttributeColumnName  
	     ,h.ID AS [HierarchyID]  
	     ,h.Name AS HierarchyName  
	FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES p  
    INNER JOIN mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES itm  
        on itm.BRSubType = N'Change value' AND itm.BRItemType_ID IN (14,16) -- Equals, Equals concatenated  
        and p.Item_AppliesTo_ID = itm.AppliesTo_ID  
        and p.PropertyType_ID = 2 -- Attribute  
        and p.Property_IsLeftHandSide = 0   
	INNER JOIN mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES br  
        on  p.BusinessRule_ID = br.BusinessRule_ID  
        and p.BusinessRule_Status = 1 -- Active   
    INNER JOIN mdm.tblAttribute a  
        on a.ID = CAST(p.Property_Value AS INT)  
    INNER JOIN mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES hier_p          
        on  hier_p.BusinessRule_ID = br.BusinessRule_ID  
        and hier_p.PropertyType_ID = 3 -- Hierarchy  
    INNER JOIN mdm.tblHierarchy h  
        on h.ID = CAST(hier_p.Property_Value AS INT)
GO
