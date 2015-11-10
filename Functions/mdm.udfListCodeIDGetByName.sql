SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT mdm.udfListCodeIDGetByName('lstVersionStatus', 'Leaf')  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfListCodeIDGetByName]  
(  
	@ListCode NVARCHAR(50),  
	@ListOption NVARCHAR(250)  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @ListCodeID INT  
		  
	SELECT	@ListCodeID = OptionID   
	FROM 	mdm.tblList   
	WHERE 	ListCode = @ListCode  
	AND 	ListOption = @ListOption  
		  
	RETURN @ListCodeID	     
  
END --fn
GO
