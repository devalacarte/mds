SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Call the udpGenerateCodeRange to allocate a range of codes for a code gen enabled entity. The SPROC has two output parameters CodeRangeStart  
and CodeRangeEnd which defines an inclusive range of usable code values. This means that if CodeRangeStart comes out 5 and CodeRangeEnd comes  
out 14 the ten codes 5,6,7,8,9,10,11,12,13,14 have been allocated  
  
Example  
    DECLARE @Start BIGINT, @End BIGINT;  
    EXEC mdm.udpGenerateCodeRange @Entity_ID = 31, @NumberOfCodesToGenerate = 3, @CodeRangeStart = @Start OUTPUT, @CodeRangeEnd = @End OUTPUT;  
  
This is an example of how calling SPROC might call this SPROC and use its output to populate codes:  
  
declare @Codes Table (Code nvarchar(250));  
insert into @Codes Values(null);  
insert into @Codes Values('text');  
insert into @Codes Values(null);  
insert into @Codes Values('arun');  
insert into @Codes Values(null);  
insert into @Codes Values(null);  
insert into @Codes Values(null);  
insert into @Codes Values('blah');  
insert into @Codes Values(null);  
  
declare @numberofcodes int;  
set @numberofcodes = (select COUNT(*) FROM @Codes WHERE Code is null);  
  
DECLARE @Start BIGINT, @End BIGINT;  
EXEC mdm.udpGenerateCodeRange @Entity_ID = 31, @NumberOfCodesToGenerate = @numberofcodes, @CodeRangeStart = @Start OUTPUT, @CodeRangeEnd = @End OUTPUT;  
  
DECLARE @Counter BIGINT = @Start - 1;  
  
UPDATE @Codes  
SET @Counter = @Counter + 1,  
	Code = CONVERT(NVARCHAR(250), @Counter)  
WHERE Code IS NULL;  
*/  
CREATE PROCEDURE [mdm].[udpGenerateCodeRange]  
(  
    @Entity_ID		            INT,  
    @NumberOfCodesToGenerate    INT,  
    @CodeRangeStart BIGINT OUTPUT,  
    @CodeRangeEnd BIGINT OUTPUT  
)  
AS BEGIN  
  
    SET NOCOUNT ON;  
  
    IF NOT EXISTS(SELECT * FROM mdm.tblCodeGenInfo WHERE EntityId = @Entity_ID)  
        BEGIN  
            RAISERROR('MDSERR310054|This entity does not support automatic code generation', 16, 1);  
            RETURN;  
        END  
  
    --We use this complicated update statement to ensure that while we are doing the calculations  
    --to generate the codes we have an exclusive lock on this row  
    --First, calculate the current largest value. If the LargestCodeValue is null or smaller than the  
    --Seed the current largest value is the seed. If the LargestCodeValue is greater than or equal to  
    --the Seed then the current largest is LargestCodeValue  
    UPDATE mdm.tblCodeGenInfo  
    SET @CodeRangeStart = CASE WHEN LargestCodeValue IS NULL OR LargestCodeValue < Seed THEN Seed ELSE LargestCodeValue + 1 END,  
        @CodeRangeEnd = LargestCodeValue = @CodeRangeStart + (@NumberOfCodesToGenerate - 1)  
    WHERE EntityId = @Entity_ID;  
  
END; --proc mdm.udpGenerateCodeRange
GO
