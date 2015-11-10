SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleLogicalOperatorGroupUpdate]  
(  
    @Rule_MUID              UNIQUEIDENTIFIER = NULL,   
    @LogicalOperator_ID     INT = NULL, /* 1= AND, 2 = OR */  
    @Parent_MUID            UNIQUEIDENTIFIER = NULL,  
	@Sequence 			    INT = NULL,  
    @MUID                   UNIQUEIDENTIFIER = NULL OUTPUT, /*Input (Clone only) and output*/  
    @ID                     INT = NULL OUTPUT /*Output only*/  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    SET @ID = 0;  
      
    -- check to made sure a MUID of an existing row was given  
    IF (@MUID IS NULL OR (SELECT COUNT(*) FROM mdm.tblBRLogicalOperatorGroup WHERE MUID = @MUID) = 0) BEGIN  
        SET @MUID = NULL;  
	    RAISERROR('MDSERR400001|The Update operation failed. The MUID was not found.', 16, 1);  
        RETURN;  
    END               
   
    -- get business rule ID  
    DECLARE @BusinessRule_ID INT   
    SET @BusinessRule_ID = (SELECT ID FROM mdm.tblBRBusinessRule WHERE MUID = @Rule_MUID);  
    IF @BusinessRule_ID IS NULL BEGIN  
        SET @MUID = NULL;  
        RAISERROR('MDSERR400005|The business rule MUID is not valid.', 16, 1);  
        RETURN;  
    END  
  
    -- get parent ID  
    DECLARE @Parent_ID INT  
    IF @Parent_MUID IS NOT NULL BEGIN  
        SET @Parent_ID = (SELECT ID FROM mdm.tblBRLogicalOperatorGroup WHERE MUID = @Parent_MUID)  
        IF @Parent_ID IS NULL BEGIN  
            SET @MUID = NULL;  
            RAISERROR('MDSERR400020|The MUID for the parent tree node is not valid.', 16, 1);  
            RETURN;  
        END  
    END  
  
    -- update row  
    UPDATE mdm.tblBRLogicalOperatorGroup  
    SET  
        LogicalOperator_ID = @LogicalOperator_ID,   
        Parent_ID = @Parent_ID,  
        BusinessRule_ID = @BusinessRule_ID,  
        Sequence = @Sequence  
    WHERE  
        MUID = @MUID  
  
    -- set output params  
    IF @@ERROR = 0 BEGIN  
        SET @ID = (SELECT ID FROM mdm.tblBRItem WHERE MUID = @MUID)  
    END ELSE BEGIN  
        SET @MUID = NULL;  
    END  
  
    SET NOCOUNT OFF  
END --proc
GO
