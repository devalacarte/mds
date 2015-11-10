SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Returns a serialized MemberType business entity object.  
  
SELECT mdm.udfMetadataMemberTypeGetXML(  
    1  
    ,null  
    ,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
    ,'<MemberTypes><MemberType>Leaf</MemberType></MemberTypes>'  
    ,null  
    ,null  
    ,2  
    ,0  
)  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataMemberTypeGetXML]  
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
   DECLARE @return XML  
  
    -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
    -- may fail (sometimes silently) to deserialize out-of-order columns.  
    SELECT @return = CONVERT(XML, (  
        SELECT      
            -- Members inherited from Core.BusinessEntities.BusinessEntity   
            [Identifier/Id] = tEntMT.ID,  
            [Identifier/Muid] = CONVERT(UNIQUEIDENTIFIER, 0x0),  
            [Identifier/Name] = tEntMT.Name,  
            [Permission] = tPriv.Name,  
  
            -- Core.BusinessEntities.EntityMemberType members           
            [AttributeGroups] = mdm.udfMetadataAttributeGroupGetXML(  
                    @User_ID,   
                    @ModelIDs,   
                    @EntityIDs,   
                    N'<MemberTypes><MemberType>' + tEntMT.Name + N'</MemberType></MemberTypes>',   
                    @AttributeIDs,   
                    @AttributeGroupIDs,  
                    @ResultOption,   
                    @SearchOption),  
            [Attributes] = mdm.udfMetadataAttributeGetXML(  
                    @User_ID,   
                    @ModelIDs,   
                    @EntityIDs,   
                    N'<MemberTypes><MemberType>' + tEntMT.Name + N'</MemberType></MemberTypes>',   
                    @AttributeIDs,   
                    @AttributeGroupIDs,  
                    @ResultOption,   
                    @SearchOption),  
            [EntityId/Id] = vEnt.ID,  
            [EntityId/Muid] = vEnt.MUID,  
            [EntityId/Name] = vEnt.Name,  
            [Type] = tEntMT.Name  
          FROM      
            mdm.udfSecurityUserMemberTypeList(@User_ID, NULL, NULL) acl  
              INNER JOIN mdm.viw_SYSTEM_SCHEMA_ENTITY vEnt   
                ON vEnt.ID = acl.Entity_ID  
            INNER JOIN mdm.tblEntityMemberType tEntMT  
                ON acl.ID = tEntMT.ID  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
                ON vEnt.Model_MUID = ISNULL(mdl.MUID, vEnt.Model_MUID)   
                AND vEnt.Model_ID = ISNULL(mdl.ID, vEnt.Model_ID)   
                AND vEnt.Model_Name = ISNULL(mdl.Name, vEnt.Model_Name)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@EntityIDs) ent  
                ON vEnt.MUID = ISNULL(ent.MUID, vEnt.MUID)   
                AND vEnt.ID = ISNULL(ent.ID, vEnt.ID)   
                AND vEnt.Name = ISNULL(ent.Name, vEnt.Name)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaMemberTypes(@MemberTypeIDs) mt  
                ON  acl.ID = ISNULL(mt.ID, acl.ID)  
            INNER JOIN mdm.tblSecurityPrivilege tPriv  
                ON tPriv.ID = acl.Privilege_ID  
          ORDER BY acl.Entity_ID, acl.ID  
         FOR XML PATH('EntityMemberType'), ELEMENTS XSINIL  
      ))  
  
    RETURN COALESCE(@return, N'');  
END
GO
