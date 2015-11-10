SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Gets the entity processing sequence for a model.  The default processing sequence is based on the relationships between entities via  
    domain-based attributes.  However, because of circular relationships this default sequence cannot be deterministically ordered.  In   
    this case derived hierarchies (there can be multiple) can be used to drive the relationship sequencing.    
      
    Here is how the DH Priority is used.  The way to read this is a priority of �1� is the most important therefore will go last  
    in the process.    
  
    DH  Priority             Processed  
    --- -------------------- ---------  
    DH3 3 (least important)  1st   
    DH2 2                    2nd   
    DH1 1 (most important)   3rd   
   
    Assume a scenario where multiple DHs are marked with a processing priority.  Using the sample Product model.  The product model  
    has these entities, in no particular order.  
  
    ID Name  
    -- ------------  
    33 Category  
    37 Class  
    35 Color  
    39 Country  
    31 Product  
    34 ProductGroup  
    36 SizeRange  
    38 Style  
    32 SubCategory  
   
    Given these two DHs.  
  
    Category: Priority = 1  
  
    Level ID Name  
    ----- -- -------------  
    3     34 ProductGroup  
    2     33 Category  
    1     32 SubCategory  
    0     31 Product  
   
    Market: Priority = 2  
    Level ID Name  
    ----- -- -------------  
    1     39 Country  
    0     31 Product  
   
    Any DHs that have a Priority > 1 will have duplicate entities filtered out, so Market DH will have the Product entity filtered out.    
    And the other entity, Country, will be processed before the ProductGroup entity, which is defined in the Category DH.  Assuming we have  
    a circular ref where the ProductGroup entity has a DBA for Product (ProductGroup.ProductDba) calling udpEntityGetProcessingSequence   
    gives us this sequence.  
  
    Entity_ID Processing Sequence  
    --------- -------------------  
    39        1  
    38        2  
    37        3  
    36        4  
    35        5  
    34        6  
    33        7  
    32        8  
    31        9  
  
    If there is a circular ref situation and two DHs that defined the relationship both ways can be handled as well.  Given a circular   
    ref between Product and SubCategory so:  
  
    Product.SubCategoryDba --> SubCategory  
    SubCategory.ProductDba --> Product  
  
    DH1: ProcessingPriority = 1  
    Level ID Name  
    ----- -- -------------  
    1     32 SubCategory  
    0     31 Product  
  
    DH2: ProcessingPriority = 2  
    Level ID Name  
    ----- -- -------------  
    1     31 Product  
    0     32 SubCategory  
   
    Because both entities of DH2 have already been defined in DH1 and DH1 has a �higher� priority the DH2 entities are ignored or filtered out.  
  
	SELECT Entity_ID, [Level] AS RelativeOrder_ID FROM mdm.udfEntityDependencyTree(7, NULL) WHERE MemberType_ID = 1 ORDER BY [Level] DESC;  
	SELECT * FROM mdm.udfEntityGetProcessingSequence(7) ORDER BY [Level];  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfEntityGetProcessingSequence]  
(  
	@Model_ID	INT  
)  
RETURNS TABLE   
/*WITH SCHEMABINDING*/  
AS   
	RETURN  
      
    WITH ProcessPriorityExplode AS (  
        --Gets sequence based solely on entity relationships.  This is our default sequence and is given a low priority    
        --so the DH processing priorities, if specified, will be ranked higher.  If entity circular references are in place  
        --udfEntityDependencyTree, which uses a recursive CTE, will return an entity sequence, but it will be   
        --non-deterministic.    
        SELECT   
             2147483647 AS Priority   
            ,[Level] AS RelativeOrder_ID  
            ,Entity_ID  
        FROM mdm.udfEntityDependencyTree(@Model_ID, NULL)   
        WHERE MemberType_ID = 1 -- Leaf   
        UNION  
        --Gets all entity records that have a processing priority defined by a derived hierarchy.  Multiple derived   
        --hierarchies can have a processing priority defined. In the cases where entity circular references exists a   
        --derived hierarchy with a processing priority must be in place to get deterministic results.  
        SELECT   
             dh.Priority AS Priority  
            ,dhd.[Level_ID] AS RelativeOrder_ID  
            ,CASE   
                WHEN dhd.ForeignType_ID = 0 --Base entity   
                    THEN dhd.Foreign_ID   
                WHEN dhd.ForeignType_ID = 1 --Domain based attribute   
                    THEN attr.Attribute_DBAEntity_ID   
            END AS Entity_ID  
        FROM [mdm].[tblDerivedHierarchyDetail] dhd  
        INNER JOIN [mdm].[tblDerivedHierarchy] dh   
            ON dh.ID = dhd.DerivedHierarchy_ID  
        LEFT JOIN [mdm].[viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC] attr   
            ON attr.Attribute_ID = dhd.Foreign_ID AND dhd.ForeignType_ID = 1 --Domain based attribute   
        WHERE dh.Priority > 0  
        AND dh.Model_ID = @Model_ID  
          
    ),  
    --Gives a distinct list of entities, associated with the lowest Priority they are associated with (removes duplicates)  
    EntityProcessPriority AS (  
        SELECT   
             MIN(Priority) AS Priority  
            ,Entity_ID           
        FROM ProcessPriorityExplode   
        GROUP BY Entity_ID  
    )    
    --Get the overall ranking from the explode and combine to give distinct entity records, eliminating the duplicates from less important   
    --DHs, this orders by DH priority in DESC and then sorts within that by the relative level DESC.  
    SELECT   
         epp.Entity_ID  
        ,ROW_NUMBER() OVER (ORDER BY epp.Priority DESC, explode.RelativeOrder_ID DESC) AS [Level]  
    FROM ProcessPriorityExplode AS explode  
    INNER JOIN EntityProcessPriority AS epp   
        ON explode.Priority = epp.Priority AND explode.Entity_ID = epp.Entity_ID;
GO
