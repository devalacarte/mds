SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfEntityGetIDByName(NULL, 'Product', NULL, 'Product')  
  
	SELECT mdm.udfEntityGetIDByName(NULL, 'Account', '65DC94B4-FD16-4FB8-9440-43DB0E14F6A4', 'Product')  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfEntityGetIDByName]  
(  
	@Model_MUID				UNIQUEIDENTIFIER,  
	@Model_Name				NVARCHAR(50),  
	@Entity_MUID			UNIQUEIDENTIFIER,   
	@Entity_Name			NVARCHAR(50)  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
    DECLARE @Model_ID INT,  
            @Entity_ID INT;  
          
      
	IF (@Model_Name IS NOT NULL OR @Model_MUID IS NOT NULL)   
	BEGIN  
  
		SELECT @Model_ID = mdm.udfModelGetIDByName(@Model_MUID, @Model_Name)   
  
		IF (@Model_ID IS NULL) --Invalid Model ID  
        BEGIN  
	        RETURN -3;  
              
        END  
  
	    SET @Entity_ID = ISNULL((SELECT ID FROM mdm.tblEntity WHERE   
	        (@Entity_MUID IS NULL OR MUID = @Entity_MUID) AND (@Entity_Name IS NULL OR [Name] = @Entity_Name) AND (@Entity_MUID IS NOT NULL OR @Entity_Name IS NOT NULL)  
	        AND Model_ID = @Model_ID),-2);  
    END  
    ELSE  
	        SET @Entity_ID = ISNULL((SELECT ID FROM mdm.tblEntity WHERE   
                @Entity_MUID IS NOT NULL AND MUID = @Entity_MUID), -1);  
  
  
	RETURN @Entity_ID;  
END; --fn
GO
