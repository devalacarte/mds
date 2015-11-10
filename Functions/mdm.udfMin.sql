SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	Function   : mdm.udfMIN  
	Component  : Security  
	Description: This function returns the smaller of two values  
	Parameters : First value, Second value  
	Return     : Value  
	Example 1  : SELECT mdm.udfMin(3, 2)  
	Example 2  : SELECT mdm.udfMin(1, 2)  
	Example 3  : SELECT mdm.udfMin(3, NULL)  
	Example 4  : SELECT mdm.udfMin(NULL, 3)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMin]  
(  
	@Value1 INT,   
	@Value2 INT  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	SET @Value1 = COALESCE(@Value1, @Value2);  
	SET @Value2 = COALESCE(@Value2, @Value1);  
	RETURN CASE WHEN @Value1 < @Value2 THEN @Value1 ELSE @Value2 END;  
END; --fn
GO
