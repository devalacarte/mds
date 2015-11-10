SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleItemDelete]  
(  
    @RuleItemMUID   UNIQUEIDENTIFIER = NULL,  
    @RuleMUID   UNIQUEIDENTIFIER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    SET @RuleMUID = NULL  
  
    -- find the item ID  
    DECLARE @ItemID INT SET @ItemID = (SELECT ID FROM mdm.tblBRItem WHERE MUID = @RuleItemMUID)  
  
    IF @ItemID IS NULL BEGIN  
        RAISERROR('MDSERR400027|The rule item MUID is not valid.', 16, 1);  
    END ELSE BEGIN   
        DECLARE @LogicalOperatorGroupId INT  
        DECLARE @LogicalOperatorGroupMUID UNIQUEIDENTIFIER  
  
        DECLARE @ItemType INT -- condition or action  
        DECLARE @ActionTypeId INT SET @ActionTypeId = 2  
  
        -- set the rule MUID  
        SELECT   
            @RuleMUID = b.MUID,  
            @LogicalOperatorGroupId = lg.ID,  
            @LogicalOperatorGroupMUID = lg.MUID,  
            @ItemType = lr.Parent_ID  
        FROM   
            mdm.tblBRItem it  
            INNER JOIN   
            mdm.tblBRLogicalOperatorGroup lg  
                ON   
                    it.ID = @ItemID AND  
                    it.BRLogicalOperatorGroup_ID = lg.ID  
            INNER JOIN  
            mdm.tblBRBusinessRule b  
                ON lg.BusinessRule_ID = b.ID  
            LEFT JOIN   
            mdm.tblBRItemTypeAppliesTo itat  
                ON it.BRItemAppliesTo_ID = itat.ID  
            LEFT JOIN  
            mdm.tblListRelationship lr  
                ON itat.ApplyTo_ID = lr.ID  
  
        -- delete all item properties  
        DELETE FROM mdm.tblBRItemProperties WHERE BRItem_ID = @ItemID  
          
        -- delete the item  
        DELETE FROM mdm.tblBRItem WHERE ID = @ItemID  
  
        -- delete the owning logical operator group *if* the deleted BRItem was the rule's last Action item  
        IF @ItemType = @ActionTypeId AND 0 = (SELECT COUNT(*) FROM mdm.tblBRItem WHERE BRLogicalOperatorGroup_ID = @LogicalOperatorGroupId) BEGIN  
            EXEC mdm.udpBusinessRuleLogicalOperatorGroupDelete @LogicalOperatorGroupMUID, @RuleMUID OUTPUT  
        END  
    END  
  
    SET NOCOUNT OFF  
END --proc
GO
