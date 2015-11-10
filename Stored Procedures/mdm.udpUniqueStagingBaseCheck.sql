SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUniqueStagingBaseCheck]  
(  
	@StagingBase			NVARCHAR(60),  
	@IsUnique				BIT OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
	  
	-- If the StagingBase is unique return 1. Otherwise return 0.   
	Set @StagingBase = LTRIM(RTRIM(@StagingBase));  
		  
	IF EXISTS (SELECT 1 FROM mdm.tblEntity WHERE StagingBase = @StagingBase) BEGIN  
		SET @IsUnique = 0;  
	END;   
	ELSE BEGIN  
		SET @IsUnique = 1;  
	END; -- IF  
  
	SET NOCOUNT OFF  
END --proc
GO
