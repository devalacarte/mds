SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, May 09, 2006  
Function   : mdm.udfSecurityUserFunctionList  
Component  : Security  
Description: mdm.udfSecurityUserFunctionList returns a list of functions available for an active user (Status_ID = 1)  
Parameters : User ID (optional)  
Return     : Table: User_ID (INT), Function_ID (INT), Function_Name  
Example 1  : SELECT * FROM mdm.udfSecurityUserFunctionList(NULL)  
Example 2  : SELECT * FROM mdm.udfSecurityUserFunctionList(2)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityUserFunctionList]   
(  
	@User_ID INT = NULL  
)   
RETURNS TABLE   
/*WITH SCHEMABINDING*/  
AS  
RETURN  
  
SELECT  
   [User_ID],   
   Foreign_ID,   
   ForeignType_ID,  
   Foreign_MUID,   
   Function_ID,   
   Function_Constant,   
   Function_Name,  
   IsExplicit,  
   MUID,  
   Permission_ID  
FROM	mdm.viw_SYSTEM_SECURITY_USER_FUNCTION  
WHERE   
	User_ID = ISNULL(@User_ID, User_ID)  
	AND Status_ID = 1  
	AND	IsExplicit = 1  
UNION  
SELECT  
   ssuf.[User_ID],   
   ssuf.Foreign_ID,   
   ssuf.ForeignType_ID,  
   ssuf.Foreign_MUID,   
   ssuf.Function_ID,   
   ssuf.Function_Constant,   
   ssuf.Function_Name,  
   ssuf.IsExplicit,  
   ssuf.MUID,  
   ssuf.Permission_ID  
FROM	mdm.viw_SYSTEM_SECURITY_USER_FUNCTION ssuf  
WHERE   
	ssuf.User_ID = ISNULL(@User_ID, User_ID)  
	AND ssuf.Status_ID = 1  
	AND	ssuf.IsExplicit = 0  
	AND		NOT EXISTS (  
			SELECT	Function_ID   
			FROM	mdm.viw_SYSTEM_SECURITY_USER_FUNCTION  
			WHERE	User_ID = ISNULL(@User_ID, User_ID)  
			AND		IsExplicit = 1  
			AND Function_ID =ssuf.Function_ID  
			)
GO
