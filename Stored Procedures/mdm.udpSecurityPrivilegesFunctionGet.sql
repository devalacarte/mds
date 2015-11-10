SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
    Returns function privileges.  
      
    EXEC mdm.udpSecurityPrivilegesFunctionGet   
        @Permission_ID = 1,  
        @PrincipalType_ID = NULL,  
        @Principal_MUID = NULL,  
        @Principal_Name = NULL,  
        @PrivilegeIdentifiers = NULL  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesFunctionGet]  
(  
    @Permission_ID INT = NULL,  
    @PrincipalType_ID INT = NULL,  
    @Principal_MUID UNIQUEIDENTIFIER = NULL,  
    @Principal_Name NVARCHAR(355) = NULL,  
    @PrivilegeIdentifiers XML = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    SELECT   
        p.Foreign_ID,  
        p.Foreign_MUID,  
        p.Foreign_Name,  
        p.Function_ID,  
        p.Function_Constant,  
        p.Function_Name,  
        p.MUID,   
        p.Permission_ID,  
        p.ForeignType_ID,  
        p.EnterUserID,  
        p.EnterUserName,  
        p.EnterDTM,  
        p.LastChgUserID,  
        p.LastChgUserName,  
        p.LastChgDTM   
    FROM mdm.viw_SYSTEM_SECURITY_NAVIGATION p  
         INNER JOIN   
         mdm.udfMetadataGetSearchCriteriaIds(@PrivilegeIdentifiers) crit  
            ON   
            p.Permission_ID = @Permission_ID AND  
            (@PrincipalType_ID IS NULL OR p.ForeignType_ID = @PrincipalType_ID) AND  
            (@Principal_MUID IS NULL   OR p.Foreign_MUID = @Principal_MUID) AND  
            (@Principal_Name IS NULL   OR UPPER(p.Foreign_Name) = UPPER(@Principal_Name)) AND  
            (crit.MUID IS NULL OR crit.MUID = p.MUID) AND  
            (crit.Name IS NULL OR UPPER(crit.Name) = UPPER(p.Function_Name)) AND  
            (crit.ID IS NULL OR crit.ID = p.Function_ID)  
              
    SET NOCOUNT OFF;  
END; --proc
GO
