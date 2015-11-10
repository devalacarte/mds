SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Returns a serialized MetadataAttribute business entity object.  
  
SELECT mdm.udfMetadataAttributeGetDetailsXML(  
    2  
    ,null  
    ,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
    ,'<MemberTypes><MemberType>Leaf</MemberType></MemberTypes>'  
    ,null  
    ,null  
    ,1  
    ,0  
)  
  
    ,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
  
SELECT mdm.udfMetadataAttributeGetDetailsXML(  
    1  
    ,'<Models><Identifier><Name>Product</Name></Identifier></Models>'  
    ,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
    ,null  
    ,null  
    ,'<AttributeGroups><Identifier><Muid>FACE96DE-00F8-4368-B375-B9095D90DA02</Muid></Identifier></AttributeGroups>'  
    ,1  
    ,0  
)  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataAttributeGetDetailsXML]  
(  
    @User_ID            INT,  
    @ModelIDs           XML = NULL,  
    @EntityIDs          XML = NULL,  
    @MemberTypeIDs      XML = NULL,  
    @AttributeIDs       XML = NULL,  
    @AttributeGroupID   XML = NULL,  
    @ResultOption       SMALLINT,  
    @SearchOption       SMALLINT  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
DECLARE @return         XML;  
DECLARE @TempID         INT;  
DECLARE @TempName       NVARCHAR(MAX);  
DECLARE @TempMUID       UNIQUEIDENTIFIER;  
--DECLARE @EmptyMuid UNIQUEIDENTIFIER SET @EmptyMuid = CONVERT(UNIQUEIDENTIFIER, 0x0);  
  
SET @SearchOption = ISNULL(@SearchOption, 0)  
  
   -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
   -- may fail (sometimes silently) to deserialize out-of-order columns.  
   SELECT @return = CONVERT(XML, (  
    SELECT     
        -- Members inherited from Core.BusinessEntities.BusinessEntity   
        [AuditInfo/CreatedDateTime] = vAtt.EnteredUser_DTM,  
        [AuditInfo/CreatedUserId/Id] = vAtt.EnteredUser_ID,  
        [AuditInfo/CreatedUserId/Muid] = vAtt.EnteredUser_MUID,  
        [AuditInfo/CreatedUserId/Name] = vAtt.EnteredUser_UserName,  
        [AuditInfo/UpdatedDateTime] = vAtt.LastChgUser_DTM,  
        [AuditInfo/UpdatedUserId/Id] = vAtt.LastChgUser_ID,  
        [AuditInfo/UpdatedUserId/Muid] = vAtt.LastChgUser_MUID,  
        [AuditInfo/UpdatedUserId/Name] = vAtt.LastChgUser_UserName,  
        [Identifier/Id] = vAtt.Attribute_ID,  
        [Identifier/Muid] = vAtt.Attribute_MUID,  
        [Identifier/Name] = vAtt.Attribute_Name,  
        [Identifier/ModelId/Id] = vAtt.Model_ID,  
        [Identifier/ModelId/Muid] = vAtt.Model_MUID,  
        [Identifier/ModelId/Name] = vAtt.Model_Name,  
        [Identifier/EntityId/Id] = vAtt.Entity_ID,  
        [Identifier/EntityId/Muid] = vAtt.Entity_MUID,  
        [Identifier/EntityId/Name] = vAtt.Entity_Name,  
        [Identifier/MemberType] = vAtt.Attribute_MemberType_Name,  
        [Permission] = tPriv.Name,  
         
        -- Core.BusinessEntities.MetadataAttribute members  
        [AttributeType] = Attribute_Type_Name,  
        [ChangeTrackingGroup] = Attribute_ChangeTrackingGroup,  
        [DataType] = Attribute_DataType_Name,  
        [DataTypeInformation] = Attribute_DataType_Information,  
        [DisplayWidth] = Attribute_DisplayWidth,  
        [DomainEntityId/Id] = Attribute_DBAEntity_ID,  
        [DomainEntityId/Muid] = Attribute_DBAEntity_MUID,  
        [DomainEntityId/Name] = Attribute_DBAEntity_Name,  
        [DomainEntityIsFlat] = Attribute_DBAEntity_IsFlat,  
        [DomainEntityPermission] = ISNULL(tDBAPriv.Name,N'NotSpecified'),  
        [EntityPhysicalTableName] = vAtt.Entity_PhysicalTableName,  
        [EntityTableName] = vAtt.Entity_TableName,  
        [FullyQualifiedName] = Attribute_FullyQualifiedName,  
        [InputMaskId/Id] = Attribute_DataMask_ID,  
        [InputMaskId/Name] = Attribute_DataMask_Name,  
        [IsCode] = vAtt.Attribute_IsCode,  
        [IsName] = vAtt.Attribute_IsName,    
        [IsReadOnly] = vAtt.Attribute_IsReadOnly,      
        [IsSystem] = vAtt.Attribute_IsSystem,      
        [SortOrder] = ISNULL(vAGA.Attribute_SortOrder, vAtt.Attribute_SortOrder),  
        [SystemName] = vAtt.Attribute_Column  
    FROM    mdm.udfSecurityUserAttributeList(@User_ID, NULL, NULL, NULL) acl  
        INNER JOIN mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES vAtt   
            ON    acl.ID = vAtt.Attribute_ID   
            AND vAtt.Attribute_Type_ID <> 3 -- System  
        INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
            ON (vAtt.Model_MUID = mdl.MUID OR mdl.MUID IS NULL)  
            AND (vAtt.Model_ID = mdl.ID OR mdl.ID IS NULL)  
            AND (vAtt.Model_Name = mdl.Name OR mdl.Name IS NULL)  
        INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@EntityIDs) ent  
            ON (vAtt.Entity_MUID = ent.MUID OR ent.MUID IS NULL)  
            AND (vAtt.Entity_ID = ent.ID OR ent.ID IS NULL)  
            AND (vAtt.Entity_Name = ent.Name OR ent.Name IS NULL)  
        INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@AttributeIDs) att  
            ON (vAtt.Attribute_MUID = att.MUID OR att.MUID IS NULL)  
            AND (vAtt.Attribute_ID = att.ID OR att.ID IS NULL)  
            AND (vAtt.Attribute_Name = att.Name OR att.Name IS NULL)  
        INNER JOIN mdm.udfMetadataGetSearchCriteriaMemberTypes(@MemberTypeIDs) mt  
            ON (vAtt.Attribute_MemberType_ID = mt.ID OR mt.ID IS NULL)  
         INNER JOIN mdm.tblSecurityPrivilege tPriv  
            ON tPriv.ID = acl.Privilege_ID  
        LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ENTITY  DBASec   
            ON vAtt.Attribute_DBAEntity_ID = DBASec.ID   
            AND vAtt.Attribute_MemberType_ID = DBASec.DBA_MemberType_ID  
            AND DBASec.User_ID = @User_ID  
        LEFT JOIN mdm.tblSecurityPrivilege tDBAPriv  
            ON tDBAPriv.ID = DBASec.Privilege_ID  
        LEFT JOIN mdm.viw_SYSTEM_SCHEMA_ATTRIBUTEGROUPS_ATTRIBUTES vAGA  
            ON vAtt.Attribute_ID = vAGA.Attribute_ID  
            AND vAGA.AttributeGroup_MUID IN (SELECT MUID FROM mdm.udfMetadataGetSearchCriteriaIds(@AttributeGroupID) ag)  
            AND vAGA.Entity_ID = vAtt.Entity_ID  
            AND vAGA.Model_ID = vAtt.Model_ID  
            AND vAGA.AttributeMemberType_ID = vAtt.Attribute_MemberType_ID  
         WHERE  
            vAGA.AttributeGroup_MUID IN (SELECT MUID FROM mdm.udfMetadataGetSearchCriteriaIds(@AttributeGroupID) ag)  
            OR  
            (vAGA.AttributeGroup_MUID IS NULL AND EXISTS (SELECT 1 FROM mdm.udfMetadataGetSearchCriteriaIds(@AttributeGroupID) ag WHERE MUID IS NULL))  
    ORDER BY vAtt.Model_ID, vAtt.Entity_ID, vAtt.Attribute_MemberType_ID, ISNULL(vAGA.Attribute_SortOrder, vAtt.Attribute_SortOrder), vAtt.Attribute_ID  
   FOR XML PATH('MetadataAttribute'), ELEMENTS XSINIL  
   ))  
  
    RETURN COALESCE(@return, N'');  
  
END; --function
GO
