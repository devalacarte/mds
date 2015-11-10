SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT mdm.udfUniqueStagingBaseGet('Product')  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfUniqueStagingBaseGet]  
(  
	@StagingBaseName	NVARCHAR(50) -- An entity name or the first 50 characters of StagingBase.  
)   
RETURNS NVARCHAR(50)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @NewStagingBase NVARCHAR(60),  
			@Count			INT = 0;  
		  
	SET	@NewStagingBase = @StagingBaseName  
	  
	-- If @NewStagingBase is not unique append the sequence number to make it unique.  
	WHILE EXISTS (SELECT 1 FROM mdm.tblEntity WHERE StagingBase = @NewStagingBase)  
	BEGIN  
		SET @Count = @Count + 1;  
		SET @NewStagingBase = @StagingBaseName + N'_' + CONVERT(NVARCHAR(10), @Count)   
	END; -- WHILE	  
		  
	RETURN @NewStagingBase;	     
  
END --fn
GO
