SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Returns the number of times that @SearchString appears in @InputString  
  
DECLARE   
     @InputString NVARCHAR(MAX) = '35/31/34/33/32/31'  
    ,@SearchString NVARCHAR(100) = '31';  
  
SELECT   
    @InputString AS InputString,  
    LEN(@InputString) AS [Len Input String],  
    REPLACE(@InputString, @SearchString, '') AS [InputString Replace],  
    LEN(REPLACE(@InputString, @SearchString, '')) AS [Len InputString Replace],  
    @SearchString AS SearchString,  
    LEN(@SearchString) AS [Len SearchString],  
    (LEN(@InputString) - LEN(REPLACE(@InputString, @SearchString, ''))) AS [Len Diff],  
    (LEN(@InputString) - LEN(REPLACE(@InputString, @SearchString, ''))) / LEN(@SearchString) AS [Len Diff / Len SearchString]  
  
SELECT mdm.udfGetStringOccurrenceCount(@InputString, @SearchString);  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfGetStringOccurrenceCount]  
(   
    @InputString  NVARCHAR(MAX),   
    @SearchString NVARCHAR(100)   
)  
RETURNS INT  
BEGIN  
  
    RETURN (LEN(@InputString) - LEN(REPLACE(@InputString, @SearchString, N''))) / LEN(@SearchString)  
  
END
GO
