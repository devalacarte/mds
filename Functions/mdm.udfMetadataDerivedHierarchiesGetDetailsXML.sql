SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Returns a serialized Derived Hierarchy business entity object.  
    SELECT mdm.udfMetadataDerivedHierarchiesGetDetailsXML(1, NULL, N'<Identifier><Muid>424DCCCC-3320-4F76-81EA-06D3D5376A5B</Muid></Identifier>', 2, 2)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataDerivedHierarchiesGetDetailsXML]  
(  
    @User_ID        INT,  
    @ModelIDs       XML = NULL,  
    @HierarchyIDs   XML = NULL,  
    @ResultOption   SMALLINT,  
    @SearchOption   SMALLINT  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
DECLARE @return     XML  
  
   -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
   -- may fail (sometimes silently) to deserialize out-of-order columns.  
   SELECT @return = CONVERT(XML, (  
       --Need to do this additional select because we can't do the SELECT DISTINCT with the Levels column in there.  
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
            [Permission] = tPriv.Name,  
              
            -- Core.BusinessEntities.DerivedHierarchy members  
            [AnchorNullRecursions] = vHir.Hierarchy_AnchorNullRecursions,               
            [FullyQualifiedName] = vHir.Hierarchy_Label,               
            --[IsSystem] = vHir.Model_IsSystem, -- unused?  
            [Levels] = CASE vHir.Levels WHEN 0 THEN N'' ELSE mdm.udfMetadataDerivedHierarchyLevelsGetXML(@User_ID, @ModelIDs, N'<Identifier><Muid>' + cast(vHir.Hierarchy_MUID as NVARCHAR(50)) + N'</Muid></Identifier>', NULL, @ResultOption, @SearchOption) END  
          FROM  
            mdm.udfSecurityUserHierarchyDerivedList (@User_ID, NULL) acl  
            INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED vHir   
                ON acl.ID = vHir.Hierarchy_ID  
                AND ((vHir.Model_IsSystem = @SearchOption AND @SearchOption <> 2) OR @SearchOption = 2)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
                ON (vHir.Model_MUID = mdl.MUID OR mdl.MUID IS NULL)  
                AND (vHir.Model_ID = mdl.ID OR mdl.ID IS NULL)  
                AND (vHir.Model_Name = mdl.Name OR mdl.Name IS NULL)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@HierarchyIDs) eh  
                ON (vHir.Hierarchy_MUID = eh.MUID OR eh.MUID IS NULL)  
                AND (vHir.Hierarchy_ID = eh.ID OR eh.ID IS NULL)  
                AND (vHir.Hierarchy_Name = eh.Name OR eh.Name IS NULL)  
            INNER JOIN mdm.tblSecurityPrivilege tPriv  
                ON tPriv.ID = acl.Privilege_ID  
          ORDER BY  
              vHir.Model_MUID, vHir.Hierarchy_Label  
          FOR XML PATH('DerivedHierarchy'),ELEMENTS XSINIL  
          ))  
  
    RETURN COALESCE(@return, N'');  
END
GO
