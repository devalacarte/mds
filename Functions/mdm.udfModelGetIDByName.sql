SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfModelGetIDByName(NULL, 'Product')  
	SELECT mdm.udfModelGetIDByName(NULL, 'Account')  
	SELECT mdm.udfModelGetIDByName(NULL, NULL)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfModelGetIDByName]  
(  
	@Model_MUID				UNIQUEIDENTIFIER,  
	@Model_Name				NVARCHAR(50)  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
    DECLARE @Model_ID INT;  
          
		SELECT @Model_ID = ID FROM mdm.tblModel WHERE   
            (@Model_MUID IS NULL OR MUID = @Model_MUID) AND (@Model_Name IS NULL OR [Name] = @Model_Name) AND (@Model_MUID IS NOT NULL OR @Model_Name IS NOT NULL)  
	RETURN @Model_ID;  
END; --fn
GO
