SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [mdq].[DateToString] (@input [datetime], @dateFormat [nvarchar] (max))
RETURNS [nvarchar] (max)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Microsoft.MasterDataServices.DataQuality].[Microsoft.MasterDataServices.DataQuality.SqlClr].[DateToString]
GO
