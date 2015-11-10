SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpDataQualityOperationsGet]  
	@CreatedBefore DATETIME2 = NULL  
AS BEGIN  
	SET NOCOUNT ON;  
	  
        SELECT CreateDTM, OperationId, SerializedOperation  
        FROM [mdm].[tblDataQualityOperationsState]  
        WHERE (@CreatedBefore IS NULL) OR (CreateDTM <= @CreatedBefore)  
  
	SET NOCOUNT OFF;  
END;
GO
