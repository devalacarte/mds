SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, May 09, 2006  
Function   : mdm.udfSecurityUserMemberTypeList  
Component  : Security  
Description: mdm.udfSecurityUserMemberTypeList returns a list of member types and privileges available for a user (read or update).  
Parameters : User ID, Model ID (optional), Entity ID (optional)  
Return     : Table: User_ID (INT), Model_ID (INT), Entity_ID (INT), ID (INT), Privilege_ID (INT)  
             ID is a foreign key to mdm.tblList; Privilege_ID is a foreign key to mdm.tblSecurityPrivilege  
Example 1  : SELECT * FROM mdm.udfSecurityUserMemberTypeList(2, 1, 2)       --All attributes and privileges for UserID = 2, ModelID = 1, and Entity ID = 2  
Example 2  : SELECT * FROM mdm.udfSecurityUserMemberTypeList(2, NULL, NULL) --All attributes and privileges for UserID = 2  
  
*/  
  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityUserMemberTypeList] (@User_ID INT, @Model_ID INT = NULL, @Entity_ID INT = NULL)   
RETURNS TABLE   
/*WITH SCHEMABINDING*/  
AS  
  
RETURN  
  
SELECT   
   tSec.User_ID,   
   tEnt.Model_ID,   
   tSec.Entity_ID,   
   tSec.ID,   
   tSec.Privilege_ID  
FROM   
  
	mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE tSec   
		JOIN mdm.tblEntity tEnt ON tSec.Entity_ID = tEnt.ID   
  
WHERE   
   tSec.User_ID = @User_ID     
   AND ((@Model_ID IS NULL) OR (tEnt.Model_ID = @Model_ID))  
   AND ((@Entity_ID IS NULL) OR (tEnt.ID = @Entity_ID))  
   AND Privilege_ID <> 1
GO
