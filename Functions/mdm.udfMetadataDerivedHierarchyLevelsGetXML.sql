SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    SELECT mdm.udfMetadataDerivedHierarchyLevelsGetXML(1, NULL, N'<Identifier><Name>Category</Name></Identifier>', NULL, 2, 2)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataDerivedHierarchyLevelsGetXML]  
(  
    @User_ID        INT,  
    @ModelIDs       XML = NULL,  
    @HierarchyIDs   XML = NULL,  
    @LevelIDs       XML = NULL,  
    @ResultOption   SMALLINT,  
    @SearchOption   SMALLINT  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
    DECLARE @return XML  
  
    -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
    -- may fail (sometimes silently) to deserialize out-of-order columns.  
    SELECT @return = CONVERT(XML, (  
        SELECT  
            -- Members inherited from Core.BusinessEntities.BusinessEntity   
            [AuditInfo/CreatedDateTime] = vHir.Detail_EnteredUser_DTM,  
            [AuditInfo/CreatedUserId/Id] = vHir.Detail_EnteredUser_ID,  
            [AuditInfo/CreatedUserId/Muid] = vHir.Detail_EnteredUser_MUID,  
            [AuditInfo/CreatedUserId/Name] = vHir.Detail_EnteredUser_UserName,  
            [AuditInfo/UpdatedDateTime] = vHir.Detail_LastChgUser_DTM,  
            [AuditInfo/UpdatedUserId/Id] = vHir.Detail_LastChgUser_ID,  
            [AuditInfo/UpdatedUserId/Muid] = vHir.Detail_LastChgUser_MUID,  
            [AuditInfo/UpdatedUserId/Name] = vHir.Detail_LastChgUser_UserName,  
            [Identifier/Id] = vHir.ID,  
            [Identifier/Muid] = vHir.MUID,  
            [Identifier/Name] = vHir.Name,  
            [Identifier/ModelId/Id] = vHir.Model_ID,  
            [Identifier/ModelId/Muid] = vHir.Model_MUID,  
            [Identifier/ModelId/Name] = vHir.Model_Name,  
            [Identifier/DerivedHierarchyId/Id] = vHir.Hierarchy_ID,  
            [Identifier/DerivedHierarchyId/Muid] = vHir.Hierarchy_MUID,  
            [Identifier/DerivedHierarchyId/Name] = vHir.Hierarchy_Name,  
             
            -- Core.BusinessEntities.DerivedHierarchyLevel members  
            [DisplayName] = vHir.DisplayName,  
            [ForeignEntityId/Id] = vHir.ForeignEntity_ID,  
            [ForeignEntityId/Muid] = vHir.ForeignEntity_MUID,  
            [ForeignEntityId/Name] = vHir.ForeignEntity_Name,  
            [ForeignId/Id] = vHir.Foreign_ID,  
            [ForeignId/Muid] = vHir.Foreign_MUID,  
            [ForeignId/Name] = vHir.Foreign_Name,  
            [ForeignType] = vHir.ForeignType_Name,  
            [IsRecursive] = vHir.IsRecursive,  
            [IsVisible] = vHir.IsLevelVisible,      
            [LevelNumber] = vHir.LevelNumber,  
            [MemberType] = vHir.MemberType_Name  
        FROM  
            mdm.udfSecurityUserHierarchyDerivedList (@User_ID, NULL) acl  
            INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS vHir   
                ON acl.ID = vHir.Hierarchy_ID  
                AND vHir.ForeignParent_ID <> -1  
                AND vHir.Model_IsSystem = CASE @SearchOption WHEN 2 THEN vHir.Model_IsSystem ELSE @SearchOption END  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
                ON vHir.Model_MUID = ISNULL(mdl.MUID, vHir.Model_MUID)   
                AND vHir.Model_ID = ISNULL(mdl.ID, vHir.Model_ID)   
                AND vHir.Model_Name = ISNULL(mdl.Name, vHir.Model_Name)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@HierarchyIDs) dh  
                ON vHir.Hierarchy_MUID = ISNULL(dh.MUID, vHir.Hierarchy_MUID)   
                AND vHir.Hierarchy_ID = ISNULL(dh.ID, vHir.Hierarchy_ID)   
                AND vHir.Hierarchy_Name = ISNULL(dh.Name, vHir.Hierarchy_Name)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@LevelIDs) dhl  
                ON vHir.MUID = ISNULL(dhl.MUID, vHir.MUID)   
                AND vHir.ID = ISNULL(dhl.ID, vHir.ID)   
                AND vHir.Name = ISNULL(dhl.Name, vHir.Name)  
        ORDER BY  
            vHir.Model_MUID, vHir.Hierarchy_Label, vHir.dhLevelNumber  
        FOR XML PATH('DerivedHierarchyLevel'),ELEMENTS XSINIL  
          ))  
  
    RETURN COALESCE(@return, N'');  
END
GO
