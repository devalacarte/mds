SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfConvertCharListToTable]  
(  
	@List      NVARCHAR(MAX),  
    @Delimiter NCHAR(1) = N',',  
    @AreValuesQuoted bit = 0  
)  
RETURNS @tbl TABLE   
(  
	Ordinal int IDENTITY(1, 1) NOT NULL,  
    Value NVARCHAR(MAX) NOT NULL  
)   
/*WITH SCHEMABINDING*/  
AS  
BEGIN  
  
    DECLARE     @end                INT,  
                @start              INT,  
                @current            INT,  
                @chunkLength        INT,  
                @workingValue       NVARCHAR(MAX),  
                @remainingValue     NVARCHAR(MAX),  
                @parsedValue        NVARCHAR(MAX)  
  
    SET @current = 1  
    SET @remainingValue = CAST(N'' AS NVARCHAR(max))  
  
  
    WHILE @current <= DATALENGTH(@List) / 2  
    BEGIN  
        SET @chunkLength = 4000 - DATALENGTH(@remainingValue) / 2  
        SET @workingValue = @remainingValue + SUBSTRING(@List, @current, @chunkLength)  
        SET @current = @current + @chunkLength  
  
        SET @start = 0  
  
        SET @end = CHARINDEX(@Delimiter COLLATE database_default, @workingValue)  
  
  
        WHILE @end > 0  
  
        BEGIN  
  
            SET @parsedValue = LTRIM(RTRIM(SUBSTRING(@workingValue, @start + 1, @end - @start - 1)))  
            IF @AreValuesQuoted = 1  
                SET @parsedValue = SUBSTRING(@parsedValue,2,len(@parsedValue)-2)  
              
            INSERT @tbl (Value) VALUES(@parsedValue)  
  
            SET @start = @end  
  
            SET @end = CHARINDEX(@Delimiter COLLATE database_default, @workingValue, @start + 1)  
  
        END  
  
		SET @remainingValue = LTRIM(RTRIM(RIGHT(@workingValue, DATALENGTH(@workingValue) / 2 - @start)))  
        IF @AreValuesQuoted = 1  
			BEGIN  
				SET @remainingValue = SUBSTRING(@remainingValue, 2, len(@remainingValue)-2)  
			END  
  
    END  
  
    --insert the last piece of the string  
    INSERT @tbl(Value)  
          VALUES (LTRIM(RTRIM(@remainingValue)))  
    RETURN  
END
GO
