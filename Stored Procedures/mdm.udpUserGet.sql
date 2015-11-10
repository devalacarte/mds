SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpUserGet 5  
EXEC mdm.udpUserGet 11  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserGet]  
(  
	@User_ID INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SELECT  
		u.ID,  
		u.MUID,  
		u.SID,  
		u.UserName,  
		u.DisplayName,  
		u.Description,  
		u.EmailAddress,  
		u.LastLoginDTM,  
		CASE u.EnterUserID WHEN NULL THEN 0 ELSE u.EnterUserID END AS EnterUserID,  
		ISNULL(eu.UserName,N'') EnterUserName,  
		ISNULL(eu.DisplayName,N'') EnterUserDisplayName,  
		u.EnterDTM,  
		CASE u.LastChgUserID WHEN NULL THEN 0 ELSE u.LastChgUserID END LastChgUserID,  
		ISNULL(lcu.UserName,N'') LastChgUserName,  
		ISNULL(lcu.DisplayName,N'') LastChgUserDisplayName,  
		u.LastChgDTM,  
		pref.PreferenceValue AS EmailType    
	FROM  
		mdm.tblUser u  
		LEFT OUTER JOIN mdm.tblUser eu ON u.EnterUserID = eu.ID   
		LEFT OUTER JOIN mdm.tblUser lcu ON u.LastChgUserID = lcu.ID  
		LEFT OUTER JOIN mdm.tblUserPreference pref on u.ID = pref.User_ID AND PreferenceName='lstEmail'  
	WHERE  
		u.ID = @User_ID   
		AND u.Status_ID <> 2  
  
	SET NOCOUNT OFF  
END --proc
GO
