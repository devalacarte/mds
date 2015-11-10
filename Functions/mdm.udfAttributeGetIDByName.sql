SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfAttributeGetIDByName(NULL, NULL, NULL, NULL, NULL, NULL, 1, 0)  
	SELECT mdm.udfAttributeGetIDByName(NULL, 'Product', NULL, 'Product', NULL, 'ModelName', 1, 0)  
	SELECT mdm.udfAttributeGetIDByName('8CDCE317-B147-4AC2-B877-C780A33D241B', NULL, NULL, 'Product', NULL, 'ModelName', 1, 0)  
	SELECT mdm.udfAttributeGetIDByName(NULL, NULL, NULL, NULL, 'C6BC0705-6EAC-4329-935C-E4C48B472818', NULL, 1, 0)  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfAttributeGetIDByName]  
(  
	@Model_MUID				UNIQUEIDENTIFIER,  
	@Model_Name				NVARCHAR(50),  
	@Entity_MUID			UNIQUEIDENTIFIER,   
	@Entity_Name			NVARCHAR(50),  
	@Attribute_MUID			UNIQUEIDENTIFIER,   
	@Attribute_Name			NVARCHAR(50),  
	@MemberType_ID			TINYINT,  
    @IsSystem               BIT = 0  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
    DECLARE @Entity_ID INT,  
            @Attribute_ID INT;  
          
    SET @IsSystem = ISNULL(@IsSystem, 0);  
      
	IF (@Entity_Name IS NOT NULL OR @Entity_MUID IS NOT NULL)  
	BEGIN  
	    SELECT @Entity_ID = mdm.udfEntityGetIDByName(@Model_MUID, @Model_Name, @Entity_MUID, @Entity_Name)   
        SELECT @Entity_ID = ISNULL(@Entity_ID, -2);  
  
	    IF (@Entity_ID < 0) --Invalid Model ID or Entity ID  
            RETURN @Entity_ID;  
  
	    SET @Attribute_ID = ISNULL((SELECT ID FROM mdm.tblAttribute WHERE   
	        (@Attribute_MUID IS NULL OR MUID = @Attribute_MUID) AND (@Attribute_Name IS NULL OR [Name] = @Attribute_Name) AND (@Attribute_MUID IS NOT NULL OR @Attribute_Name IS NOT NULL)  
	        AND IsSystem = @IsSystem AND Entity_ID = @Entity_ID AND MemberType_ID = @MemberType_ID), -1);  
  
    END  
    ELSE  
	    SET @Attribute_ID = ISNULL((SELECT ID FROM mdm.tblAttribute WHERE   
	        @Attribute_MUID IS NOT NULL AND MUID = @Attribute_MUID AND IsSystem = @IsSystem), -1);  
      
	RETURN @Attribute_ID;  
END; --fn
GO
