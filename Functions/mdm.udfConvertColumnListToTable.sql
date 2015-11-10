SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
select * from mdm.udfConvertColumnListToTable('T.Name, T.AccountType, Operator as Op' )  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfConvertColumnListToTable]  
(  
	@List      NVARCHAR(MAX)   
)  
RETURNS @tbl TABLE   
(  
	Ordinal int IDENTITY(1, 1) NOT NULL,  
	SchemaName	sysname NULL,  
	ObjectName	sysname NOT NULL,  
    Alias		sysname NULL  
)   
/*WITH SCHEMABINDING*/              
AS  
BEGIN  
  
        DECLARE     @end            INT,  
                @start              INT,  
                @current            INT,  
                @chunkLength        INT,  
				@alias				sysname,  
                @workingValue       NVARCHAR(MAX),  
                @remainingValue     NVARCHAR(MAX),  
                @parsedValue        NVARCHAR(MAX),  
				@delimiter NCHAR(1),  
				@as nchar(4)   
				  
	SET @as = CAST(N' AS ' AS NVARCHAR(4))  
	SET @delimiter = N','  
    SET @current = 1  
    SET @remainingValue = CAST(N'' AS NVARCHAR(max))  
    IF @List IS NULL RETURN  
  
    WHILE @current <= DATALENGTH(@List) / 2  
    BEGIN  
        SET @chunkLength = 4000 - DATALENGTH(@remainingValue) / 2  
        SET @workingValue = @remainingValue + SUBSTRING(@List, @current, @chunkLength)  
        SET @current = @current + @chunkLength  
  
        SET @start = 0  
  
        SET @end = CHARINDEX(@delimiter COLLATE database_default, @workingValue)  
  
  
        WHILE @end > 0  
  
        BEGIN  
  
            SET @parsedValue = LTRIM(RTRIM(SUBSTRING(@workingValue, @start + 1, @end - @start - 1)))  
			SET @alias = NULL  
			IF CHARINDEX(@as, UPPER(@parsedValue)) <> 0  
				BEGIN  
				SET @alias = LTRIM(RTRIM(SUBSTRING(@parsedValue  
										,CHARINDEX(@as, UPPER(@parsedValue) ) + LEN(@as)  
										, LEN(@parsedValue) - CHARINDEX(@parsedValue, @as) + LEN(@as))))  
				--trailing spaces cause incorrect results for parsename!  
				SET @parsedValue = LTRIM(RTRIM(LEFT(@parsedValue, CHARINDEX(@as, UPPER(@parsedValue) ))))  
				  
				END              
  
            INSERT @tbl (SchemaName, ObjectName, Alias)   
			VALUES(LTRIM(RTRIM(PARSENAME(@parsedValue,2)))   
					,LTRIM(RTRIM(PARSENAME(@parsedValue, 1)))  
					,@alias  
					)  
            SET @start = @end  
  
            SET @end = CHARINDEX(@delimiter COLLATE database_default, @workingValue, @start + 1)  
  
        END  
  
        SET @remainingValue = RIGHT(@workingValue, DATALENGTH(@workingValue) / 2 - @start)  
		IF CHARINDEX(@as, UPPER(@remainingValue)) <> 0  
				BEGIN  
					SET @alias = LTRIM(RTRIM(SUBSTRING(@remainingValue  
										,CHARINDEX(@as, UPPER(@remainingValue) ) + LEN(@as)  
										, LEN(@remainingValue) - CHARINDEX(@remainingValue, @as) + LEN(@as))))  
				  
					--trailing spaces cause incorrect results for parsename!  
					SET @remainingValue = LTRIM(RTRIM(LEFT(@remainingValue, CHARINDEX(@as, UPPER(@remainingValue) ))))  
				  
				END              
    END  
  
    --insert the last piece of the string  
    INSERT @tbl(SchemaName, ObjectName, Alias)  
          VALUES (LTRIM(RTRIM(PARSENAME(@remainingValue,2)))   
					,LTRIM(RTRIM(PARSENAME(@remainingValue, 1) ))  
					,@alias  
					)  
    RETURN  
END
GO
