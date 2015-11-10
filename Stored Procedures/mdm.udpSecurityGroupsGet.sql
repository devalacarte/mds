SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Returns the specified groups.  
      
    EXEC mdm.udpSecurityGroupsGet   
        @GroupIdentifiers = N''  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityGroupsGet]  
(  
    @GroupIdentifiers XML = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    SELECT   
        g.ID,  
        g.MUID,  
        g.SID,  
        g.UserGroupType_ID,  
        g.Name,  
        g.Description,  
        COALESCE(g.EnterUserID, 0) AS EnterUserID,  
        COALESCE(eu.UserName, N'') AS EnterUserName,  
        COALESCE(eu.DisplayName, N'') AS EnterUserDisplayName,  
        g.EnterDTM,  
        COALESCE(g.LastChgUserID, 0) AS LastChgUserID,  
        COALESCE(lcu.UserName, N'') AS LastChgUserName,  
        COALESCE(lcu.DisplayName, N'') AS LastChgUserDisplayName,  
        g.LastChgDTM  
    FROM  
        mdm.tblUserGroup g  
        INNER JOIN   
        mdm.udfMetadataGetSearchCriteriaIds(@GroupIdentifiers) crit  
            ON   
            g.Status_ID = 1 AND   
            (crit.MUID IS NOT NULL OR crit.Name IS NOT NULL OR crit.ID IS NOT NULL) AND  
            (crit.MUID IS NULL OR crit.MUID = g.MUID) AND  
            (crit.Name IS NULL OR UPPER(crit.Name) = UPPER(g.Name)) AND  
            (crit.ID IS NULL OR crit.ID = g.ID)  
        LEFT JOIN mdm.tblUser eu   
            ON g.EnterUserID = eu.ID   
        LEFT JOIN mdm.tblUser lcu   
            ON g.LastChgUserID = lcu.ID  
        ORDER BY g.ID;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
