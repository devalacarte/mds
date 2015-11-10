SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleLogicalOperatorGroupDelete]  
(  
    @LogicalOperatorMUID   UNIQUEIDENTIFIER = NULL,  
    @RuleMUID   UNIQUEIDENTIFIER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    SET @RuleMUID = NULL  
  
    -- find the item ID  
    DECLARE @LogicalOperatorID INT  
    DECLARE @RuleID INT  
    SELECT   
        @LogicalOperatorID = ID,   
        @RuleID = BusinessRule_ID  
    FROM mdm.tblBRLogicalOperatorGroup   
    WHERE MUID = @LogicalOperatorMUID  
  
    IF @LogicalOperatorID IS NULL BEGIN  
        RAISERROR('MDSERR400006|The logical operator group MUID is not valid.', 16, 1);  
    END ELSE BEGIN   
        -- set the rule muid  
        SET @RuleMUID = (SELECT MUID FROM mdm.tblBRBusinessRule WHERE ID = @RuleID)  
          
        -- delete all child rule items and their properties  
        DECLARE @ChildMuids TABLE (MUID UNIQUEIDENTIFIER PRIMARY KEY)  
        INSERT INTO @ChildMuids  
            SELECT MUID FROM mdm.tblBRItem WHERE BRLogicalOperatorGroup_ID = @LogicalOperatorID;  
        DECLARE @ChildMuid UNIQUEIDENTIFIER SET @ChildMuid = (SELECT TOP 1 MUID FROM @ChildMuids);  
        WHILE @ChildMuid IS NOT NULL BEGIN  
            EXEC mdm.udpBusinessRuleItemDelete @ChildMuid  
            DELETE FROM @ChildMuids WHERE MUID = @ChildMuid  
            SET @ChildMuid = (SELECT TOP 1 MUID FROM @ChildMuids);  
        END  
  
        -- delete all child logical operator groups  
        INSERT INTO @ChildMuids  
            SELECT MUID FROM mdm.tblBRLogicalOperatorGroup WHERE ISNULL(Parent_ID, 0) = @LogicalOperatorID;  
        SET @ChildMuid = (SELECT TOP 1 MUID FROM @ChildMuids);  
        WHILE @ChildMuid IS NOT NULL BEGIN  
            EXEC mdm.udpBusinessRuleLogicalOperatorGroupDelete @ChildMuid  
            DELETE FROM @ChildMuids WHERE MUID = @ChildMuid  
            SET @ChildMuid = (SELECT TOP 1 MUID FROM @ChildMuids);  
        END  
         
        -- delete the logical operator group  
        DELETE FROM mdm.tblBRLogicalOperatorGroup WHERE ID = @LogicalOperatorID  
    END  
  
    SET NOCOUNT OFF  
END --proc
GO
