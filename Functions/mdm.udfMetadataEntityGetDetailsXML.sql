SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Returns a serialized Entity business entity object.  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataEntityGetDetailsXML]  
(  
    @User_ID            INT,  
    @ModelIDs           XML = NULL,  
    @EntityIDs          XML = NULL,  
    @HierarchyIDs       XML = NULL,  
    @MemberTypeIDs      XML = NULL,  
    @AttributeIDs       XML = NULL,  
    @AttributeGroupIDs  XML = NULL,  
    @ResultOption       SMALLINT,  
    @SearchOption       SMALLINT  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
    DECLARE @Return XML  
  
    -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
    -- may fail (sometimes silently) to deserialize out-of-order columns.  
    SELECT @Return = CONVERT(XML, (  
      SELECT  
        -- Members inherited from Core.BusinessEntities.BusinessEntity   
        [AuditInfo/CreatedDateTime] = vEnt.EnteredUser_DTM,  
        [AuditInfo/CreatedUserId/Id] = vEnt.EnteredUser_ID,  
        [AuditInfo/CreatedUserId/Muid] = vEnt.EnteredUser_MUID,  
        [AuditInfo/CreatedUserId/Name] = vEnt.EnteredUser_UserName,  
        [AuditInfo/UpdatedDateTime] = vEnt.LastChgUser_DTM,  
        [AuditInfo/UpdatedUserId/Id] = vEnt.LastChgUser_ID,  
        [AuditInfo/UpdatedUserId/Muid] = vEnt.LastChgUser_MUID,  
        [AuditInfo/UpdatedUserId/Name] = vEnt.LastChgUser_UserName,  
        [Identifier/Id] = vEnt.ID,  
        [Identifier/Muid] = vEnt.MUID,  
        [Identifier/Name] = vEnt.Name,  
        [Identifier/ModelId/Id] = vEnt.Model_ID,  
        [Identifier/ModelId/Muid] = vEnt.Model_MUID,  
        [Identifier/ModelId/Name] = vEnt.Model_Name,  
        [Permission] = tPriv.Name,  
          
        -- Core.BusinessEntities.Entity members. The data members are ordered alphabetically.  
        [CodeGenerationSeed] = vEnt.CodeGenerationSeed,  
        [ExplicitHierarchies] = mdm.udfMetadataExplicitHierarchiesGetXML (@User_ID, @ModelIDs,  
                                        N'<Entities><Identifier><Muid>' + cast(vEnt.MUID as NVARCHAR(50)) + N'</Muid></Identifier></Entities>',  
                                        @HierarchyIDs, @ResultOption, @SearchOption),  
        [IsBase] = vEnt.IsBase,      
        [IsCodeGenerationEnabled] = vEnt.IsCodeGenerationEnabled,  
        [IsFlat] = vEnt.IsFlat,      
        [IsSystem] = vEnt.IsSystem,     
        [MemberTypes] = mdm.udfMetadataMemberTypeGetXML(@User_ID, @ModelIDs,  
                            N'<Entities><Identifier><Muid>' + cast(vEnt.MUID as NVARCHAR(50)) + N'</Muid></Identifier></Entities>',  
                            @MemberTypeIDs, @AttributeIDs, @AttributeGroupIDs, @ResultOption, @SearchOption),  
        [StagingName] = vEnt.StagingBase  
  
      FROM    mdm.udfSecurityUserEntityList(@User_ID, NULL) acl  
              INNER JOIN mdm.viw_SYSTEM_SCHEMA_ENTITY vEnt   
                ON  acl.ID = vEnt.ID   
                AND ((vEnt.IsSystem = @SearchOption AND @SearchOption <> 2) OR @SearchOption = 2)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
                ON (vEnt.Model_MUID = mdl.MUID OR mdl.MUID IS NULL)  
                AND (vEnt.Model_ID = mdl.ID OR mdl.ID IS NULL)  
                AND (vEnt.Model_Name = mdl.Name OR mdl.Name IS NULL)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@EntityIDs) ent  
                ON (vEnt.MUID = ent.MUID or ent.MUID IS NULL)  
                AND (vEnt.ID = ent.ID OR ent.ID IS NULL)  
                AND (vEnt.Name = ent.Name OR ent.Name IS NULL)  
            INNER JOIN mdm.tblSecurityPrivilege tPriv  
               ON tPriv.ID = acl.Privilege_ID  
      ORDER BY vEnt.Model_ID, vEnt.Name  
      FOR XML PATH('Entity'), ELEMENTS XSINIL  
      ))  
  
    RETURN COALESCE(@Return, N'');  
END; --function
GO
