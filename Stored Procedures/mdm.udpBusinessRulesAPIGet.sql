SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Returns business rule information using the given criteria. If no  
criteria is specified, then info for all rules is returned. For example:  
  
    exec mdm.udpBusinessRulesAPIGet  
        @UserId=1,   
        @AttributeMuid=NULL,  
        @AttributeName=NULL,  
        @EntityMuid=NULL,  
        @EntityName=NULL,  
        @ModelMuid=NULL,  
        @ModelName=NULL,  
        @BusinessRuleIdentifiers=NULL,  
        @MemberType=NULL,  
        @ActionResultType=0,  
        @ConditionResultType=0,  
        @ConditionTreeNodeResultType=0,  
        @BusinessRulesResultType=2  
  
Returned tables:  
    BR_IDs  
    AuditInfo  
    BusinessRules  
    Actions  
    Conditions  
    ConditionTreeNodes  
    Arguments      
*/  
CREATE PROCEDURE [mdm].[udpBusinessRulesAPIGet]  
(  
    @UserId INT,  
    @AttributeMuid UNIQUEIDENTIFIER = NULL,  
    @AttributeName NVARCHAR(128) = NULL,  
    @EntityMuid UNIQUEIDENTIFIER = NULL,  
    @EntityName NVARCHAR(50) = NULL,  
    @ModelMuid UNIQUEIDENTIFIER = NULL,  
    @ModelName NVARCHAR(50) = NULL,  
    @BusinessRuleIdentifiers XML = NULL,  
    @MemberType INT = NULL, /*1 = Leaf, 2 = Consolidated */  
    @ActionResultType INT = 0, /*0 = None, 1 = Identifiers, 2 = Details */  
    @ConditionResultType INT = 0,   
    @ConditionTreeNodeResultType INT = 0,  
    @BusinessRulesResultType INT = 0                   
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON    
    
    DECLARE @EmptyMuid UNIQUEIDENTIFIER SET @EmptyMuid = CONVERT(UNIQUEIDENTIFIER, 0x0);    
    -- lookup ModelMuid, if necessary    
    IF (@ModelMuid IS NULL OR 0 = (SELECT COUNT(*) FROM mdm.tblModel WHERE MUID = @ModelMuid)) AND LEN(@ModelName) > 0 BEGIN    
        SET @ModelMuid = COALESCE((SELECT TOP 1 MUID FROM mdm.tblModel WHERE [Name] = @ModelName ORDER BY MUID), @EmptyMuid/*set to emtpy muid if name lookup fails*/);    
    END    
    
    -- lookup EntityMuid, if necessary    
    IF (@EntityMuid IS NULL OR 0 = (SELECT COUNT(*) FROM mdm.tblEntity WHERE MUID = @EntityMuid))     
        AND LEN(@EntityName) > 0 AND @ModelMuid IS NOT NULL BEGIN    
        SET @EntityMuid = COALESCE((SELECT TOP 1 MUID FROM mdm.viw_SYSTEM_SCHEMA_ENTITY WHERE [Name] = @EntityName AND Model_MUID = @ModelMuid ORDER BY MUID), @EmptyMuid/*set to emtpy muid if name lookup fails*/);    
    END    
    
    -- lookup AttributeMuid, if necessary    
    IF (@AttributeMuid IS NULL OR 0 = (SELECT COUNT(*) FROM mdm.tblAttribute WHERE MUID = @AttributeMuid))     
        AND LEN(@AttributeName) > 0 AND @EntityMuid IS NOT NULL BEGIN    
        SET @AttributeMuid = COALESCE(  
                (SELECT TOP 1 Attribute_MUID   
                 FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES   
                 WHERE Attribute_Name = @AttributeName AND Entity_MUID = @EntityMuid     
                 ORDER BY (CASE WHEN Attribute_MemberType_ID = @MemberType THEN 0 ELSE 1 END))  
             , @EmptyMuid/*set to emtpy muid if name lookup fails*/);      
    END    
    
    DECLARE @ConditionId INT SET @ConditionId = 1;    
    DECLARE @ActionId INT SET @ActionId = 2;    
    
    -- result type values    
    DECLARE @Details INT SET @Details = 2;    
    DECLARE @IdentifiersOnly INT SET @IdentifiersOnly = 1;    
    DECLARE @None INT SET @None = 0;    
    
    -- Use the criteria vars to find the Ids of matching business rule(s).    
    -- Place these Ids in a table var for use in subsequent queries.     
    DECLARE @BR_Ids TABLE (    
        Id INT PRIMARY KEY,     
        Muid UNIQUEIDENTIFIER UNIQUE,    
        [Name] NVARCHAR(100),    
        ModelId INT,     
        ModelMuid UNIQUEIDENTIFIER,    
        ModelName NVARCHAR(50),    
        EntityId INT,     
        EntityMuid UNIQUEIDENTIFIER,    
        EntityName NVARCHAR(50),    
        MemberType INT    
        );    
    INSERT INTO @BR_Ids    
    SELECT    
        DISTINCT     
        b.BusinessRule_ID Id,    
        b.BusinessRule_MUID Muid,        
        b.BusinessRule_Name [Name],    
        COALESCE(b.Model_ID, 0) ModelId,    
        b.Model_MUID ModelMuid,    
        b.Model_Name ModelName,    
        COALESCE(b.Entity_ID, 0) EntityId,    
        b.Entity_MUID EntityMuid,    
        b.Entity_Name EntityName,    
        COALESCE(b.BusinessRule_SubTypeID, 0) MemberType    
    FROM     
        mdm.udfSecurityUserModelList(@UserId) acl    
    INNER JOIN    
        mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES b     
        ON acl.ID = b.Model_ID    
        AND    
        (@EntityMuid IS NULL OR b.Entity_MUID = @EntityMuid)    
        AND (@ModelMuid IS NULL OR b.Model_MUID = @ModelMuid)               
        AND (@MemberType IS NULL OR b.BusinessRule_SubTypeID = @MemberType)    
    IF @AttributeMuid IS NOT NULL BEGIN    
        -- remove rules that don't have arguments referencing the given attribute MUID    
        DELETE FROM     
            @BR_Ids     
        WHERE     
            Id NOT IN     
                (SELECT DISTINCT BusinessRule_ID     
                 FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES    
                 WHERE Attribute_MUID = @AttributeMuid)    
    END    
    IF @BusinessRuleIdentifiers IS NOT NULL BEGIN    
        -- remove rules that were not in the given list of rule MUIDs    
        DELETE FROM     
            @BR_Ids     
        WHERE     
            Muid NOT IN     
            (SELECT br.Muid     
             FROM     
                @BR_Ids br            
                INNER JOIN     
                mdm.udfMetadataGetSearchCriteriaIds(@BusinessRuleIdentifiers) crit    
                ON     
                    (crit.MUID IS NOT NULL OR crit.Name IS NOT NULL) AND    
                    ISNULL(crit.MUID, br.Muid) = br.Muid AND    
                    ISNULL(crit.Name, br.Name) = br.Name)    
    END     
    
    -- BR Id info    
    SELECT Id ,     
        Muid ,    
        [Name] ,    
        ModelId ,     
        ModelMuid ,    
        ModelName ,    
        EntityId ,     
        EntityMuid ,    
        EntityName ,    
        MemberType     
        FROM @BR_Ids     
    
    -- BR Audit Info    
    IF @Details IN (@BusinessRulesResultType, @ActionResultType, @ConditionTreeNodeResultType, @ConditionResultType) BEGIN    
        -- Details    
        SELECT    
            DISTINCT    
            b.BusinessRule_ID RuleId,    
            COALESCE(b.BusinessRule_CreatedUserID, 0) CreatedUserId,    
            b.BusinessRule_CreatedUserMUID CreatedUserMuid,     
            b.BusinessRule_CreatedUserName CreatedUserName,    
            b.BusinessRule_DateCreated CreatedDateTime,    
            COALESCE(b.BusinessRule_UpdatedUserID, 0) UpdatedUserId,    
            b.BusinessRule_UpdatedUserMUID UpdatedUserMuid,     
            b.BusinessRule_UpdatedUserName UpdatedUserName,    
            b.BusinessRule_DateUpdated UpdatedDateTime    
        FROM    
            @BR_Ids i     
            INNER JOIN     
            mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES b     
                ON i.Id = b.BusinessRule_ID    
    END ELSE BEGIN     
        -- IDs Only or None    
        SELECT NULL WHERE 1=0;    
    END    
    
    -- BusinessRules    
    IF @BusinessRulesResultType = @Details BEGIN     
        -- Details    
        SELECT     
            DISTINCT    
            b.BusinessRule_ID Id,    
            b.BusinessRule_Description [Description],    
            b.BusinessRule_RuleActionText RuleActionText,    
            b.BusinessRule_RuleConditionText RuleConditionText,    
            b.BusinessRule_RuleConditionSql RuleConditionSql,    
            COALESCE(b.BusinessRule_StatusID, 0) [Status],    
            COALESCE(b.BusinessRule_Priority, 0) Priority,    
            b.BusinessRule_NotificationGroupMUID NotificationGroup,    
            b.BusinessRule_NotificationUserMUID NotificationUser    
        FROM    
            @BR_Ids i     
            INNER JOIN     
            mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES b     
                ON i.Id = b.BusinessRule_ID    
    END ELSE IF @BusinessRulesResultType = @IdentifiersOnly BEGIN     
        -- IDs only     
        SELECT i.Id    
        FROM @BR_Ids i     
    END ELSE BEGIN    
        -- Nothing    
        SELECT NULL WHERE 1=0;    
    END    
        
    -- Load BRItems (Actions and Conditions) into a table var    
    DECLARE @BR_Items TABLE     
    (    
        Id INT,     
        Muid UNIQUEIDENTIFIER,    
        [Text] NVARCHAR(2000),    
        [Sql] NVARCHAR(2000),    
        RuleId INT,    
        ItemTypeId INT,    
        Sequence INT,    
        [Type] INT,    
        LogicalOperatorGroupId INT,    
        LogicalOperatorGroupMuid UNIQUEIDENTIFIER,  
        AnchorAttributeDataType INT    
    );    
    IF  @None <> @BusinessRulesResultType OR    
        @None <> @ActionResultType OR             
        @None <> @ConditionResultType OR    
        @None <> @ConditionTreeNodeResultType    
    BEGIN    
        INSERT INTO @BR_Items    
        SELECT    
            DISTINCT    
            it.ID Id,    
            it.MUID Muid,    
            it.ItemText [Text],    
            it.ItemSQL [Sql],    
            lo.BusinessRule_ID RuleId,    
            itat.BRItemType_ID ItemTypeId, -- operator    
            it.Sequence Sequence,    
            lr.Parent_ID [Type], -- 1 = Condition, 2 = Action                 
            lo.ID LogicalOperatorGroupId,    
            lo.MUID LogicalOperatorGroupMuid,    
            anchorAttribute.DataType_ID AnchorAttributeDataType    
        FROM     
            @BR_Ids i     
            INNER JOIN mdm.tblBRLogicalOperatorGroup lo    
                ON i.Id = lo.BusinessRule_ID    
            INNER JOIN mdm.tblBRItem it    
                ON lo.ID = it.BRLogicalOperatorGroup_ID     
            INNER JOIN mdm.tblBRItemTypeAppliesTo itat    
                ON it.BRItemAppliesTo_ID = itat.ID    
            INNER JOIN mdm.tblListRelationship lr    
                ON itat.ApplyTo_ID = lr.ID AND    
                   lr.Parent_ID IN (@ActionId, @ConditionId)    
            LEFT JOIN mdm.tblBRItemProperties anchorArg      
                ON anchorArg.BRItem_ID = it.ID AND    
                   anchorArg.IsLeftHandSide = 1 AND     
                   anchorArg.PropertyType_ID = 2 -- 2 = Attribute     
            LEFT JOIN mdm.tblAttribute anchorAttribute    
                ON anchorArg.Value = CAST(anchorAttribute.ID as NVARCHAR)    
   
        ORDER BY lo.ID, it.Sequence    
    END     
    
    -- Actions    
    IF @Details IN (@BusinessRulesResultType, @ActionResultType) BEGIN     
        -- Details    
        SELECT    
            Id,    
            Muid,    
            RuleId,    
            [Text],    
            [Sql],    
            ItemTypeId, -- operator    
            Sequence,  
            AnchorAttributeDataType                     
        FROM @BR_Items     
        WHERE [Type] = @ActionId    
    END ELSE IF @IdentifiersOnly IN (@BusinessRulesResultType, @ActionResultType) BEGIN     
        -- IDs only    
        SELECT    
            Id,    
            Muid,    
            RuleId    
        FROM @BR_Items     
        WHERE [Type] = @ActionId            
    END ELSE BEGIN     
        -- None    
        SELECT NULL WHERE 1=0;    
    END          
    
    -- Conditions    
    IF @Details IN (@BusinessRulesResultType, @ConditionResultType, @ConditionTreeNodeResultType) BEGIN     
        -- Details    
        SELECT    
            Id,    
            Muid,    
            RuleId,    
            [Text],    
            [Sql],    
            ItemTypeId, -- operator    
            Sequence,    
            LogicalOperatorGroupId,    
            LogicalOperatorGroupMuid,               
            AnchorAttributeDataType      
        FROM @BR_Items     
        WHERE [Type] = @ConditionId    
    END ELSE IF @IdentifiersOnly IN (@BusinessRulesResultType, @ConditionResultType, @ConditionTreeNodeResultType) BEGIN     
        -- IDs only    
        SELECT    
            Id,    
            Muid,    
            RuleId,    
            LogicalOperatorGroupId,    
            LogicalOperatorGroupMuid                 
        FROM @BR_Items     
        WHERE [Type] = @ConditionId            
    END ELSE BEGIN     
        -- None    
        SELECT NULL WHERE 1=0;    
    END          
    
    -- Condition Tree Nodes     
    IF  @None <> @BusinessRulesResultType OR    
        @None <> @ConditionTreeNodeResultType    
    BEGIN    
         -- Details or IDs only    
        SELECT    
            DISTINCT    
            lo.ID Id,    
            lo.MUID Muid,    
            lo.BusinessRule_ID RuleId,    
            lop.ID ParentId,    
            lop.MUID ParentMuid,    
            lo.LogicalOperator_ID OperatorId,    
            lo.Sequence Sequence    
        FROM    
            mdm.tblBRLogicalOperatorGroup lo    
            INNER JOIN @BR_Ids br    
                ON lo.BusinessRule_ID = br.Id    
            LEFT JOIN mdm.tblBRItem it  -- left (not inner) join, because a condition operator group can be empty    
                ON lo.ID = it.BRLogicalOperatorGroup_ID     
            LEFT JOIN mdm.tblBRItemTypeAppliesTo itat    
                ON it.BRItemAppliesTo_ID = itat.ID    
            LEFT JOIN mdm.tblListRelationship lr    
                ON itat.ApplyTo_ID = lr.ID    
            LEFT JOIN mdm.tblBRLogicalOperatorGroup lop -- self join to get the parent group's MUID    
                ON lo.Parent_ID IS NOT NULL AND    
                   lo.Parent_ID = lop.ID    
            WHERE ISNULL(lr.Parent_ID, @ConditionId) <> @ActionId -- exclude action logical operator group    
        ORDER BY RuleId, ParentId, Sequence    
    END ELSE BEGIN    
        -- None    
        SELECT NULL WHERE 1=0;    
    END     
    
    -- Load Arguments into a table var    
    DECLARE @BR_ItemArguments TABLE     
    (    
        Id INT PRIMARY KEY,     
        Muid UNIQUEIDENTIFIER UNIQUE,    
        ItemId INT,    
        ParentId INT,     
        [Value] NVARCHAR(999),    
        ValueMuid UNIQUEIDENTIFIER,    
        ValueName NVARCHAR(128),    
        PropertyType INT,    
        PropertyName INT,    
        IsLeftHandSide BIT    
    );    
    IF  @None <> @BusinessRulesResultType OR    
        @None <> @ActionResultType OR             
        @None <> @ConditionResultType OR    
        @None <> @ConditionTreeNodeResultType    
    BEGIN    
        DECLARE @GetActions BIT SET @GetActions = 0    
        DECLARE @GetConditions BIT SET @GetConditions = 0    
        IF @ActionResultType <> @None OR @BusinessRulesResultType <> @None BEGIN    
            SET @GetActions = 1    
        END    
        IF @ConditionResultType <> @None OR @ConditionTreeNodeResultType <> @None OR @BusinessRulesResultType <> @None BEGIN    
            SET @GetConditions = 1    
        END    
        INSERT INTO @BR_ItemArguments    
        SELECT    
            ip.ID Id,    
            ip.MUID Muid,    
            ip.BRItem_ID ItemId,    
            COALESCE(ip.Parent_ID, 0) ParentId,    
            ip.Value [Value], -- freeform string, attributeId, hierarchyId, or member code (for attribute value arguments)  
            COALESCE(a.MUID, h.MUID) ValueMuid, -- attribute muid or hierarchy muid    
            COALESCE(a.Name, h.Name) ValueName, -- attribute name or hierarchy name  
            ip.PropertyType_ID PropertyType,    
            ip.PropertyName_ID PropertyName,    
            ip.IsLeftHandSide IsLeftHandSide  
       FROM    
            mdm.tblBRItemProperties ip     
            INNER JOIN @BR_Items i    
                ON ip.BRItem_ID = i.Id AND    
                   ip.ID > 0 AND    
                    ((@GetActions    = 1 AND i.Type = @ActionId) OR    
                     (@GetConditions = 1 AND i.Type = @ConditionId))    
            LEFT JOIN mdm.tblAttribute a    
                ON ip.PropertyType_ID IN (2,4) AND -- Attribute = 2, DBAAttribute = 4    
                   ip.Value = CONVERT(nvarchar(50), a.ID)    
            LEFT JOIN mdm.tblHierarchy h    
                ON ip.PropertyType_ID = 3 AND -- ParentAttribute = 3    
                   ip.Value = CONVERT(nvarchar(50), h.ID)    
       ORDER BY ip.BRItem_ID, ip.Sequence     
            
    END    
    
    -- Arguments    
    IF @Details IN (@BusinessRulesResultType, @ActionResultType, @ConditionResultType, @ConditionTreeNodeResultType) BEGIN     
        -- Details    
        SELECT     
            Id ,     
            Muid ,    
            ItemId ,    
            ParentId ,     
            [Value] ,    
            ValueMuid ,    
            ValueName ,    
            PropertyType ,    
            PropertyName ,    
            IsLeftHandSide    
         FROM @BR_ItemArguments; -- Note: Ignore the "Microsoft.Design#SR0001" Code Analysis warning.    
    END ELSE IF @IdentifiersOnly IN (@BusinessRulesResultType, @ActionResultType, @ConditionResultType, @ConditionTreeNodeResultType) BEGIN     
        -- IDs only    
        SELECT Id, Muid, ItemId, ParentId, PropertyType, IsLeftHandSide FROM @BR_ItemArguments;    
    END ELSE BEGIN    
        -- None    
        SELECT NULL WHERE 1=0;    
    END    
    
    SET NOCOUNT OFF    
END --proc
GO
