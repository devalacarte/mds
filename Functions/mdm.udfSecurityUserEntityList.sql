SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, May 09, 2006  
Function   : mdm.udfSecurityUserEntityList  
Component  : Security  
Description: mdm.udfSecurityUserEntityList returns a list of entities and privileges available for a user (read or update).  
Parameters : User ID, Model ID (optional)  
Return     : Table: User_ID (INT), Model_ID (INT), ID (INT), Privilege_ID (INT)  
  
             ID is a foreign key to mdm.tblEntity; Privilege_ID is a foreign key to mdm.tblSecurityPrivilege  
Example 1  : SELECT * FROM mdm.udfSecurityUserEntityList(2, 4)    --All attributes and privileges for UserID = 2 and ModelID = 4  
Example 2  : SELECT * FROM mdm.udfSecurityUserEntityList(2, NULL) --All attributes and privileges for UserID = 2  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityUserEntityList] (@User_ID INT, @Model_ID INT = NULL)   
RETURNS TABLE   
/*WITH SCHEMABINDING*/  
AS  
  
RETURN  
  
SELECT   
   User_ID,   
   Model_ID,   
   ID,   
   Privilege_ID  
FROM   
   mdm.viw_SYSTEM_SECURITY_USER_ENTITY  
WHERE   
   User_ID = @User_ID   
   AND Model_ID = ISNULL(@Model_ID, Model_ID)  
   AND Privilege_ID <> 1
GO
