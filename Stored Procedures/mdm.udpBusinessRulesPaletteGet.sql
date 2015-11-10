SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Returns the data for the business rules palette  
  
exec mdm.udpBusinessRulesPaletteGet 1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRulesPaletteGet]  
(  
    @BRSubType_ID   INT = NULL  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    -- create vars corresponding to tblListRelationshipType.ID values  
    DECLARE @BRType INT SET @BRType = 1  
    DECLARE @BRItemTypeCategory INT SET @BRItemTypeCategory = 2  
    DECLARE @DataType INT SET @DataType = 3  
  
    -- Level 2 nodes, i.e. "Value Comparison", "Default value", "Change value", "Validation"  
    SELECT      
        c.OptionID AS Id,  
        CONVERT(BIT, p.OptionID - 1) AS IsAction,  
        c.ListOption AS [Name]  
    FROM      
        mdm.tblListRelationship lr   
        INNER JOIN  
        mdm.tblList c   
            ON   
                lr.ListRelationshipType_ID = @BRItemTypeCategory AND  
                lr.Child_ID = c.OptionID AND   
                lr.ChildListCode = c.ListCode AND   
                c.IsVisible = 1   
        INNER JOIN  
        mdm.tblList p   
            ON   
                lr.Parent_ID = p.OptionID AND   
                lr.ParentListCode = p.ListCode   
    ORDER BY p.Seq, c.Seq  
  
    -- Rule item types (level 3 nodes)  
    SELECT       
        ssbi.BRItemType_ID  Id,  
        ssbi.BRSubTypeID    ParentId  
    FROM    mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES ssbi  
    WHERE      
        ssbi.ApplyToCategoryID = @BRItemTypeCategory AND  
        ssbi.BRSubTypeIsVisible = 1 AND  
        EXISTS   
        (  
            SELECT    BRItemType_ID   
            FROM    mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES   
            WHERE      
                ApplyToCategoryID = @BRType AND  
                BRSubTypeID = @BRSubType_ID AND  
                BRItemType_ID = ssbi.BRItemType_ID  
        )  
    ORDER BY   
        DisplaySequence,   
        DisplaySubSequence  
  
    -- Compatible attribute types  
    SELECT   
        itat.BRItemType_ID  BRItemType,  
        lr.Parent_ID        AttributeType,  
        lr.Child_ID         AttributeDataType  
    FROM      
        mdm.tblBRItemTypeAppliesTo itat   
        INNER JOIN  
        mdm.tblListRelationship lr   
        ON   
            lr.ListRelationshipType_ID = @DataType AND  
            itat.ApplyTo_ID = lr.ID  
    ORDER BY   
        itat.BRItemType_ID,   
        lr.Parent_ID,   
        lr.Child_ID  
  
    SET NOCOUNT OFF  
END --proc
GO
