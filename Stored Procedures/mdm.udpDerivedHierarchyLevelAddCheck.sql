SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    SELECT mdm.udfDerivedHierarchyLevelAddCheck(1, 1515, 1);  
*/  
CREATE PROCEDURE [mdm].[udpDerivedHierarchyLevelAddCheck]  
(  
    @DerivedHierarchy_ID  INT,  
    @Foreign_ID  INT,  
    @ForeignType_ID  INT,  
    @NextLevelNumber INT OUTPUT,    -- 0 = Incompatible level info; >0 = The new top most level.  
    @TopLevelForeign_ID INT OUTPUT  -- The toplevel foreign Id that will be used to set the foreign parent Id.  
)   
/*WITH*/  
AS BEGIN  
    DECLARE @Entity_ID INT,  
            @TopLevelNumber INT,  
            @TopLevelForeignType_ID  INT;  
  
    /************************************************/  
    /*@ForeignType_ID is Common.HierarchyItemType   */  
    /************************************************/  
    DECLARE @HierarchyItemType_Entity          INT = 0;  
    DECLARE @HierarchyItemType_DBA             INT = 1;  
    DECLARE @HierarchyItemType_Hierarchy       INT = 2;  
    DECLARE @HierarchyItemType_ConsolidatedDBA INT = 3;  
      
    -- Get the current top level so we can validate it against the requested Foreign_ID and ForeignType_ID.  
    SELECT TOP 1   
         @TopLevelForeign_ID = Foreign_ID  
        ,@TopLevelForeignType_ID = ForeignType_ID  
        ,@TopLevelNumber = dhLevelNumber  
    FROM mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS WHERE Hierarchy_ID = @DerivedHierarchy_ID AND ForeignParent_ID <> -1 ORDER BY LevelNumber  
  
    SET @TopLevelForeign_ID = ISNULL(@TopLevelForeign_ID, 0);  
    SET @TopLevelForeignType_ID = ISNULL(@TopLevelForeignType_ID, -1);  
  
    --Initialize next level to 0, the error state.  
    SET @NextLevelNumber = 0;  
  
    IF @TopLevelForeignType_ID = -1 --Model  
    BEGIN  
        -- The first level must be an entity and must be in the model of the derived hierarchy.  
        IF EXISTS(SELECT 1 FROM mdm.tblEntity E INNER JOIN mdm.tblDerivedHierarchy DH ON E.ID = @Foreign_ID AND DH.ID = @DerivedHierarchy_ID AND E.Model_ID = DH.Model_ID)  
            SET @NextLevelNumber = 1;  
    END  
  
    ELSE IF @TopLevelForeignType_ID = @HierarchyItemType_Entity  
    BEGIN  
        -- The second level can be either a DBA or a Hierarchy  
        IF @ForeignType_ID = @HierarchyItemType_DBA AND EXISTS(SELECT 1 FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Attribute_ID = @Foreign_ID AND Entity_ID = @TopLevelForeign_ID AND Attribute_MemberType_ID = 1 AND Attribute_DBAEntity_ID > 0)  
            BEGIN  
                SET @NextLevelNumber = @TopLevelNumber + 1;  
            END  
        ELSE IF @ForeignType_ID = @HierarchyItemType_Hierarchy AND EXISTS(SELECT 1 FROM mdm.tblHierarchy WHERE ID = @Foreign_ID AND Entity_ID = @TopLevelForeign_ID)  
                SET @NextLevelNumber = @TopLevelNumber + 1;  
    END  
  
    ELSE IF @TopLevelForeignType_ID = @HierarchyItemType_DBA  
    BEGIN  
        -- If the current top level is a DBA the next level can be either a DBA or a Hierarchy  
        SELECT @Entity_ID = DomainEntity_ID FROM mdm.tblAttribute WHERE ID = @TopLevelForeign_ID  
  
        IF (@ForeignType_ID = @HierarchyItemType_DBA  
            AND EXISTS(SELECT 1   
                        FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES   
                        WHERE     Attribute_ID = @Foreign_ID   
                            AND Entity_ID = @Entity_ID   
                            AND Attribute_MemberType_ID = 1   
                            AND Attribute_DBAEntity_ID > 0   
                        ))  
            OR (@ForeignType_ID = @HierarchyItemType_Hierarchy   
                AND EXISTS(SELECT 1 FROM mdm.tblHierarchy WHERE ID = @Foreign_ID AND Entity_ID = @Entity_ID))  
        BEGIN   
            SET @NextLevelNumber = @TopLevelNumber + 1;  
        END  
    END  
  
    ELSE IF @TopLevelForeignType_ID = @HierarchyItemType_Hierarchy  
    BEGIN  
        -- If the current top level is a Hierarchy then no other levels can be added.  
        SET @NextLevelNumber = 0;  
    END  
  
    ELSE IF @TopLevelForeignType_ID = @HierarchyItemType_ConsolidatedDBA  
    BEGIN  
        -- If the current top level is a consolidated DBA the next level can only be a DBA.  
        IF @ForeignType_ID = @HierarchyItemType_DBA AND EXISTS(SELECT 1 FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Attribute_ID = @Foreign_ID AND Entity_ID = @TopLevelForeign_ID AND Attribute_MemberType_ID = 2 AND Attribute_DBAEntity_ID > 0)  
            SET @NextLevelNumber = @TopLevelNumber + 1;  
    END  
  
END; --fn
GO
