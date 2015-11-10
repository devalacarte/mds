SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Function   : mdm.udfSecurityUserHierarchyDerivedItem  
Component  : Security  
Description: mdm.udfSecurityUserHierarchyDerivedItem determines if an item appears in a Derived Hierarchy and, if so, returns the explicit permission assigned to the hierarchy.  
Parameters : User ID, Security Object ID, Item ID (Entity, Attribute, Explicit Hierarchy)  
Return     : Privilege_ID  
Example 1  : SELECT mdm.udfSecurityUserHierarchyDerivedItem(10, 5, 3, 26)  
Example 2  : SELECT mdm.udfSecurityUserHierarchyDerivedItem(10, NULL, 3, 26)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityUserHierarchyDerivedItem]   
(  
	@User_ID INT,   
	@Hierarchy_ID INT,   
	@Object_ID INT,   
	@Item_ID INT  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN   
  
RETURN  
    (SELECT MIN(Privilege_ID)  
       FROM mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS tHir   
       JOIN (SELECT ID, Privilege_ID   
               FROM mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY_DERIVED   
              WHERE User_ID = @User_ID AND ID = ISNULL(@Hierarchy_ID, ID)) tSec   
         ON tHir.Hierarchy_ID = tSec.ID  
      WHERE Object_ID = @Object_ID AND Foreign_ID = @Item_ID)  
  
END  --fn
GO
