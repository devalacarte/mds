SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleItemAdd]  
(  
    @BRLogicalOperatorGroup_MUID    UNIQUEIDENTIFIER = NULL OUTPUT,    -- required for Conditions, optional for Actions (will be found/created if not provided)  
    @Rule_MUID                      UNIQUEIDENTIFIER = NULL,      
    @RuleType                       INT = NULL,  
    @RuleSubType                    INT = NULL,  
    @ItemType_ID                    INT = NULL, -- tblBRItemType.ID (Operation)  
    @IsAction                       BIT = NULL, -- 0 = Condition, 1 = Action  
    @AnchorName                     NVARCHAR(250),  
    @AnchorAttribute_MUID           UNIQUEIDENTIFIER = NULL,    -- required  
    @Sequence                       INT = NULL,  
    @ItemText                       NVARCHAR(MAX) = NULL,  
    @ItemSQL                        NVARCHAR(MAX) = NULL,  
    @ArgumentMuids                  XML = NULL, -- must contain Muids of all tblBRItemProperties rows belonging to the BRItem  
    @MUID                           UNIQUEIDENTIFIER = NULL OUTPUT, -- Input (Clone only) and output  
    @ID                             INT = NULL OUTPUT -- Output only  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    SET @ID = 0;  
    -- check to see if a MUID of an existing row was given  
    IF (@MUID IS NOT NULL AND (SELECT COUNT(*) FROM mdm.tblBRItem WHERE MUID = @MUID) > 0) BEGIN  
  
        -- call update  
        EXEC mdm.udpBusinessRuleItemUpdate  
            @BRLogicalOperatorGroup_MUID OUTPUT,      
            @Rule_MUID,      
            @RuleType,  
            @RuleSubType,  
            @ItemType_ID,  
            @IsAction,  
            @AnchorName,  
            @AnchorAttribute_MUID,  
            @Sequence,  
            @ItemText,  
            @ItemSQL,  
            @ArgumentMuids,  
            @MUID OUTPUT,  
            @ID OUTPUT  
  
    END ELSE BEGIN  
  
        -- get item properties  
        DECLARE   
            @Rule_ID                    INT,  
            @BRLogicalOperatorGroup_ID  INT,  
            @BRItemAppliesTo_ID         INT,  
            @AnchorDataType             NVARCHAR(50),  
            @AnchorAttributeType        INT,  
            @Failed                     BIT;  
        EXEC mdm.udpBusinessRuleItemAddHelper  
            @Rule_MUID,  
            NULL,   
            @AnchorAttribute_MUID,   
            @AnchorName,  
            @RuleType,  
            @RuleSubType,  
            @ItemType_ID,  
            @IsAction,  
            @BRLogicalOperatorGroup_MUID OUTPUT,  
            @Rule_ID OUTPUT,  
            @BRLogicalOperatorGroup_ID OUTPUT,  
            @BRItemAppliesTo_ID OUTPUT,  
            @AnchorDataType OUTPUT,  
            @AnchorAttributeType OUTPUT,  
            @Failed OUTPUT;  
          
        -- check for errors  
        IF (@Failed = 1) BEGIN  
            SET @MUID = NULL;  
            RETURN  
        END  
  
        SET @MUID = ISNULL(@MUID, NEWID());  
  
        -- add row  
        INSERT INTO mdm.tblBRItem(  
            MUID,  
            BRLogicalOperatorGroup_ID,   
            BRItemAppliesTo_ID,   
            [Sequence],   
            ItemText,  
            ItemSQL,  
            AnchorName,  
            AnchorDataType,  
            AnchorAttributeType  
        ) VALUES (  
            @MUID,  
            @BRLogicalOperatorGroup_ID,  
            @BRItemAppliesTo_ID,  
            @Sequence,  
            @ItemText,  
            @ItemSQL,  
            @AnchorName,  
            @AnchorDataType,  
            @AnchorAttributeType  
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
