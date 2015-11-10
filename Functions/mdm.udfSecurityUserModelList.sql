SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, May 09, 2006  
Function   : mdm.udfSecurityUserModelList  
Component  : Security  
Description: mdm.udfSecurityUserModelList returns a list of Models and privileges available for a user (read or update).  
Parameters : User ID  
Return     : Table: ID (INT), Privilege_ID (INT)  
  
             ID is a foreign key to mdm.tblModel; Privilege_ID is a foreign key to mdm.tblSecurityPrivilege  
Example 1  : SELECT * FROM mdm.udfSecurityUserModelList(2) --All Models and privileges for UserID = 2  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityUserModelList] (@User_ID INT)   
RETURNS TABLE   
/*WITH SCHEMABINDING*/  
AS  
  
RETURN  
  
SELECT     
   User_ID,  
   ID,  
   Privilege_ID,  
   IsAdministrator  
FROM   
   mdm.viw_SYSTEM_SECURITY_USER_MODEL  
WHERE   
   User_ID = @User_ID   
   AND Privilege_ID <> 1
GO
