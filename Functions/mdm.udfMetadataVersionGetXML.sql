SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Returns a serialized Version business entity object.  
  
select * from mdm.viw_SYSTEM_SCHEMA_VERSION vVer   
  
SELECT mdm.udfMetadataVersionGetXML(  
    1  
    ,NULL  
    ,'<Versions><Identifier><Muid>564A23C2-7CCD-43F5-8932-2B58E49CDA33</Muid></Identifier></Versions>'  
    ,2  
    ,0  
)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataVersionGetXML]  
(  
    @User_ID         INT,  
    @ModelIDs        XML = NULL,  
    @VersionIDs      XML = NULL,  
    @ResultOption    SMALLINT,  
    @SearchOption    SMALLINT  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS  
  
BEGIN  
    DECLARE @return XML  
  
    -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
    -- may fail (sometimes silently) to deserialize out-of-order columns.  
    SELECT @return = CONVERT(XML, (  
         SELECT  
            -- Members inherited from Core.BusinessEntities.BusinessEntity   
            [AuditInfo/CreatedDateTime] = vVer.EnteredUser_DTM,  
            [AuditInfo/CreatedUserId/Id] = vVer.EnteredUser_ID,  
            [AuditInfo/CreatedUserId/Muid] = vVer.EnteredUser_MUID,  
            [AuditInfo/CreatedUserId/Name] = vVer.EnteredUser_UserName,  
            [AuditInfo/UpdatedDateTime] = vVer.LastChgUser_DTM,  
            [AuditInfo/UpdatedUserId/Id] = vVer.LastChgUser_ID,  
            [AuditInfo/UpdatedUserId/Muid] = vVer.LastChgUser_MUID,  
            [AuditInfo/UpdatedUserId/Name] = vVer.LastChgUser_UserName,  
            [Identifier/Id] = vVer.ID,  
            [Identifier/Muid] = vVer.MUID,  
            [Identifier/Name] = vVer.Name,  
            [Identifier/ModelId/Id] = vVer.Model_ID,  
            [Identifier/ModelId/Muid] = vVer.Model_MUID,  
            [Identifier/ModelId/Name] = vVer.Model_Name,  
            [Permission] =    
                CASE  
                    -- If the status is Committed (3) then the version has been approved and cannot be updated by anyone  
                    WHEN vVer.Status_ID = 3 THEN 'ReadOnly'  
                    -- If the status is Locked (2) then the version is locked for review and can only be updated by a Model administrator  
                    WHEN vVer.Status_ID = 2 THEN   
                        CASE  
                            WHEN acl.IsAdministrator = 1 THEN tPriv.Name -- Will be Update  
                            ELSE 'ReadOnly'  
                        END  
                    -- If the status is Open (1) then return update.  
                    ELSE 'Update'  
                END,  
  
            -- Core.BusinessEntities.VersionFlag members                 
            [CopiedFromVersionId/Id] = vVer.CopiedFrom_ID,  
            [CopiedFromVersionId/Muid] = vVer.CopiedFrom_MUID,  
            [CopiedFromVersionId/Name] = vVer.CopiedFrom,  
            [Description] = vVer.Description,  
            --[IsSystem] = vVer.Model_IsSystem, -- unused?  
            [ValidationStatus] = 'NotSpecified',  
            [VersionFlagId/Id] = vVer.VersionFlag_ID,  
            [VersionFlagId/Muid] = vVer.Flag_MUID,  
            [VersionFlagId/Name] = vVer.Flag,  
            [VersionNumber] = vVer.VersionNbr,  
            [VersionStatus] = vVer.Status  
         FROM  
            mdm.udfSecurityUserModelList(@User_ID) acl  
            INNER JOIN mdm.viw_SYSTEM_SCHEMA_VERSION vVer   
                ON acl.ID = vVer.Model_ID  
                AND vVer.Model_IsSystem = CASE @SearchOption WHEN 2 THEN vVer.Model_IsSystem ELSE @SearchOption END  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
                ON vVer.Model_MUID = ISNULL(mdl.MUID, vVer.Model_MUID)   
                AND vVer.Model_ID = ISNULL(mdl.ID, vVer.Model_ID)   
                AND vVer.Model_Name = ISNULL(mdl.Name, vVer.Model_Name)  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@VersionIDs) ver  
                ON vVer.MUID = ISNULL(ver.MUID, vVer.MUID)   
                AND vVer.ID = ISNULL(ver.ID, vVer.ID)   
                AND vVer.Name = ISNULL(ver.Name, vVer.Name)  
            INNER JOIN mdm.tblSecurityPrivilege tPriv  
               ON tPriv.ID = acl.Privilege_ID  
          ORDER BY vVer.Model_MUID, vVer.VersionNbr  
         FOR XML PATH('Version'), ELEMENTS XSINIL  
         ))  
  
    RETURN COALESCE(@return, N'');  
END
GO
