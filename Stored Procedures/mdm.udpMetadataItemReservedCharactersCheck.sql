SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
/*  
Description: mdm.udpMetadataItemReservedCharactersCheck verifies an input value against a list of reserved characters  
Parameters : @Item (to be verified) , @HasReservedCharacters (output parameter with the result. 1 if value has reserved characters, 0 otherwise)  
  
Example 1:   
DECLARE @HasReservedCharacters BIT;  
SELECT mdm.udpMetadataItemReservedCharactersCheck('Attribute1', @HasReservedCharacters OUTPUT)   --0 = Passes verification (no reserved characters)  
  
Example 2:  
DECLARE @HasReservedCharacters BIT;  
SELECT mdm.udpMetadataItemReservedCharactersCheck('Attribute<\n>2', @HasReservedCharacters OUTPUT) --1 = Fails verification (has newline. <\n> used to indicate newline)  
*/  
  
CREATE PROCEDURE [mdm].[udpMetadataItemReservedCharactersCheck]   
(  
    @Item NVARCHAR(MAX),   
    @HasReservedCharacters BIT OUTPUT  
)   
/*WITH*/  
AS BEGIN   
    SET NOCOUNT ON  
  
    DECLARE @Tab                    NCHAR(1) = CHAR(9),  
            @NewLine                NCHAR(1) = CHAR(10),  
            @CarriageReturn         NCHAR(1) = CHAR(13);  
  
    --Make sure that the Item does have characters to check. No point doing all these checks for nulls or empty strings  
    IF NULLIF(@Item, N'') IS NOT NULL  
    BEGIN  
        --Check for tabs, newlines or carriage return chars  
        IF (CHARINDEX(@Tab, @Item) != 0 OR CHARINDEX(@NewLine, @Item) != 0 OR CHARINDEX(@CarriageReturn, @Item) != 0)  
        BEGIN  
            SET @HasReservedCharacters = 1;  
            RETURN;  
        END  
  
        --Check for chars that can not be serialized to XML by the SQL engine  
        BEGIN TRY  
            DECLARE @Result XML;  
            SELECT @Result = CONVERT(XML, (SELECT @Item FOR XML PATH));  
        END TRY  
        BEGIN CATCH  
            SET @HasReservedCharacters = 1;  
            RETURN;  
        END CATCH  
    END  
  
    SET @HasReservedCharacters = 0;  
  
    SET NOCOUNT OFF  
END --udpMedatataItemReservedCharactersCheck
GO
