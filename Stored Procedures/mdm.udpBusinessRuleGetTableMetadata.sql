SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    EXEC mdm.udpBusinessRuleGetTableMetadata 1,1,31  
    EXEC mdm.udpBusinessRuleGetTableMetadata 1,2,31  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleGetTableMetadata]  
(  
    @BRType_ID      INT,  
    @BRSubType_ID   TINYINT,  
    @Foreign_ID     INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE  
        @FactTable                  sysname,  
        @ParentFactTable            sysname,  
        @PublishableStatus          mdm.IdList,  
        @ChangeValueActions         mdm.IdList,  
        @RecursiveInheritanceAttributes mdm.IdList,  
        @AttributeProperty          int = 2,  
        @DbaAttributeProperty       int = 4,  
        @ParentAttributeProperty    int = 3;  
  
    SET @FactTable = mdm.udfViewNameGetByID(@Foreign_ID,@BRSubType_ID,0)  
    SET @ParentFactTable = mdm.udfViewNameGetByID(@Foreign_ID,2,0)  
  
    INSERT INTO @PublishableStatus (ID)    
        SELECT OptionID FROM mdm.tblList   
        WHERE ListCode = CAST(N'lstBRStatus' AS NVARCHAR(50)) AND Group_ID = 1  -- Group_ID = 1 indicates publishable.  
  
    INSERT INTO @ChangeValueActions (ID)    
        SELECT AppliesTo_ID FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES WHERE ApplyToCategoryID = 2 AND BRTypeID = 2 AND (BRSubTypeID = 2 OR BRSubTypeID = 3)  
  
    INSERT INTO @RecursiveInheritanceAttributes         
        SELECT DISTINCT Attribute_ID FROM (  
            SELECT BusinessRule_ID, Attribute_ID  
            FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES a  
            INNER JOIN @PublishableStatus ps ON a.BusinessRule_Status = ps.ID  
            INNER JOIN @ChangeValueActions cva ON a.Item_AppliesTo_ID = cva.ID  
            WHERE      
                a.Attribute_Entity_ID = @Foreign_ID  
            AND a.Attribute_MemberType_ID = 2  
            AND a.Property_IsLeftHandSide = 1  
            INTERSECT  
            SELECT BusinessRule_ID, Attribute_ID  
            FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES a  
            INNER JOIN @PublishableStatus ps ON a.BusinessRule_Status = ps.ID  
            INNER JOIN @ChangeValueActions cva ON a.Item_AppliesTo_ID = cva.ID  
            WHERE      
                a.Attribute_Entity_ID = @Foreign_ID  
            AND a.Attribute_MemberType_ID = 2  
            AND a.Property_IsLeftHandSide = 0  
            AND a.Property_Parent_PropertyType_ID = @ParentAttributeProperty  
        ) r  
  
    /* FACT TABLE */  
    SELECT  
         @Foreign_ID AS ID  
        ,@FactTable AS [Name]    
        ,N'' AS ColumnPrefix  
        ,@BRSubType_ID AS MemberTypeID  
        ,N'Fact' AS Type  
        ,N'fact' AS Alias  
        ,N'' AS JoinTableName  
        ,N'' AS JoinTableColumn  
        ,N'' AS JoinTableAlias  
        ,CASE @BRSubType_ID   
            WHEN 1 THEN EntityTableName  
            WHEN 2 THEN HierarchyParentTableName  
         END AS PhysicalTableName  
        ,CASE @BRSubType_ID   
            WHEN 1 THEN StagingLeafName  
            WHEN 2 THEN StagingConsolidatedName  
         END AS StagingName  
    FROM mdm.viw_SYSTEM_TABLE_NAME WHERE ID = @Foreign_ID;  
  
    /* FACT TABLE ATTRIBUTES */  
    SELECT DISTINCT  
        @Foreign_ID AS ParentFactID,  
        col.COLUMN_NAME As [Name],  
        a.DisplayName,  
        a.ID AS TableColumnID,  
        a.AttributeType_ID AS AttributeTypeID,  
        a.DomainEntity_ID AS DomainEntityID,  
        CASE WHEN dbaRefresh.Attribute_DBAEntity_ID IS NULL THEN 0 ELSE 1 END AS IsDomainEntityRefreshRequired,  
        CASE WHEN recur.ID IS NULL THEN 0 ELSE 1 END AS IsRecursiveInheritance,  
        a.SortOrder AS Ordinal,  
        col.DATA_TYPE AS SQLType,  
        col.CHARACTER_MAXIMUM_LENGTH AS MaxLength,  
        col.NUMERIC_PRECISION AS NumericPrecision,  
        col.NUMERIC_SCALE AS NumericScale  
    FROM mdm.tblBRItemProperties p   
    INNER JOIN mdm.tblBRItem i ON   
        p.BRItem_ID = i.ID   
    INNER JOIN mdm.tblBRLogicalOperatorGroup g ON   
        i.BRLogicalOperatorGroup_ID = g.ID   
    INNER JOIN mdm.tblBRBusinessRule br ON   
        g.BusinessRule_ID = br.ID   
    INNER JOIN mdm.tblListRelationship lr ON   
        br.ForeignType_ID = lr.ID AND  
        br.Foreign_ID = @Foreign_ID AND  
        lr.Parent_ID = @BRType_ID AND  
        lr.Child_ID = @BRSubType_ID  
    INNER JOIN @PublishableStatus ps  
        ON br.Status_ID = ps.ID      
    INNER JOIN mdm.tblAttribute a ON   
        a.ID = cast(p.[Value] AS INT) and   
        (p.PropertyType_ID = @AttributeProperty OR p.PropertyType_ID = @DbaAttributeProperty ) and   
        p.Parent_ID is null AND   
        a.MemberType_ID = @BRSubType_ID   
    INNER JOIN INFORMATION_SCHEMA.COLUMNS col ON   
        col.TABLE_NAME = @FactTable AND col.TABLE_SCHEMA = 'mdm' AND (col.COLUMN_NAME = a.Name)  
    LEFT JOIN (      
        -- Find any DBAs that are getting set (left-hand side) and their attributes are referenced in the right-hand side of other rules  
        -- These DBA attribute values will need to be refreshed during business rule processing.  
        -- Find the DBAs getting set  
        SELECT  
            Attribute_DBAEntity_ID  
        FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES a  
            INNER JOIN @PublishableStatus ps ON a.BusinessRule_Status = ps.ID  
            INNER JOIN @ChangeValueActions cva ON a.Item_AppliesTo_ID = cva.ID  
        WHERE      
            a.Attribute_Entity_ID = @Foreign_ID  
        AND a.Attribute_MemberType_ID = @BRSubType_ID  
        AND a.Attribute_DBAEntity_ID IS NOT NULL  
        AND a.Property_IsLeftHandSide = 1  
        INTERSECT      
        -- Find the DBA attribute values being referenced.  
        SELECT  
            Attribute_DBAEntity_ID  
        FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES a  
            INNER JOIN @PublishableStatus ps ON a.BusinessRule_Status = ps.ID  
            INNER JOIN @ChangeValueActions cva ON a.Item_AppliesTo_ID = cva.ID  
        WHERE      
            a.Attribute_Entity_ID = @Foreign_ID  
        AND a.Attribute_MemberType_ID = @BRSubType_ID  
        AND a.Attribute_DBAEntity_ID IS NOT NULL  
        AND a.Property_IsLeftHandSide = 0  
        AND a.Property_Parent_ID IS NULL  
        AND a.PropertyType_ID = @DbaAttributeProperty  
    ) dbaRefresh  
    ON a.DomainEntity_ID = dbaRefresh.Attribute_DBAEntity_ID  
    LEFT JOIN @RecursiveInheritanceAttributes recur  
        ON a.ID = recur.ID  
    UNION  
    --Ensure the Code attribute is returned  
    SELECT DISTINCT  
        @Foreign_ID AS ParentFactID,  
        col.COLUMN_NAME As [Name],  
        a.DisplayName,  
        a.ID AS TableColumnID,  
        a.AttributeType_ID AS AttributeTypeID,  
        a.DomainEntity_ID AS DomainEntityID,  
        0 AS IsDomainEntityRefreshRequired,  
        0 AS IsRecursiveInheritance,  
        a.SortOrder AS Ordinal,  
        col.DATA_TYPE AS SQLType,  
        col.CHARACTER_MAXIMUM_LENGTH AS MaxLength,  
        col.NUMERIC_PRECISION AS NumericPrecision,  
        col.NUMERIC_SCALE AS NumericScale  
    FROM mdm.tblAttribute a    
    INNER JOIN INFORMATION_SCHEMA.COLUMNS col ON  
        a.Entity_ID = @Foreign_ID AND   
        a.MemberType_ID = @BRSubType_ID AND  
        a.Name = 'Code' AND  
        col.TABLE_NAME = @FactTable AND col.TABLE_SCHEMA = 'mdm' AND (col.COLUMN_NAME = a.Name)  
    ORDER BY  
        a.SortOrder;  
  
    /* DBA SUPPORTING FACT TABLES */  
    SELECT DISTINCT  
         e.ID  
        ,mdm.udfViewNameGetByID(DomainEntity_ID, 1, 0) AS [Name]  
        ,N'DBA.' + a.Name AS ColumnPrefix  
        ,1 AS MemberTypeID  
        ,N'SupportingFactDBA' AS Type  
        ,N'[dba' + a.Name + N']' AS Alias  
        ,@FactTable AS JoinTableName  
        ,a.Name AS JoinTableColumn  
        ,N'fact' AS JoinTableAlias  
        ,mdm.udfTableNameGetByID(DomainEntity_ID, 1) AS PhysicalTableName  
    FROM mdm.tblBRItemProperties p   
    INNER JOIN mdm.tblBRItem i ON   
        p.BRItem_ID = i.ID   
    INNER JOIN mdm.tblBRLogicalOperatorGroup g ON   
        i.BRLogicalOperatorGroup_ID = g.ID   
    INNER JOIN mdm.tblBRBusinessRule br ON   
        g.BusinessRule_ID = br.ID   
    INNER JOIN mdm.tblListRelationship lr ON   
        br.ForeignType_ID = lr.ID AND  
        br.Foreign_ID = @Foreign_ID AND  
        lr.Parent_ID = @BRType_ID AND  
        lr.Child_ID = @BRSubType_ID  
    INNER JOIN @PublishableStatus ps  
        ON br.Status_ID = ps.ID      
    INNER JOIN mdm.tblAttribute a ON   
        a.ID = cast(p.[Value] AS INT) and p.PropertyType_ID = @DbaAttributeProperty and p.Parent_ID is null   
    INNER JOIN  
        mdm.tblEntity e ON a.DomainEntity_ID = e.ID  
    ORDER BY [Type];  
  
    /* DBA SUPPORTING FACT TABLE ATTRIBUTES */  
    SELECT DISTINCT  
        a.Entity_ID AS ParentFactID,  
        col.COLUMN_NAME As [Name],   
        a.DisplayName,  
        a.ID AS TableColumnID,  
        a.AttributeType_ID AS AttributeTypeID,  
        a.DomainEntity_ID AS DomainEntityID,  
        0 AS IsDomainEntityRefreshRequired,  
        0 AS IsRecursiveInheritance,  
        a.SortOrder AS Ordinal,  
        col.DATA_TYPE AS SQLType,  
        col.CHARACTER_MAXIMUM_LENGTH AS MaxLength,  
        col.NUMERIC_PRECISION AS NumericPrecision,  
        col.NUMERIC_SCALE AS NumericScale  
    FROM mdm.tblBRItemProperties p   
    INNER JOIN mdm.tblBRItem i ON   
        p.BRItem_ID = i.ID   
    INNER JOIN mdm.tblBRLogicalOperatorGroup g ON   
        i.BRLogicalOperatorGroup_ID = g.ID   
    INNER JOIN mdm.tblBRBusinessRule br ON   
        g.BusinessRule_ID = br.ID   
    INNER JOIN mdm.tblListRelationship lr ON   
        br.ForeignType_ID = lr.ID AND  
        br.Foreign_ID = @Foreign_ID AND  
        lr.Parent_ID = @BRType_ID AND  
        lr.Child_ID = @BRSubType_ID   
    INNER JOIN @PublishableStatus ps  
        ON br.Status_ID = ps.ID      
    INNER JOIN mdm.tblAttribute a ON   
        a.ID = cast(p.[Value] AS INT) and   
        p.PropertyType_ID = @AttributeProperty and   
        p.Parent_ID is not null   
    INNER JOIN mdm.tblBRItemProperties p_dba ON   
        p.Parent_ID = p_dba.ID AND  
        p_dba.PropertyType_ID = @DbaAttributeProperty   
    INNER JOIN INFORMATION_SCHEMA.COLUMNS col ON   
        col.TABLE_NAME = mdm.udfViewNameGetByID(a.Entity_ID, 1, 0) AND col.TABLE_SCHEMA = 'mdm' AND (col.COLUMN_NAME = a.Name)  
    ORDER BY   
        ParentFactID, a.SortOrder;  
  
    /* PARENT (HIERARCHY) SUPPORTING FACT TABLES */  
    SELECT DISTINCT  
         h.ID  
        ,@ParentFactTable AS [Name]  
        ,N'Parent.' + h.Name AS ColumnPrefix  
        ,2 AS MemberTypeID  
        ,N'SupportingFactParent' AS Type  
        ,N'[hp' + h.Name + N']' AS Alias  
        ,mdm.udfTableNameGetByID(@Foreign_ID, 4) As JoinTableName  
        ,N'' AS JoinTableColumn  
        ,N'hr' AS JoinTableAlias  
        ,mdm.udfTableNameGetByID(@Foreign_ID, 4) AS PhysicalTableName  
    FROM mdm.tblBRItemProperties p   
    INNER JOIN mdm.tblBRItem i ON   
        p.BRItem_ID = i.ID   
    INNER JOIN mdm.tblBRLogicalOperatorGroup g ON   
        i.BRLogicalOperatorGroup_ID = g.ID   
    INNER JOIN mdm.tblBRBusinessRule br ON   
        g.BusinessRule_ID = br.ID   
    INNER JOIN mdm.tblListRelationship lr ON   
        br.ForeignType_ID = lr.ID AND  
        br.Foreign_ID = @Foreign_ID AND  
        lr.Parent_ID = @BRType_ID AND  
        lr.Child_ID = @BRSubType_ID  
    INNER JOIN @PublishableStatus ps  
        ON br.Status_ID = ps.ID      
    INNER JOIN mdm.tblHierarchy h ON   
        h.ID = cast(p.[Value] AS INT) and p.PropertyType_ID = @ParentAttributeProperty and p.Parent_ID is null   
    ORDER BY   
        h.ID;  
  
    /* PARENT (HIERARCHY) SUPPORTING FACT TABLE ATTRIBUTES */  
    SELECT DISTINCT  
        cast(p_parent.[Value] AS INT) AS ParentFactID,  
        col.COLUMN_NAME As [Name],  
        a.DisplayName,  
        a.ID AS TableColumnID,  
        a.AttributeType_ID AS AttributeTypeID,  
        a.DomainEntity_ID AS DomainEntityID,  
        0 AS IsDomainEntityRefreshRequired,  
        CASE WHEN recur.ID IS NULL THEN 0 ELSE 1 END AS IsRecursiveInheritance,  
        a.SortOrder AS Ordinal,  
        col.DATA_TYPE AS SQLType,  
        col.CHARACTER_MAXIMUM_LENGTH AS MaxLength,  
        col.NUMERIC_PRECISION AS NumericPrecision,  
        col.NUMERIC_SCALE AS NumericScale  
    FROM mdm.tblBRItemProperties p   
    INNER JOIN mdm.tblBRItem i ON   
        p.BRItem_ID = i.ID   
    INNER JOIN mdm.tblBRLogicalOperatorGroup g ON   
        i.BRLogicalOperatorGroup_ID = g.ID   
    INNER JOIN mdm.tblBRBusinessRule br ON   
        g.BusinessRule_ID = br.ID   
    INNER JOIN mdm.tblListRelationship lr ON   
        br.ForeignType_ID = lr.ID AND  
        br.Foreign_ID = @Foreign_ID AND  
        lr.Parent_ID = @BRType_ID AND  
        lr.Child_ID = @BRSubType_ID  
    INNER JOIN @PublishableStatus ps  
        ON br.Status_ID = ps.ID      
    INNER JOIN mdm.tblAttribute a ON   
        a.ID = cast(p.[Value] AS INT) and   
        p.PropertyType_ID = @AttributeProperty and   
        p.Parent_ID is not null   
    INNER JOIN mdm.tblBRItemProperties p_parent ON   
        p.Parent_ID = p_parent.ID AND  
        p_parent.PropertyType_ID = @ParentAttributeProperty   
    INNER JOIN INFORMATION_SCHEMA.COLUMNS col ON   
        col.TABLE_NAME = @ParentFactTable AND col.TABLE_SCHEMA = 'mdm' AND (col.COLUMN_NAME = a.Name)  
    LEFT JOIN @RecursiveInheritanceAttributes recur  
        ON a.ID = recur.ID  
    ORDER BY   
        a.SortOrder;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
