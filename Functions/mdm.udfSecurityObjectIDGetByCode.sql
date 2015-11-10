SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Friday, September 8, 2006  
Function   : mdm.udfSecurityObjectIDGetByCode  
Component  : All  
Description: mdm.udfSecurityObjectIDGetByCode returns an ID associated with a security object code.  
Parameters : Object code  
Return     : String  
Example    :   
			SELECT mdm.udfSecurityObjectIDGetByCode('DIMATT')  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityObjectIDGetByCode] (@ObjectCode NVARCHAR(6))   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
   RETURN (SELECT ID FROM mdm.tblSecurityObject WHERE Code = @ObjectCode)  
END --fn
GO
