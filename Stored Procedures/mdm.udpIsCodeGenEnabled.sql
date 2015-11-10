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
    DECLARE @IsCodeGenEnabled BIT;  
    EXEC @IsCodeGenEnabled = mdm.udpIsCodeGenEnabled @Entity_ID = 20;  
*/  
CREATE PROCEDURE [mdm].[udpIsCodeGenEnabled]  
(  
    @Entity_ID		INT  
)  
AS BEGIN  
  
    SET NOCOUNT ON;  
  
    DECLARE @IsCodeGenEnabled BIT = 0;  
  
    IF EXISTS(SELECT * FROM mdm.tblCodeGenInfo WHERE EntityId = @Entity_ID)  
        BEGIN  
            SET @IsCodeGenEnabled = 1;  
        END  
  
    -- Return the result of the SPROC  
    RETURN @IsCodeGenEnabled;  
  
END; --proc mdm.udpIsCodeGenEnabled
GO
