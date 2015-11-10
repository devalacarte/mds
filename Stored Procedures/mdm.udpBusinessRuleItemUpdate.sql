SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleItemUpdate]  
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
    @MUID                           UNIQUEIDENTIFIER = NULL OUTPUT, -- Input (Clone or Update) and output  
    @ID                             INT = NULL OUTPUT -- Output only  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    -- find the item ID  
    SET @ID = 0;  
    IF (@MUID IS NOT NULL)   
    BEGIN  
        SELECT @ID = ID  
        FROM mdm.tblBRItem   
        WHERE MUID = @MUID  
    END  
  
    IF (@ID = 0)   
    BEGIN  
        SET @MUID = NULL;  
        RAISERROR('MDSERR400001|The Update operation failed. The MUID was not found.', 16, 1);  
        RETURN;  
    END     
      
    -- delete unused arguments  
    DELETE FROM mdm.tblBRItemProperties  
    WHERE   
        BRItem_ID = @ID AND  
        MUID NOT IN (SELECT   
            DISTINCT am.MUID.value(N'.',N'UNIQUEIDENTIFIER') MUID   
            FROM @ArgumentMuids.nodes(N'//guid') am(MUID))  
          
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
        @ID,  
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
    IF (@Failed = 1)   
    BEGIN  
        SET @MUID = NULL;  
        SET @ID = 0;  
        RETURN  
    END  
  
    -- update row  
    UPDATE mdm.tblBRItem  
    SET  
        BRLogicalOperatorGroup_ID = @BRLogicalOperatorGroup_ID,   
        BRItemAppliesTo_ID = @BRItemAppliesTo_ID,   
        [Sequence] = @Sequence,  
        ItemText = @ItemText,   
        ItemSQL = @ItemSQL,   
        AnchorName = @AnchorName,   
        AnchorDataType = @AnchorDataType,  
        AnchorAttributeType = @AnchorAttributeType  
    WHERE  
        MUID = @MUID  
  
    -- set output params  
    IF @@ERROR <> 0   
    BEGIN  
        SET @MUID = NULL;  
        SET @ID = 0;  
    END  
  
    SET NOCOUNT OFF  
END --proc
GO
