SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
  
Assumptions:  
        1) Assume that ONLY values to be subtituted are marked with a % followed by a number as %1, %2 etc..  
        2) Assume the values are incremental and not higher than 9  
          
  
select mdm.udfDBErrorsGetMessageByIDLanguage(500001, 1036, NULL)  
  
  
*/  
/*==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE function [mdm].[udfDBErrorsGetMessageByIDLanguage]  
(  
   @ID				INT,  
   @Language_ID		INT,  
   @Values          NVARCHAR(4000) = NULL   
)  
RETURNS NVARCHAR(4000)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
      
    DECLARE @Message NVARCHAR(4000),  
            @ReplaceValue NVARCHAR(4000),  
            @MessageIndex INT,  
            @ValuesIndex INT,  
			@Count	INT;  
      
    IF @Language_ID = 0 SET @Language_ID = 1033   
	SELECT @Message = [Text]  
	FROM mdm.tblDBErrors e  
	WHERE e.ID = @ID   
		AND e.Language_ID = @Language_ID;  
  
    IF @Values IS NULL SET @Values = CAST(N'' AS NVARCHAR(4000));  
    IF @Message IS NULL SET @Message = CAST(N'Message not found in error table' AS NVARCHAR(4000));  
      
  /* Assumptions:  
        1) Assume that ONLY values to be subtituted are marked with a % followed by a number as %1, %2 etc..  
        2) Assume the values are incremental and not higher than 9  
    */   
    SET @MessageIndex = CHARINDEX('%', @Message);  
   --Get the first value to be substituted  
   SET @ValuesIndex = CHARINDEX('%', @Values);  
  
    SET @Count = 0  
      
    WHILE (@MessageIndex > 0 AND @ValuesIndex > 0 AND @Count < 10)  
    BEGIN  
         
		--keep track of how many values we are replacing  
		SET @Count = @Count + 1    
  
		--get the value to replace with  
		SET @ReplaceValue = SUBSTRING(@Values, 1, @ValuesIndex - 1);  
  
		-- Perform the substitution  
		SET @Message = REPLACE(@Message, SUBSTRING(@Message, @MessageIndex , 2), @ReplaceValue);  
  
		-- Remove the substituted value  
		SET @Values =  SUBSTRING(@Values, @ValuesIndex + 1, LEN(@Values) - @ValuesIndex)      
  
		--Get the next value to be substituted  
		SET @MessageIndex = CHARINDEX('%', @Message);  
		SET @ValuesIndex = CHARINDEX('%', @Values);  
	  
    END;  
      
	--Perform the last replacement  
	IF @MessageIndex > 0 AND @ValuesIndex = 0 AND LEN(@Values) > 0  
       SET @Message = REPLACE(@Message, SUBSTRING(@Message, @MessageIndex, 2), @Values);  
  
	RETURN @Message;  
    	  
END
GO
