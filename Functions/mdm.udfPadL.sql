SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, June 06, 2006  
Function   : mdm.udfPadL  
Component  : All  
Description: mdm.udfPadL returns a left padded string value  
Parameters : Input string, Pad length, Pad character  
Return     : Left padded string value  
Example    : SELECT mdm.udfPadL(2, 5, '0')  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfPadL](@value NVARCHAR(MAX), @len INT, @char NVARCHAR(1))   
RETURNS NVARCHAR(MAX)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	--The concatenation code below is due to an issue in SQL  
	--whereby this comparison (N'' == N' ') is TRUE  
	IF (@char IS NULL OR LEN(N'|' + @char + N'|') = 2) RETURN @value;  
	  
	RETURN REPLICATE(@char, @len - LEN(@value)) + @value;  
END; --fn
GO
