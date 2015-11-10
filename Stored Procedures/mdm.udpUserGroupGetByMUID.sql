SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupGetByMUID]  
(  
	@UserGroup_MUID		UNIQUEIDENTIFIER = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
		BEGIN  
			SELECT  
				S.ID,  
				S.MUID,  
				S.SID,  
				S.UserGroupType_ID,  
				S.Name,  
				S.Description,  
				IsNull(S.EnterUserID,0) AS EnterUserID,  
				IsNull(eu.UserName,N'') AS EnterUserName,  
				IsNull(eu.DisplayName,N'') AS EnterUserDisplayName,  
				S.EnterDTM,  
				IsNull(S.LastChgUserID,0) AS LastChgUserID,  
				IsNull(lcu.UserName,N'') AS LastChgUserName,  
				IsNull(lcu.DisplayName,N'') AS LastChgUserDisplayName,  
				S.LastChgDTM  
			FROM  
				mdm.tblUserGroup S  
				LEFT OUTER JOIN mdm.tblUser eu ON S.EnterUserID = eu.ID   
				LEFT OUTER JOIN mdm.tblUser lcu ON S.LastChgUserID = lcu.ID  
			WHERE  
				S.Status_ID = 1 AND S.MUID = @UserGroup_MUID  
  
		END  
	SET NOCOUNT OFF  
END --proc
GO
