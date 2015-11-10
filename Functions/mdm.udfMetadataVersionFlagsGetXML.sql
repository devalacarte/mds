SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Returns a serialized Version Flag business entity object.  
  
    select mdm.udfMetadataVersionFlagsGetXML(1,NULL, NULL,2, 2)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataVersionFlagsGetXML]  
(  
    @User_ID         INT,  
    @ModelIDs        XML = NULL,  
    @VersionFlagIDs  XML = NULL,  
    @ResultOption    SMALLINT,  
    @SearchOption    SMALLINT  
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
            [AuditInfo/CreatedDateTime] = vFlg.EnteredUser_DTM,  
            [AuditInfo/CreatedUserId/Id] = vFlg.EnteredUser_ID,  
            [AuditInfo/CreatedUserId/Muid] = vFlg.EnteredUser_MUID,  
            [AuditInfo/CreatedUserId/Name] = vFlg.EnteredUser_UserName,  
            [AuditInfo/UpdatedDateTime] = vFlg.LastChgUser_DTM,  
            [AuditInfo/UpdatedUserId/Id] = vFlg.LastChgUser_ID,  
            [AuditInfo/UpdatedUserId/Muid] = vFlg.LastChgUser_MUID,  
            [AuditInfo/UpdatedUserId/Name] = vFlg.LastChgUser_UserName,  
            [Identifier/Id] = vFlg.ID,  
            [Identifier/Muid] = vFlg.MUID,  
            [Identifier/Name] = vFlg.Name,  
            [Identifier/ModelId/Id] = vFlg.Model_ID,  
            [Identifier/ModelId/Muid] = vFlg.Model_MUID,  
            [Identifier/ModelId/Name] = vFlg.Model_Name,  
            [Permission] = tPriv.Name,  
  
            -- Core.BusinessEntities.VersionFlag members                 
            [AssignedVersionId/Id] = vFlg.AssignedVersion_ID,  
            [AssignedVersionId/Muid] = vFlg.AssignedVersion_MUID,  
            [AssignedVersionId/Name] = vFlg.AssignedVersion_Name,  
            [Description] = vFlg.Description,  
            [IsCommittedOnly] = vFlg.IsCommittedOnly  
         FROM  
            mdm.udfSecurityUserModelList(@User_ID) acl  
            INNER JOIN mdm.viw_SYSTEM_SCHEMA_VERSION_FLAGS vFlg   
                ON acl.ID = vFlg.Model_ID  
                AND vFlg.Status_ID = 1  
                AND vFlg.Model_IsSystem = CASE @SearchOption WHEN 2 THEN vFlg.Model_IsSystem ELSE @SearchOption END  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@ModelIDs) mdl  
                ON ((mdl.MUID IS NULL) OR (vFlg.Model_MUID = mdl.MUID))  
                AND ((mdl.ID IS NULL) OR (vFlg.Model_ID = mdl.ID))  
                AND ((mdl.Name IS NULL) OR (vFlg.Model_Name = mdl.Name))  
            INNER JOIN mdm.udfMetadataGetSearchCriteriaIds(@VersionFlagIDs) flg  
                ON ((flg.MUID IS NULL) OR (vFlg.MUID = flg.MUID))  
                AND ((flg.ID IS NULL) OR (vFlg.ID = flg.ID))  
                AND ((flg.Name IS NULL) OR (vFlg.Name = flg.Name))  
            INNER JOIN mdm.tblSecurityPrivilege tPriv  
               ON tPriv.ID = acl.Privilege_ID  
          ORDER BY vFlg.Model_MUID, vFlg.Name  
         FOR XML PATH('VersionFlag'), ELEMENTS XSINIL  
         ))  
  
    RETURN COALESCE(@return, N'');  
END
GO
