SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMetadataMemberTypeGetPermissionsXML]  
(  
    @User_ID        INT,  
    @SearchCriteria XML = NULL,  
    @ResultCriteria XML = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
  
    SET NOCOUNT ON  
  
    DECLARE @ModelIDs           XML,  
            @EntityIDs          XML,  
            @MemberTypeIDs      XML,  
            @Result             XML;  
  
    SELECT @ModelIDs = @SearchCriteria.query('//Models');  
    SELECT @EntityIDs = @SearchCriteria.query('//Entities');  
    SELECT @MemberTypeIDs = @SearchCriteria.query('//MemberTypes');  
                  
    -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
    -- may fail (sometimes silently) to deserialize out-of-order columns.  
    SELECT @Result = CONVERT(XML, (  
          SELECT      
            -- Members inherited from Core.BusinessEntities.BusinessEntity   
            [Identifier/Id] = tEntMT.ID,  
            [Identifier/Muid] = CONVERT(UNIQUEIDENTIFIER, 0x0),  
            [Identifier/Name] = tEntMT.Name,  
            [Permission] = tPriv.Name,  
  
            -- Core.BusinessEntities.EntityMemberType members                 
            [EntityId/Id] = vEnt.ID,  
            [EntityId/Muid] = vEnt.MUID,  
            [EntityId/Name] = vEnt.Name,  
            [Type] = tEntMT.Name  
          FROM    mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE acl  
            INNER JOIN mdm.viw_SYSTEM_SCHEMA_ENTITY vEnt   
                ON vEnt.ID = acl.Entity_ID  
            INNER JOIN mdm.tblEntityMemberType tEntMT  
                ON acl.ID = tEntMT.ID  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
                ON (vEnt.Model_MUID = mdl.MUID OR mdl.MUID IS NULL)   
                AND (vEnt.Model_ID = mdl.ID OR mdl.ID IS NULL)   
                AND (vEnt.Model_Name = mdl.Name OR mdl.Name IS NULL)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@EntityIDs) ent  
                ON (vEnt.MUID = ent.MUID OR ent.MUID IS NULL)   
                AND (vEnt.ID = ent.ID OR ent.ID IS NULL)   
                AND (vEnt.Name = ent.Name OR ent.Name IS NULL)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaMemberTypes(@MemberTypeIDs) mt  
                ON (acl.ID = mt.ID OR mt.ID IS NULL)  
            INNER JOIN mdm.tblSecurityPrivilege tPriv  
                ON tPriv.ID = acl.Privilege_ID  
          WHERE acl.Privilege_ID <> 1 AND acl.User_ID = @User_ID  
          ORDER BY tEntMT.Name, vEnt.Name  
         FOR XML PATH('EntityMemberType'), ELEMENTS XSINIL  
      ))  
  
    SELECT @Result  
        FOR XML PATH(''), ELEMENTS XSINIL, ROOT('ArrayOfEntityMemberType')  
          
END
GO
