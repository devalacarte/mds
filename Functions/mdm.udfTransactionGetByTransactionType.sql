SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
--SELECT * FROM mdm.udfTransactionGetByTransactionType(2)  
  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfTransactionGetByTransactionType] (@TransactionType_ID INT)   
RETURNS TABLE  
/*WITH SCHEMABINDING*/  
AS  
RETURN  
	SELECT OptionID ID, ListOption Code   
	FROM mdm.tblList   
	WHERE ListCode = CAST(N'lstTransaction' AS NVARCHAR(50)) AND Group_ID = @TransactionType_ID
GO
