SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Call the udpGenerateNextCode generate the next code for a code gen enabled entity  
  
Example  
    DECLARE @Code NVARCHAR(250);  
    EXEC @Code = mdm.udpGenerateNextCode @Entity_ID = 20;  
*/  
CREATE PROCEDURE [mdm].[udpGenerateNextCode]  
(  
    @Entity_ID		INT  
)  
AS BEGIN  
  
    SET NOCOUNT ON;  
  
    DECLARE @GeneratedCode          NVARCHAR(250) = NULL;  
    DECLARE @Start BIGINT, @End BIGINT;  
  
    --Generate one code. Start and End should come out equal  
    EXEC mdm.udpGenerateCodeRange   @Entity_ID = @Entity_ID,   
                                    @NumberOfCodesToGenerate = 1,   
                                    @CodeRangeStart = @Start OUTPUT,   
                                    @CodeRangeEnd = @End OUTPUT;  
  
    --Convert the generated code to an nvarchar  
    SET @GeneratedCode = CONVERT(NVARCHAR(250), @Start);  
  
    RETURN @GeneratedCode;  
  
END; --proc mdm.udpGenerateNextCode
GO
