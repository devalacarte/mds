SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Returns the specified model privileges.  
      
    EXEC udpSecurityPrivilegesModelGet   
        @Permission_ID          = NULL,  
        @Model_MUID             = NULL,  
        @Model_Name             = NULL,  
        @Securable_MUID         = NULL,  
        @Securable_Name         = NULL,  
        @Principal_MUID         = NULL,   
        @Principal_Name         = NULL,  
        @PrincipalType_ID       = NULL,      
        @RoleAccessIdentifiers  = NULL  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesModelGet]  
(  
    @Permission_ID          INT = NULL,  
    @Model_MUID             UNIQUEIDENTIFIER = NULL,  
    @Model_Name             NVARCHAR(100) = NULL,  
    @Securable_MUID         UNIQUEIDENTIFIER = NULL,  
    @Securable_Name         NVARCHAR(100) = NULL,  
    @Principal_MUID         UNIQUEIDENTIFIER = NULL,   
    @Principal_Name         NVARCHAR(100) = NULL,  
    @PrincipalType_ID       INT = NULL,      
    @RoleAccessIdentifiers  XML = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @EmptyMuid UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, 0x0);  
      
    SET @Permission_ID      = NULLIF(@Permission_ID, 0);  
    SET @Model_MUID         = NULLIF(@Model_MUID, @EmptyMuid);  
    SET @Model_Name         = NULLIF(@Model_Name, N'');  
    SET @Securable_MUID     = NULLIF(@Securable_MUID, @EmptyMuid);  
    SET @Securable_Name     = NULLIF(@Securable_Name, N'');  
    SET @Principal_MUID     = NULLIF(@Principal_MUID, @EmptyMuid);  
    SET @Principal_Name     = NULLIF(@Principal_Name, N'');  
    SET @PrincipalType_ID   = NULLIF(@PrincipalType_ID, 0);  
      
    SELECT r.RoleAccess_ID  
          ,r.RoleAccess_MUID  
          ,r.Role_ID  
          ,r.Principal_ID  
          ,r.Principal_MUID  
          ,r.PrincipalType_ID  
          ,r.Principal_Name  
          ,r.Object_ID  
          ,r.Object_Name  
          ,r.Model_ID  
          ,r.Model_MUID  
          ,r.Model_Name  
          ,r.Securable_ID  
          ,r.Securable_MUID  
          ,r.Securable_Name  
          ,r.Privilege_ID  
          ,r.LastChgUser  
          ,r.LastChgDTM  
          ,CASE PrincipalType_ID   
            WHEN 1 THEN (SELECT IsAdministrator  
                         FROM mdm.viw_SYSTEM_SECURITY_USER_MODEL u  
                         WHERE   
                            u.User_ID = r.Principal_ID AND   
                            u.ID = r.Model_ID)    
            ELSE 0 END AS IsModelAdministrator  
      FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL r  
        INNER JOIN   
            mdm.udfMetadataGetSearchCriteriaIds(@RoleAccessIdentifiers) crit  
            ON   
            (@Permission_ID IS NULL OR r.Privilege_ID = @Permission_ID) AND  
            (@Model_MUID IS NULL OR r.Model_MUID = @Model_MUID) AND  
            (@Model_Name IS NULL OR r.Model_Name = @Model_Name) AND  
            (@Securable_MUID IS NULL OR r.Securable_MUID = @Securable_MUID) AND  
            (@Securable_Name IS NULL OR r.Securable_Name = @Securable_Name) AND  
            (@Principal_MUID IS NULL OR r.Principal_MUID = @Principal_MUID) AND  
            (@Principal_Name IS NULL OR UPPER(r.Principal_Name) = UPPER(@Principal_Name)) AND  
            (@PrincipalType_ID IS NULL OR r.PrincipalType_ID = @PrincipalType_ID) AND  
            (crit.MUID IS NULL OR crit.MUID = r.RoleAccess_MUID) AND  
            (crit.ID IS NULL OR crit.ID = r.RoleAccess_ID)   
  
    SET NOCOUNT OFF;  
END; --proc
GO
