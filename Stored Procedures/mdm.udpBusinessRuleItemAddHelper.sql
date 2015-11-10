SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Performs operations common to the BRItem Add and Update operations  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleItemAddHelper]  
(  
    @Rule_MUID                      UNIQUEIDENTIFIER = NULL,    
    @Item_ID                        INT = NULL, -- Leave null when adding    
    @AnchorAttribute_MUID           UNIQUEIDENTIFIER = NULL,    -- Either @AnchorAttribute_MUID or @AnchorAttributeName must be provided  
    @AnchorAttributeName            NVARCHAR(250) = NULL,      
    @RuleType                       INT = NULL,  
    @RuleSubType                    INT = NULL,  
    @ItemType_ID                    INT = NULL, -- tblBRItemType.ID (Operation)  
    @IsAction                       BIT = NULL, -- 0 = Condition, 1 = Action  
    @BRLogicalOperatorGroup_MUID    UNIQUEIDENTIFIER = NULL OUTPUT, /*input (optional for Action items) and output, */  
    @Rule_ID                        INT = NULL OUTPUT,  
    @BRLogicalOperatorGroup_ID      INT = NULL OUTPUT,  
    @BRItemAppliesTo_ID             INT = NULL OUTPUT,  
    @AnchorDataType                 NVARCHAR(50) = NULL OUTPUT,  
    @AnchorAttributeType            INT  = NULL OUTPUT,  
    @Failed                         BIT OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET @Failed = 1  
  
    -- get rule info  
    SET @Rule_ID = NULL  
    DECLARE @RuleEntity_ID INT SET @RuleEntity_ID = NULL      
    SELECT   
        @Rule_ID = ID,  
        @RuleEntity_ID = Foreign_ID  
    FROM mdm.tblBRBusinessRule   
    WHERE MUID = @Rule_MUID  
    IF (@Rule_ID IS NULL) BEGIN  
        RAISERROR('MDSERR400005|The business rule MUID is not valid.', 16, 1);  
        RETURN  
    END  
  
    -- get AnchorAttribute properties  
    DECLARE   
        @AnchorDataTypeID   INT,  
        @AnchorColumnName   NVARCHAR(128),  
        @AnchorEntityId     INT,  
        @AnchorMemberTypeId TINYINT,  
        @AnchorID           INT SET @AnchorID = NULL  
    SELECT   
        @AnchorID = Attribute_ID,  
        @AnchorColumnName = Attribute_Column,  
        @AnchorEntityId = Entity_ID,  
        @AnchorMemberTypeId = Attribute_MemberType_ID,  
        @AnchorDataTypeID = Attribute_DataType_ID,  
        @AnchorAttributeType = Attribute_Type_ID  
    FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES vAtt  
    WHERE  
        vAtt.Attribute_MUID = @AnchorAttribute_MUID OR  
            (vAtt.Attribute_Name = @AnchorAttributeName AND  
             vAtt.Entity_ID = @RuleEntity_ID)  
    IF (@AnchorID IS NULL) BEGIN  
        RAISERROR('MDSERR400003|The attribute reference is not valid. The attribute was not found.', 16, 1);  
        RETURN  
    END  
      
    -- Get the anchor attribute's SQL data type.  
    -- Note: this is not a part of the above query for perf reasons. Doing a join   
    -- between INFORMATION_SCHEMA.COLUMNS and viw_SYSTEM_SCHEMA_ATTRIBUTES is *extremely* slow.  
    SELECT   
        @AnchorDataType = sysCol.DATA_TYPE   
    FROM INFORMATION_SCHEMA.COLUMNS sysCol  
    WHERE  
        sysCol.COLUMN_NAME = @AnchorColumnName  
        AND sysCol.TABLE_NAME = mdm.udfTableNameGetByID(@AnchorEntityId, @AnchorMemberTypeId)  
      
    -- check compatibility between operation and anchor  
    IF (mdm.udfBusinessRuleIsItemTypeCompatible(@AnchorAttributeType, @AnchorDataTypeID, @ItemType_ID) <> 1) BEGIN  
        RAISERROR('MDSERR400004|The operation is not supported for the attribute type.', 16, 1);  
        RETURN  
    END   
  
    -- get @BRLogicalOperatorGroup_ID  
    IF (@BRLogicalOperatorGroup_MUID IS NOT NULL) BEGIN  
        SET @BRLogicalOperatorGroup_ID = (SELECT TOP 1 ID FROM mdm.tblBRLogicalOperatorGroup WHERE MUID = @BRLogicalOperatorGroup_MUID);  
    END  
    IF (@BRLogicalOperatorGroup_ID IS NULL AND @IsAction = 1) BEGIN  
        -- search for existing Action operator group row  
        SET @BRLogicalOperatorGroup_ID =   
            (SELECT TOP 1 logp.ID  
             FROM   
                mdm.tblBRLogicalOperatorGroup logp  
                INNER JOIN mdm.tblBRItem it   
                    ON logp.ID = it.BRLogicalOperatorGroup_ID AND  
                       logp.BusinessRule_ID = @Rule_ID AND  
                       logp.Parent_ID IS NULL AND -- no parent  
                       logp.LogicalOperator_ID = 1 --AND operator  
                INNER JOIN mdm.tblBRItemTypeAppliesTo itat ON it.BRItemAppliesTo_ID = itat.ID  
                INNER JOIN mdm.tblListRelationship lr   
                    ON itat.ApplyTo_ID = lr.ID AND  
                       lr.Parent_ID = 2 -- Action  
                ORDER BY logp.ID  
                    )  
        IF (@BRLogicalOperatorGroup_ID IS NULL) BEGIN  
            -- couldn't find existing row, so add one  
            INSERT INTO mdm.tblBRLogicalOperatorGroup(  
                LogicalOperator_ID,  
                BusinessRule_ID,  
                Sequence  
            )  
            VALUES (  
                1,-- 1 = AND Operator  
                @Rule_ID,  
                1                  
            )  
            SET @BRLogicalOperatorGroup_ID = SCOPE_IDENTITY();  
        END  
        SET @BRLogicalOperatorGroup_MUID = (SELECT MUID FROM mdm.tblBRLogicalOperatorGroup WHERE ID = @BRLogicalOperatorGroup_ID);  
    END   
    IF (@BRLogicalOperatorGroup_ID IS NULL) BEGIN  
        RAISERROR('MDSERR400006|The logical operator group MUID is not valid.', 16, 1);  
        RETURN  
    END  
  
    -- lookup @BRItemAppliesTo_ID   
  
    SET @BRItemAppliesTo_ID = mdm.udfBusinessRuleGetBRItemAppliesToID(@ItemType_ID, (SELECT CASE WHEN @IsAction = 1 THEN 2 ELSE 1 END), @RuleType, @RuleSubType)  
    IF (@BRItemAppliesTo_ID IS NULL) BEGIN  
        RAISERROR('MDSERR400007|The operation is not valid for the condition or action.', 16, 1);  
        RETURN  
    END  
  
    -- If the rule item is Workflow, ensure that no other items within the same rule are Workflow.  
    DECLARE @ItemType_Workflow INT = 32; -- From tblBRItemType.ID  
    IF (@ItemType_ID = @ItemType_Workflow AND  
        EXISTS(SELECT 1   
               FROM mdm.tblBRItem i   
               LEFT JOIN mdm.tblBRItemTypeAppliesTo itat  
               ON i.BRItemAppliesTo_ID = itat.ID   
               WHERE  
                    i.BRLogicalOperatorGroup_ID = @BRLogicalOperatorGroup_ID AND -- All actions within the same rule will share the same logical operator group.  
                    itat.BRItemType_ID = @ItemType_Workflow AND                      
                    (@Item_ID IS NULL OR i.ID <> @Item_ID))  
        )   
    BEGIN  
        RAISERROR('MDSERR400041|A rule cannot contain more than one Workflow action.', 16, 1);  
        RETURN;  
    END;  
  
  
    SET @Failed = 0  
END --proc
GO
