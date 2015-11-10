SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [mdq].[IsDateTime2] (@input [nvarchar] (max))
RETURNS [bit]
WITH EXECUTE AS CALLER
EXTERNAL NAME [Microsoft.MasterDataServices.DataQuality].[Microsoft.MasterDataServices.DataQuality.SqlClr].[IsDateTime2]
GO
