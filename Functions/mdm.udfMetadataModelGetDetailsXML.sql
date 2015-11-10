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
Returns a serialized Model business entity object.  
*/  
CREATE FUNCTION [mdm].[udfMetadataModelGetDetailsXML]  
(  
    @User_ID        INT,  
    @SearchCriteria XML = NULL  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
    DECLARE @SearchOption           SMALLINT,  
            @ResultOption           SMALLINT,  
            @ModelIDs               XML,  
            @EntityIDs              XML,  
            @ExplicitHierarchyIds   XML,  
            @DerivedHierarchyIds    XML,  
            @VersionIDs             XML,  
            @VersionFlagsIDs        XML,  
            @MemberTypeIDs          XML,  
            @AttributeIDs           XML,  
            @AttributeGroupID       XML,  
            @Return                 XML;  
  
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
    SET @ResultOption = 2 --Details  
  
    SELECT @ModelIDs = @SearchCriteria.query('//Models');  
    SELECT @EntityIDs = @SearchCriteria.query('//Entities');  
    SELECT @ExplicitHierarchyIds = @SearchCriteria.query('//ExplicitHierarchies');  
    SELECT @DerivedHierarchyIds = @SearchCriteria.query('//DerivedHierarchies');  
    SELECT @VersionIDs = @SearchCriteria.query('//Versions');  
    SELECT @VersionFlagsIDs = @SearchCriteria.query('//VersionFlags');  
    SELECT @MemberTypeIDs = @SearchCriteria.query('//MemberTypes');  
    SELECT @AttributeIDs = @SearchCriteria.query('//Attributes');  
    SELECT @AttributeGroupID = @SearchCriteria.query('//AttributeGroups');  
  
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
            [DerivedHierarchies] = mdm.udfMetadataDerivedHierarchiesGetXML(@User_ID,   
                            N'<Models><Identifier><Muid>' + cast(vMod.MUID as NVARCHAR(50)) + N'</Muid></Identifier></Models>',   
                            @DerivedHierarchyIds,   
                            @ResultOption,@SearchOption),  
            [Entities] = mdm.udfMetadataEntityGetXML(@User_ID,   
                            N'<Models><Identifier><Muid>' + cast(vMod.MUID as NVARCHAR(50)) + N'</Muid></Identifier></Models>',   
                            @EntityIDs,   
                            @ExplicitHierarchyIds,   
                            @MemberTypeIDs,   
                            @AttributeIDs,   
                            @AttributeGroupID,   
                            @ResultOption,@SearchOption),  
            [ExplicitHierarchies] = mdm.udfMetadataExplicitHierarchiesGetXML(@User_ID,   
                            @ModelIDs,   
                            @EntityIDs,   
                            @ExplicitHierarchyIds,   
                            @ResultOption, @SearchOption),  
            [IsAdministrator] = acl.IsAdministrator,  
            [IsSystem] = vMod.IsSystem,      
            [VersionFlags] = mdm.udfMetadataVersionFlagsGetXML(@User_ID,   
                            N'<Models><Identifier><Muid>' + cast(vMod.MUID as NVARCHAR(50)) + N'</Muid></Identifier></Models>',   
                            @VersionFlagsIDs,   
                            @ResultOption,@SearchOption),  
            [Versions] = mdm.udfMetadataVersionGetXML(@User_ID,   
                            N'<Models><Identifier><Muid>' + cast(vMod.MUID as NVARCHAR(50)) + N'</Muid></Identifier></Models>',   
                            @VersionIDs,   
                            @ResultOption,@SearchOption)  
        FROM  
           mdm.udfSecurityUserModelList(@User_ID) acl  
           INNER JOIN mdm.viw_SYSTEM_SCHEMA_MODEL vMod   
               ON acl.ID = vMod.ID  
               AND ((vMod.IsSystem = @SearchOption AND @SearchOption <> 2) OR @SearchOption = 2)  
         INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
            ON   
             (vMod.MUID = mdl.MUID OR mdl.MUID IS NULL)  
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
