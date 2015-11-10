SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
  
	 SELECT * FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY WHERE ParentEntityID = 81  
	 SELECT * FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY WHERE ParentEntityID = 80  
	 SELECT * FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY WHERE ParentEntityID = 79  
	 SELECT * FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY WHERE ParentEntityID = 78  
	 SELECT * FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY WHERE ParentModelID = 9  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY]  
/*WITH SCHEMABINDING*/  
AS  
  
select	  
		a.Model_ID AS ParentModelID,  
		a.Attribute_Entity_ID AS ParentEntityID,  
		a.Attribute_Entity_Name AS ParentEntityName,  
		a.Attribute_Name AS ParentAttributeName,  
		a.Attribute_Column AS ParentAttributeColumnName,  
		dba.Attribute_Entity_ID ChildEntityID,  
		dba.Attribute_Entity_Name AS ChildEntityName,  
		dba.Attribute_Name AS ChildAttributeName,  
		dba.Attribute_Column AS ChildAttributeColumnName,  
		a.Attribute_MemberType_ID  
from	mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES a  
        inner join 	mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES dba  
			on a.PropertyType_ID = 2   
			and a.Property_IsLeftHandSide = 0 			  
			and dba.PropertyType_ID = 4 -- DBA attribute  
            and a.Property_Parent_ID = dba.Property_ID  
            and a.BusinessRule_Status = 1 -- Active   
        inner join mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES itm  
            on itm.BRSubType = N'Change value' AND itm.BRItemType_ID IN (14,16) -- Equals, Equals concatenated  
            and a.Item_AppliesTo_ID = itm.AppliesTo_ID
GO
