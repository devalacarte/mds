SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleItemPropertyUpdate]  
(  
    @BRItem_ID              INT = NULL,  
	@PropertyType_ID 	    INT = NULL,  
	@PropertyName_ID 	    INT = NULL,  
	@Value 				    NVARCHAR(999) = NULL, -- possible values: freeform/blank string, Attribute muid, Hierarchy muid, or AttributeValue code  
    @AttributeName          NVARCHAR(128) = NULL, -- optional  
	@Sequence 			    INT = NULL,  
	@IsLeftHandSide 	    BIT = NULL,  
	@Parent_ID			    INT = NULL,  
	@SuppressText		    BIT = NULL,  
    @MUID                   UNIQUEIDENTIFIER = NULL OUTPUT, /*Input and output*/  
    @ID                     INT = NULL OUTPUT /*Output only*/  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    -- sanitize parameters  
    IF @Parent_ID <= 0 BEGIN SET @Parent_ID = NULL END  
    IF @BRItem_ID <= 0 BEGIN SET @BRItem_ID = NULL END  
    SET @ID = 0;  
      
    -- check to made sure a MUID of an existing row was given  
    IF (@MUID IS NULL OR (SELECT COUNT(*) FROM mdm.tblBRItemProperties WHERE MUID = @MUID) = 0) BEGIN  
        SET @MUID = NULL;  
	    RAISERROR('MDSERR400001|The Update operation failed. The MUID was not found.', 16, 1);  
        RETURN;  
    END               
  
    -- get value  
    DECLARE @Failed BIT SET @Failed = 0  
    EXEC mdm.udpBusinessRuleItemPropertyAddHelper @BRItem_ID, @PropertyType_ID, @AttributeName, @Value OUTPUT, @Failed OUTPUT  
    IF @Failed = 1 BEGIN  
        RETURN   
    END  
  
    -- update row  
    UPDATE mdm.tblBRItemProperties  
    SET  
        BRItem_ID = @BRItem_ID,   
        PropertyType_ID = @PropertyType_ID,   
        PropertyName_ID = @PropertyName_ID,  
        [Value] = @Value,   
        Sequence = @Sequence,   
        IsLeftHandSide = @IsLeftHandSide,   
        Parent_ID = @Parent_ID,  
        SuppressText = @SuppressText  
    WHERE  
        MUID = @MUID  
  
    -- set output params  
    IF @@ERROR = 0 BEGIN  
        SET @ID = (SELECT ID FROM mdm.tblBRItemProperties WHERE MUID = @MUID)  
    END ELSE BEGIN  
        SET @MUID = NULL;  
    END  
  
    SET NOCOUNT OFF  
END --proc
GO
