SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpValidateMembers]  
(  
	@User_ID INT,   
	@Version_ID INT,  
    @Entity_ID INT,  
	@MemberIdList mdm.IdList READONLY,   
	@MemberType_ID INT,  
	@ProcessUIRulesOnly BIT = 0  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	/*  
	Business Rule Process options.  Any combination can be present.  
	Bits              876543210  
	===================================  
    Default         = 000000001 =  1  
    ChangeValue     = 000000010 =  2  
    Assignment      = 000000011 =  3  
    Validation      = 000000100 =  4  
    UI              = 000001000 =  8  
    ExternalAction  = 000010000 =  16  
    Logging         = 010000000 =  128  
	*/  
	DECLARE @ProcessOptions	              INT;  
    DECLARE @ProcessOptionDefault         INT = 1;  
    DECLARE @ProcessOptionChangeValue     INT = 2;  
    DECLARE @ProcessOptionAssignments     INT = @ProcessOptionDefault | @ProcessOptionChangeValue;  
    DECLARE @ProcessOptionValidation      INT = 4;  
    DECLARE @ProcessOptionUI              INT = 8;  
    DECLARE @ProcessOptionExternalAction  INT = 16;  
    DECLARE @ProcessOptionLogging         INT = 128;  
  
	IF @ProcessUIRulesOnly = 1  
        SET @ProcessOptions = @ProcessOptionUI;  
    ELSE  
		SET @ProcessOptions = @ProcessOptionAssignments | @ProcessOptionValidation | @ProcessOptionLogging | @ProcessOptionExternalAction;  
          
	--Call the Business Rules Controller to process rules for the member(s)  
	EXEC mdm.udpBusinessRule_AttributeMemberController @User_ID,@Version_ID, @Entity_ID, @MemberIdList, @MemberType_ID, @ProcessOptions  
  
	SET NOCOUNT OFF  
END --proc
GO
