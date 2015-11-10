SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMetadataVersionGetXML]   
(  
    @User_ID        INT,  
    @SearchCriteria XML = NULL,  
    @ResultCriteria XML = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
  
    SET NOCOUNT ON  
  
    /*  
    SearchOption  
        UserDefinedObjectsOnly = 0,  
        SystemObjectsOnly = 1  
        BothUserDefinedAndSystemObjects = 2  
  
    ResultOption  
        None = 0  
        Identifiers = 1  
        Details = 2  
    */  
  
    DECLARE   
        @SearchOption SMALLINT,  
        @ResultOption SMALLINT,  
        @ModelIDs        XML,  
        @VersionIDs        XML,  
        @return XML;  
  
    DECLARE @tblVersions TABLE (  
        RowNumber INT IDENTITY (1, 1) PRIMARY KEY CLUSTERED NOT NULL  
          
        ,[Identifier/Id] [int] NOT NULL  
        ,[Identifier/Muid] [uniqueidentifier] NOT NULL  
        ,[Identifier/Name] [nvarchar](50) NOT NULL  
  
        ,[Identifier/ModelId/Id] [int] NOT NULL  
        ,[Identifier/ModelId/Muid] [uniqueidentifier] NOT NULL  
        ,[Identifier/ModelId/Name] [nvarchar](50) NOT NULL  
  
        ,[IsSystem] [nvarchar] (5) NULL  
        ,[Description] [nvarchar](500) NULL  
        ,[VersionStatus] [nvarchar](250) NULL  
        ,[ValidationStatus] [nvarchar](250) NULL  
        ,[VersionNumber] [int] NOT NULL  
  
        ,[VersionFlagId/Id] [int] NULL  
        ,[VersionFlagId/Muid] [uniqueidentifier] NULL  
        ,[VersionFlagId/Name] [nvarchar](50) NULL  
  
        ,[CopiedFromVersionId/Id] [int] NULL  
        ,[CopiedFromVersionId/Muid] [uniqueidentifier] NULL  
        ,[CopiedFromVersionId/Name] [nvarchar](60) NULL  
  
        ,[Permission] [nvarchar] (10) NULL  
  
        ,[AuditInfo/CreatedUserId/Id] [int] NULL  
        ,[AuditInfo/CreatedUserId/Muid] [uniqueidentifier] NULL  
        ,[AuditInfo/CreatedUserId/Name] [nvarchar](50) NULL  
        ,[AuditInfo/CreatedDateTime] [datetime2](3) NULL  
          
        ,[AuditInfo/UpdatedUserId/Id] [int] NULL  
        ,[AuditInfo/UpdatedUserId/Muid] [uniqueidentifier] NULL  
        ,[AuditInfo/UpdatedUserId/Name] [nvarchar](50) NULL  
        ,[AuditInfo/UpdatedDateTime] [datetime2](3) NULL  
  
    )  
  
    SELECT   
       @SearchOption = mdm.udfMetadataSearchOptionGetByName(T.Criteria.value('SearchOption[1]', 'nvarchar(50)'))  
    FROM @SearchCriteria.nodes('/MetadataSearchCriteria') T(Criteria)   
  
    SELECT   
       @ResultOption = mdm.udfMetadataResultOptionGetByName(T.Criteria.value('Versions[1]', 'nvarchar(50)'))  
    FROM @ResultCriteria.nodes('/MetadataResultOptions') T(Criteria)   
  
    SET @SearchOption = COALESCE(@SearchOption, 0)  
  
  
        SELECT @ModelIDs = @SearchCriteria.query('//Models');  
        SELECT @VersionIDs = @SearchCriteria.query('//Versions');  
  
        INSERT INTO @tblVersions  
             SELECT  
                [Identifier/Id] = vVer.ID,  
                [Identifier/Muid] = vVer.MUID,  
                [Identifier/Name] = vVer.Name,  
                  
                [Identifier/ModelId/Id] = vVer.Model_ID,  
                [Identifier/ModelId/Muid] = vVer.Model_MUID,  
                [Identifier/ModelId/Name] = vVer.Model_Name,  
  
                [IsSystem] = vVer.Model_IsSystem,  
                [Description] = vVer.Description,  
                [VersionStatus] = vVer.Status,  
                [ValidationStatus] = 'NotSpecified',  
                [VersionNumber] = vVer.VersionNbr,  
  
                [VersionFlagId/Id] = vVer.VersionFlag_ID,  
                [VersionFlagId/Muid] = vVer.Flag_MUID,  
                [VersionFlagId/Name] = vVer.Flag,  
                  
                [CopiedFromVersionId/Id] = vVer.CopiedFrom_ID,  
                [CopiedFromVersionId/Muid] = vVer.CopiedFrom_MUID,  
                [CopiedFromVersionId/Name] = vVer.CopiedFrom,  
  
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
  
                [AuditInfo/CreatedUserId/Id] = vVer.EnteredUser_ID,  
                [AuditInfo/CreatedUserId/Muid] = vVer.EnteredUser_MUID,  
                [AuditInfo/CreatedUserId/Name] = vVer.EnteredUser_UserName,  
                [AuditInfo/CreatedDateTime] = vVer.EnteredUser_DTM,  
  
                [AuditInfo/UpdatedUserId/Id] = vVer.LastChgUser_ID,  
                [AuditInfo/UpdatedUserId/Muid] = vVer.LastChgUser_MUID,  
                [AuditInfo/UpdatedUserId/Name] = vVer.LastChgUser_UserName,  
                [AuditInfo/UpdatedDateTime] = vVer.LastChgUser_DTM  
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
          ORDER BY vVer.Model_MUID, vVer.VersionNbr;  
  
        --Determine validation status of each version.  
        DECLARE @Counter INT = 1;  
        DECLARE @MaxCounter INT = (SELECT MAX(RowNumber) FROM @tblVersions);  
        DECLARE @VersionID INT;  
        DECLARE @IsValidated INT;  
  
        WHILE @Counter <= @MaxCounter  
        BEGIN  
            SELECT @VersionID = [Identifier/Id]  FROM @tblVersions WHERE [RowNumber] = @Counter  
            EXECUTE @IsValidated = mdm.udpVersionValidationStatusGet @VersionID  
  
            UPDATE @tblVersions  
            SET    [ValidationStatus] = CASE WHEN @IsValidated = 1 THEN 'Validated' ELSE 'NotValidated' END  
            WHERE  [RowNumber] = @Counter  
  
            SET @Counter += 1;  
        END;  
  
        -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
        -- may fail (sometimes silently) to deserialize out-of-order columns.  
        SELECT @return = CONVERT(XML, (  
            SELECT  
                -- Members inherited from Core.BusinessEntities.BusinessEntity   
                 [AuditInfo/CreatedDateTime]  
                ,[AuditInfo/CreatedUserId/Id]  
                ,[AuditInfo/CreatedUserId/Muid]  
                ,[AuditInfo/CreatedUserId/Name]  
                ,[AuditInfo/UpdatedDateTime]  
                ,[AuditInfo/UpdatedUserId/Id]  
                ,[AuditInfo/UpdatedUserId/Muid]  
                ,[AuditInfo/UpdatedUserId/Name]  
                ,[Identifier/Id]  
                ,[Identifier/Muid]  
                ,[Identifier/Name]  
                ,[Identifier/ModelId/Id]  
                ,[Identifier/ModelId/Muid]  
                ,[Identifier/ModelId/Name]  
                ,[Permission]  
                  
                -- Core.BusinessEntities.Version members                 
                ,[CopiedFromVersionId/Id]  
                ,[CopiedFromVersionId/Muid]  
                ,[CopiedFromVersionId/Name]  
                ,[Description]  
                --,[IsSystem] -- unused?  
                ,[ValidationStatus]  
                ,[VersionFlagId/Id]  
                ,[VersionFlagId/Muid]  
                ,[VersionFlagId/Name]  
                ,[VersionNumber]  
                ,[VersionStatus]  
            FROM    @tblVersions  
            FOR XML PATH('Version'), ELEMENTS XSINIL))  
  
        SELECT @return  
          FOR XML PATH(''), ELEMENTS XSINIL, ROOT('ArrayOfVersion')  
  
SET NOCOUNT OFF  
END --proc
GO
