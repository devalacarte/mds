SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
/*  
Returns a serialized Model business entity object with just Identifiers.  
*/  
CREATE FUNCTION [mdm].[udfMetadataModelGetIdentifiersXML]  
(  
    @User_ID        INT,  
    @SearchCriteria XML = NULL  
)  
/*WITH*/  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
    DECLARE	@SearchOption   SMALLINT,  
		    @ModelIDs		XML,  
		    @Return			XML;  
  
    /*  
    SearchOption  
        UserDefinedObjectsOnly = 0,  
        SystemObjectsOnly = 1  
        BothUserDefinedAndSystemObjects = 2  
    */  
  
    SELECT   
       @SearchOption = mdm.udfMetadataSearchOptionGetByName(T.Criteria.value('SearchOption[1]', 'nvarchar(50)'))  
    FROM @SearchCriteria.nodes('/MetadataSearchCriteria') T(Criteria)   
    SET @SearchOption = ISNULL(@SearchOption, 0)  
  
    SELECT @ModelIDs = @SearchCriteria.query('//Models');  
  
    -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
    -- may fail (sometimes silently) to deserialize out-of-order columns.  
    SELECT @Return = CONVERT(XML, (  
        SELECT  
            -- Members inherited from Core.BusinessEntities.BusinessEntity   
            [AuditInfo/CreatedDateTime] = vMod.EnteredUser_DTM,  
            [AuditInfo/CreatedUserId/Id] = vMod.EnteredUser_ID,  
            [AuditInfo/CreatedUserId/Muid] = vMod.EnteredUser_MUID,  
            [AuditInfo/CreatedUserId/Name] = vMod.EnteredUser_UserName,  
            [AuditInfo/UpdatedDateTime] = vMod.LastChgUser_DTM,  
            [AuditInfo/UpdatedUserId/Id] = vMod.LastChgUser_ID,  
            [AuditInfo/UpdatedUserId/Muid] = vMod.LastChgUser_MUID,  
            [AuditInfo/UpdatedUserId/Name] = vMod.LastChgUser_UserName,  
            [Identifier/Id] = vMod.ID,  
            [Identifier/Muid] = vMod.MUID,  
            [Identifier/Name] = vMod.Name,  
            [Permission] = tPriv.Name,  
  
            -- Core.BusinessEntities.Model members        
            [IsAdministrator] = acl.IsAdministrator,     
            [IsSystem] = vMod.IsSystem  
        FROM  
           mdm.udfSecurityUserModelList(@User_ID) acl  
           INNER JOIN mdm.viw_SYSTEM_SCHEMA_MODEL vMod   
	           ON acl.ID = vMod.ID  
	           AND ((vMod.IsSystem = @SearchOption AND @SearchOption <> 2) OR @SearchOption = 2)  
         INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
            ON (vMod.MUID =mdl.MUID OR mdl.MUID IS NULL)  
            AND (vMod.ID = mdl.ID OR mdl.ID IS NULL)  
            AND (vMod.Name = mdl.Name OR mdl.Name IS NULL)  
         INNER JOIN mdm.tblSecurityPrivilege tPriv  
            ON tPriv.ID = acl.Privilege_ID  
        ORDER BY  
         vMod.Name  
        FOR XML PATH('Model'), ELEMENTS XSINIL))  
  
    RETURN COALESCE(@Return, N'');  
  
END --proc
GO
