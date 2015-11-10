SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Returns a serialized Explicit Hierarchy business entity object.  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataExplicitHierarchiesGetXML]  
(  
    @User_ID        INT,  
    @ModelIDs       XML = NULL,  
    @EntityIDs      XML = NULL,  
    @HierarchyIDs   XML = NULL,  
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
            [AuditInfo/CreatedDateTime] = vHir.EnteredUser_DTM,  
            [AuditInfo/CreatedUserId/Id] = vHir.EnteredUser_ID,  
            [AuditInfo/CreatedUserId/Muid] = vHir.EnteredUser_MUID,  
            [AuditInfo/CreatedUserId/Name] = vHir.EnteredUser_UserName,  
            [AuditInfo/UpdatedDateTime] = vHir.LastChgUser_DTM,  
            [AuditInfo/UpdatedUserId/Id] = vHir.LastChgUser_ID,  
            [AuditInfo/UpdatedUserId/Muid] = vHir.LastChgUser_MUID,  
            [AuditInfo/UpdatedUserId/Name] = vHir.LastChgUser_UserName,  
            [Identifier/Id] = vHir.Hierarchy_ID,  
            [Identifier/Muid] = vHir.Hierarchy_MUID,  
            [Identifier/Name] = vHir.Hierarchy_Name,  
            [Identifier/ModelId/Id] = vHir.Model_ID,  
            [Identifier/ModelId/Muid] = vHir.Model_MUID,  
            [Identifier/ModelId/Name] = vHir.Model_Name,  
            [Identifier/EntityId/Id] = vHir.Entity_ID,  
            [Identifier/EntityId/Muid] = vHir.Entity_MUID,  
            [Identifier/EntityId/Name] = vHir.Entity_Name,  
            [Permission] = tPriv.Name,  
              
            -- Core.BusinessEntities.ExplicitHierarchy members           
            [FullyQualifiedName] = vHir.Hierarchy_Label,  
            [IsMandatory] = vHir.Hierarchy_IsMandatory  
            --[IsSystem] = vHir.Entity_IsSystem    -- unused?  
          FROM  
              mdm.udfSecurityUserHierarchyList(@User_ID, NULL, NULL) acl  
              INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_EXPLICIT vHir   
                  ON acl.ID = vHir.Hierarchy_ID  
                  AND vHir.Entity_IsSystem  = CASE @SearchOption WHEN 2 THEN vHir.Entity_IsSystem  ELSE @SearchOption END  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
                ON vHir.Model_MUID = ISNULL(mdl.MUID, vHir.Model_MUID)   
                AND vHir.Model_ID = ISNULL(mdl.ID, vHir.Model_ID)   
                AND vHir.Model_Name = ISNULL(mdl.Name, vHir.Model_Name)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@EntityIDs) ent  
                ON vHir.Entity_MUID = ISNULL(ent.MUID, vHir.Entity_MUID)   
                AND vHir.Entity_ID = ISNULL(ent.ID, vHir.Entity_ID)   
                AND vHir.Entity_Name = ISNULL(ent.Name, vHir.Entity_Name)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@HierarchyIDs) eh  
                ON vHir.Hierarchy_MUID = ISNULL(eh.MUID, vHir.Hierarchy_MUID)   
                AND vHir.Hierarchy_ID = ISNULL(eh.ID, vHir.Hierarchy_ID)   
                AND vHir.Hierarchy_Name = ISNULL(eh.Name, vHir.Hierarchy_Name)  
            INNER JOIN mdm.tblSecurityPrivilege tPriv  
               ON tPriv.ID = acl.Privilege_ID  
         ORDER BY  
            vHir.Model_ID, vHir.Entity_ID, vHir.Hierarchy_Label  
               FOR XML PATH('ExplicitHierarchy'),ELEMENTS XSINIL  
         ))  
  
    RETURN COALESCE(@return, N'');  
END
GO
