SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Call the udpIsCodeGenEnabled to check whether an entity supports code generation.  
  
Example  
DECLARE @MemberCodes AS mdm.MemberCodes  
insert into @MemberCodes(MemberCode) values (N'HL-U509-BL');   
insert into @MemberCodes(MemberCode) values (N'BK-M38S-46');   
insert into @MemberCodes(MemberCode) values (N'100');   
insert into @MemberCodes(MemberCode) values (N'BK-M38Z-51');   
insert into @MemberCodes(MemberCode) values (N'BK-M38Z-55');   
insert into @MemberCodes(MemberCode) values (N'999');   
  
EXEC mdm.udpProcessCodes @Entity_ID = 20, @MemberCodes = @MemberCodes  
  
*/  
CREATE PROCEDURE [mdm].[udpProcessCodes]  
(  
    @Entity_ID		INT,  
    @MemberCodes    mdm.MemberCodes READONLY  
)  
AS BEGIN  
  
    SET NOCOUNT ON;  
  
    DECLARE @TempMaxValue BIGINT = NULL,  
            @CodeGenSeed INT = NULL,  
            @CurrentLargestValue    BIGINT = NULL,  
            @CodeSetMaxValue BIGINT = NULL;  
  
    IF NOT EXISTS(SELECT * FROM mdm.tblCodeGenInfo WHERE EntityId = @Entity_ID)  
        BEGIN  
            RAISERROR('MDSERR310054|This entity does not support automatic code generation', 16, 1);  
            RETURN;  
        END  
  
    --Try and get the maximum numeric value out of the set of codes we were given  
    --We need to first cast the code as a decimal because otherwise we can not convert  
    --codes that contain decimals down to a bigint. If there are no numbers in the set  
    --of codes @CodeSetMaxValue should be NULL  
    SELECT @CodeSetMaxValue = CONVERT(BIGINT, MAX(CAST(MemberCode AS DECIMAL(38,8))))   
    FROM @MemberCodes   
    WHERE mdq.IsNumber(MemberCode) = 1;  
  
    IF @CodeSetMaxValue IS NOT NULL  
        BEGIN  
            --Update the largest code value for this entity to the code set's maximum value if:  
            --1. The existing largest code value is null and the seed is smaller than code set's maximum value  
            --2. The existing largest code value is larger than or equal to the seed but is smaller than the code set's maximum value  
            --3. The seed is larger than the existing largest code value but is smaller than the code set's maximum value  
            --  
            --The expression has been broken out on purpose to aid readability of the code  
            UPDATE mdm.tblCodeGenInfo  
            SET LargestCodeValue = CASE WHEN LargestCodeValue IS NULL AND @CodeSetMaxValue > Seed THEN @CodeSetMaxValue  
                                        WHEN LargestCodeValue >= Seed AND @CodeSetMaxValue > LargestCodeValue THEN @CodeSetMaxValue  
                                        WHEN Seed > LargestCodeValue AND @CodeSetMaxValue > Seed THEN @CodeSetMaxValue  
                                        ELSE LargestCodeValue  
                                        END  
            WHERE EntityId = @Entity_ID;  
        END  
  
END; --proc mdm.udpProcessCodes
GO
