SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleItemPropertyAdd]  
(  
    @BRItem_ID              INT = NULL,  
	@PropertyType_ID 	    INT = NULL,  
	@PropertyName_ID 	    INT = NULL,  
	@Value 				    NVARCHAR(999) = NULL, -- possible values: freeform/blank string, Attribute muid, Hierarchy muid, or AttributeValue code  
    @AttributeName          NVARCHAR(128) = NULL,   
	@Sequence 			    INT = NULL,  
	@IsLeftHandSide 	    BIT = NULL,  
	@Parent_ID			    INT = NULL,  
	@SuppressText		    BIT = NULL,  
    @MUID                   UNIQUEIDENTIFIER = NULL OUTPUT, /*Input (Clone only) and output*/  
    @ID                     INT = NULL OUTPUT /*Output only*/  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    -- sanitize parameters  
    IF @Parent_ID <= 0 BEGIN SET @Parent_ID = NULL END  
    IF @BRItem_ID <= 0 BEGIN SET @BRItem_ID = NULL END  
    SET @ID = 0;  
      
    -- check to see if a MUID of an existing row was given  
    IF (@MUID IS NOT NULL AND (SELECT COUNT(*) FROM mdm.tblBRItemProperties WHERE MUID = @MUID) > 0) BEGIN  
        -- call update  
	    EXEC mdm.udpBusinessRuleItemPropertyUpdate   
            @BRItem_ID,   
            @PropertyType_ID,   
            @PropertyName_ID,   
            @Value,  
            @AttributeName,   
            @Sequence,   
            @IsLeftHandSide,   
            @Parent_ID,  
            @SuppressText,  
            @MUID OUTPUT,   
            @ID OUTPUT;  
    END ELSE BEGIN  
  
        -- get value  
        DECLARE @Failed BIT SET @Failed = 0  
        EXEC mdm.udpBusinessRuleItemPropertyAddHelper @BRItem_ID, @PropertyType_ID, @AttributeName, @Value OUTPUT, @Failed OUTPUT  
        IF @Failed = 1 BEGIN  
            RETURN   
        END  
  
        SET @MUID = ISNULL(@MUID, NEWID());  
  
        -- add row  
        INSERT INTO mdm.tblBRItemProperties(  
            MUID,  
	        BRItem_ID,   
	        PropertyType_ID,   
	        PropertyName_ID,  
	        [Value],   
	        Sequence,   
	        IsLeftHandSide,   
	        Parent_ID,  
            SuppressText  
        ) VALUES (  
            @MUID,  
	        @BRItem_ID,   
	        @PropertyType_ID,   
	        @PropertyName_ID,  
	        @Value,   
	        @Sequence,   
	        @IsLeftHandSide,   
	        @Parent_ID,  
            @SuppressText  
        );  
  
        -- set output params  
        IF @@ERROR = 0 BEGIN  
            SET @ID = SCOPE_IDENTITY();  
        END ELSE BEGIN  
            SET @MUID = NULL;-- ensure MUID is set back to NULL if there was an error  
        END  
    END  
  
    SET NOCOUNT OFF  
END --proc
GO
