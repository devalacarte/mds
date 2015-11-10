SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Returns the specified users.  
      
    EXEC udpSecurityUsersGet   
        @UserIdentifiers = N''  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityUsersGet]  
(  
    @UserIdentifiers XML = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    SELECT   
        u.ID,  
        u.MUID,  
        u.SID,  
        u.UserName,  
        u.DisplayName,  
        u.Description,  
        u.EmailAddress,  
        u.LastLoginDTM,  
        COALESCE(u.EnterUserID,0) AS EnterUserID,  
        COALESCE(eu.UserName,N'') AS EnterUserName,  
        COALESCE(eu.DisplayName,N'') AS EnterUserDisplayName,  
        u.EnterDTM,  
        COALESCE(u.LastChgUserID,0) AS LastChgUserID,  
        COALESCE(lcu.UserName,N'') AS LastChgUserName,  
        COALESCE(lcu.DisplayName,N'') AS LastChgUserDisplayName,  
        u.LastChgDTM,  
        pref.PreferenceValue AS EmailType    
    FROM  
        mdm.tblUser u  
        INNER JOIN   
        mdm.udfMetadataGetSearchCriteriaIds(@UserIdentifiers) crit  
            ON   
            u.Status_ID <> 2 AND  
            --(crit.MUID IS NOT NULL OR crit.Name IS NOT NULL OR crit.ID IS NOT NULL) AND -- return all when no indentifiers are provided. This is inconsistent with udpSecurityGroupsGet??  
            (crit.MUID IS NULL OR crit.MUID = u.MUID) AND  
            (crit.Name IS NULL OR UPPER(crit.Name) = UPPER(u.UserName)) AND  
            (crit.ID IS NULL OR crit.ID = u.ID)  
        LEFT OUTER JOIN mdm.tblUser eu   
            ON u.EnterUserID = eu.ID   
        LEFT OUTER JOIN mdm.tblUser lcu   
            ON u.LastChgUserID = lcu.ID  
        LEFT OUTER JOIN mdm.tblUserPreference pref   
            ON   
                u.ID = pref.User_ID AND   
                PreferenceName='lstEmail'  
        ORDER BY u.ID  
          
    SET NOCOUNT OFF;  
END; --proc
GO
