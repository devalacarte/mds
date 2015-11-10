SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [mdq].[IsBigInt] (@input [nvarchar] (max))
RETURNS [bit]
WITH EXECUTE AS CALLER
EXTERNAL NAME [Microsoft.MasterDataServices.DataQuality].[Microsoft.MasterDataServices.DataQuality.SqlClr].[IsBigInt]
GO
