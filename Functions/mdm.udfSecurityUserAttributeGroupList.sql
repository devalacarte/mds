SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, May 09, 2006  
Function   : mdm.udfSecurityUserAttributeGroupList  
Component  : Security  
Description: mdm.udfSecurityUserAttributeGroupList returns a list of attribute groups and privileges available for a user (read or update).  
Parameters : User ID, Model ID (optional), Entity ID (optional), Member Type ID (optional)  
Return     : Table: User_ID (INT), Model_ID (INT), Entity_ID (INT), ID (INT), Privilege_ID (INT)  
  
             ID is a foreign key to mdm.tblAttributeGroup; Privilege_ID is a foreign key to mdm.tblSecurityPrivilege  
Example 1  : SELECT * FROM mdm.udfSecurityUserAttributeGroupList(1, 1, 2, NULL)    --All attributes and privileges for UserID = 1, ModelID = 1, Entity ID = 2, and all member types  
Example 2  : SELECT * FROM mdm.udfSecurityUserAttributeGroupList(1, NULL, NULL, 1) --All attributes and privileges for UserID = 1, member type = leaf  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityUserAttributeGroupList] (@User_ID INT, @Model_ID INT = NULL, @Entity_ID INT = NULL, @MemberType_ID TINYINT = NULL)   
RETURNS TABLE   
/*WITH SCHEMABINDING*/  
AS  
  
RETURN  
  
SELECT   
   tSec.User_ID,   
   tEnt.Model_ID,   
   tSec.Entity_ID,   
   tSec.MemberType_ID,   
   tSec.ID,   
   tSec.Privilege_ID  
FROM   
   mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTEGROUP tSec JOIN mdm.tblEntity tEnt ON tSec.Entity_ID = tEnt.ID   
WHERE   
   tSec.User_ID = @User_ID   
   AND tEnt.Model_ID  = ISNULL(@Model_ID, tEnt.Model_ID)  
   AND tEnt.ID = ISNULL(@Entity_ID, tEnt.ID)  
   AND tSec.MemberType_ID = ISNULL(@MemberType_ID, tSec.MemberType_ID)  
   AND Privilege_ID <> 1
GO
