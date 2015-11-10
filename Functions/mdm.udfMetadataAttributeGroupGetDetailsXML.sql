SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Returns a serialized Entity business entity object.  
  
SELECT mdm.udfMetadataAttributeGroupGetDetailsXML(  
    1  
    ,null  
    ,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
    ,'<MemberTypes><MemberType>Leaf</MemberType></MemberTypes>'  
    ,null  
    ,null  
    ,2  
    ,0  
)  
  
SELECT mdm.udfMetadataAttributeGroupGetDetailsXML(  
    1  
    ,null  
    ,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
    ,'<MemberTypes><MemberType>Consolidated</MemberType></MemberTypes>'  
    ,null  
    ,null  
    ,1  
    ,0  
)  
  
SELECT mdm.udfMetadataAttributeGroupGetXML(  
    1  
    ,null  
    ,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
    ,null  
    ,null  
    ,'<AttributeGroups><Identifier><Muid>108673D9-7BB3-4C03-A31C-FAB65CBCA067</Muid></Identifier></AttributeGroups>'  
    ,2  
    ,0  
)  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataAttributeGroupGetDetailsXML]  
(  
    @User_ID            INT,  
    @ModelIDs           XML = NULL,  
    @EntityIDs          XML = NULL,  
    @MemberTypeIDs      XML = NULL,  
    @AttributeIDs       XML = NULL,  
    @AttributeGroupIDs  XML = NULL,  
    @ResultOption       SMALLINT,  
    @SearchOption       SMALLINT  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
   DECLARE @return         XML;  
  
   -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
   -- may fail (sometimes silently) to deserialize out-of-order columns.  
   SELECT @return = CONVERT(XML, (  
    SELECT      
      -- Members inherited from Core.BusinessEntities.BusinessEntity   
      [AuditInfo/CreatedDateTime] = vAG.EnteredUser_DTM,  
      [AuditInfo/CreatedUserId/Id] = vAG.EnteredUser_ID,  
      [AuditInfo/CreatedUserId/Muid] = vAG.EnteredUser_MUID,  
      [AuditInfo/CreatedUserId/Name] = vAG.EnteredUser_UserName,  
      [AuditInfo/UpdatedDateTime] = vAG.LastChgUser_DTM,  
      [AuditInfo/UpdatedUserId/Id] = vAG.LastChgUser_ID,  
      [AuditInfo/UpdatedUserId/Muid] = vAG.LastChgUser_MUID,  
      [AuditInfo/UpdatedUserId/Name] = vAG.LastChgUser_UserName,  
      [Identifier/Id] = vAG.ID,  
      [Identifier/Muid] = vAG.MUID,  
      [Identifier/Name] = vAG.Name,  
      [Identifier/ModelId/Id] = vAG.Model_ID,  
      [Identifier/ModelId/Muid] = vAG.Model_MUID,  
      [Identifier/ModelId/Name] = vAG.Model_Name,  
      [Identifier/EntityId/Id] = vAG.Entity_ID,  
      [Identifier/EntityId/Muid] = vAG.Entity_MUID,  
      [Identifier/EntityId/Name] = vAG.Entity_Name,  
      [Identifier/MemberType] = vAG.MemberType_Name,  
      [Permission] = tPriv.Name,  
       
      -- Core.BusinessEntities.AttributeGroup members  
      [Attributes] = mdm.udfMetadataAttributeGetXML(  
                @User_ID,   
                @ModelIDs,   
                @EntityIDs,   
                @MemberTypeIDs,   
                @AttributeIDs,   
                N'<AttributeGroups><Identifier><Muid>' + cast(vAG.MUID as NVARCHAR(50)) + N'</Muid></Identifier></AttributeGroups>',  
                1,   
                @SearchOption),  
      [FullName] = FullName,  
      [IsNameCodeFrozen] = vAG.IsNameCodeFrozen,      
      [IsSystem] = vAG.IsSystem,      
      [SortOrder] = SortOrder  
    FROM    mdm.udfSecurityUserAttributeGroupList(@User_ID, NULL, NULL, NULL) acl  
        INNER JOIN     mdm.viw_SYSTEM_SCHEMA_ATTRIBUTEGROUPS vAG   
            ON    acl.ID = vAG.ID   
            AND ((vAG.IsSystem = @SearchOption AND @SearchOption <> 2) OR @SearchOption = 2)  
         INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
            ON (vAG.Model_MUID = mdl.MUID OR mdl.MUID IS NULL)  
            AND (vAG.Model_ID = mdl.ID OR mdl.ID IS NULL)  
            AND (vAG.Model_Name = mdl.Name OR mdl.Name IS NULL)  
        INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@EntityIDs) ent  
            ON (vAG.Entity_MUID = ent.MUID OR ent.MUID IS NULL)  
            AND (vAG.Entity_ID = ent.ID OR ent.ID IS NULL)  
            AND (vAG.Entity_Name = ent.Name OR ent.Name IS NULL)  
        INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@AttributeGroupIDs) ag  
            ON (vAG.MUID = ag.MUID OR ag.MUID IS NULL)  
            AND (vAG.ID = ag.ID OR ag.ID IS NULL)  
            AND (vAG.Name = ag.Name OR ag.Name IS NULL)  
        INNER JOIN mdm.udfMetadataGetSearchCriteriaMemberTypes(@MemberTypeIDs) mt  
            ON (vAG.MemberType_ID = mt.ID OR mt.ID IS NULL)  
        INNER JOIN mdm.tblSecurityPrivilege tPriv  
            ON tPriv.ID = acl.Privilege_ID  
    ORDER BY vAG.Model_ID, vAG.Entity_ID, vAG.MemberType_ID, vAG.SortOrder  
   FOR XML PATH('AttributeGroup'), ELEMENTS XSINIL  
   ))  
  
    RETURN COALESCE(@return, N'');  
  
END; --function
GO
