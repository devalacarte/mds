SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_NAVIGATION]  
/*WITH SCHEMABINDING*/  
AS  
SELECT       
	tUserGroup.ID AS Foreign_ID,   
	2 AS ForeignType_ID,  
	tUserGroup.MUID AS Foreign_MUID,   
	tUserGroup.Name Foreign_Name,   
	tNav.ID AS Function_ID,   
    tNav.Constant AS Function_Constant,   
	tNav.Name AS Function_Name,   
	tNavSec.MUID,   
	tNavSec.Permission_ID Permission_ID,  
	  
	IsNull(tNavSec.EnterUserID,0) AS EnterUserID,  
	IsNull(eu.UserName,N'') AS EnterUserName,  
	tNavSec.EnterDTM,  
	IsNull(tNavSec.LastChgUserID,0) AS LastChgUserID,  
	IsNull(lcu.UserName,N'') AS LastChgUserName,  
	tNavSec.LastChgDTM	    
FROM        mdm.tblUserGroup AS tUserGroup   
			INNER JOIN  mdm.tblNavigationSecurity AS tNavSec ON tUserGroup.ID = tNavSec.Foreign_ID AND tNavSec.ForeignType_ID = 2   
            INNER JOIN  mdm.tblNavigation AS tNav ON tNavSec.Navigation_ID = tNav.ID  
            LEFT OUTER JOIN mdm.tblUser eu ON tUserGroup.EnterUserID = eu.ID   
			LEFT OUTER JOIN mdm.tblUser lcu ON tUserGroup.LastChgUserID = lcu.ID  
UNION   
SELECT    
	tUser.ID AS Foreign_ID,   
	1 AS ForeignType_ID,  
	tUser.MUID AS Foreign_MUID,   
	tUser.UserName Foreign_Name,   
	tNav.ID AS Function_ID,   
    tNav.Constant AS Function_Constant,   
	tNav.Name AS Function_Name,   
	tNavSec.MUID,   
	tNavSec.Permission_ID Permission_ID,  
	IsNull(tNavSec.EnterUserID,0) AS EnterUserID,  
	IsNull(eu.UserName,N'') AS EnterUserName,  
	tNavSec.EnterDTM,  
	IsNull(tNavSec.LastChgUserID,0) AS LastChgUserID,  
	IsNull(lcu.UserName,N'') AS LastChgUserName,  
	tNavSec.LastChgDTM    
FROM        mdm.tblUser AS tUser  
			INNER JOIN  mdm.tblNavigationSecurity AS tNavSec ON tUser.ID = tNavSec.Foreign_ID AND tNavSec.ForeignType_ID = 1   
			INNER JOIN  mdm.tblNavigation AS tNav ON tNavSec.Navigation_ID = tNav.ID  
			LEFT OUTER JOIN mdm.tblUser eu ON tUser.EnterUserID = eu.ID   
			LEFT OUTER JOIN mdm.tblUser lcu ON tUser.LastChgUserID = lcu.ID
GO
GRANT SELECT ON  [mdm].[viw_SYSTEM_SECURITY_NAVIGATION] TO [mds_exec]
GO
