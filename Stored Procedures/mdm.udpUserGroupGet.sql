SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
mdm.udpUserGroupGet 'cthompson',1  
mdm.udpUserGroupGet 'cthompson',2  
mdm.udpUserGroupGet 'cthompson',3  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupGet]  
(  
	@User_ID 			INT,  
	@SecurityStatus_ID	INT,  
	@UserGroup_ID		INT = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	IF @SecurityStatus_ID = 1 --Member of  
		BEGIN  
			SELECT  
				S.ID,  
				S.MUID,  
				S.SID,  
				S.UserGroupType_ID,  
				S.Name,  
				S.Description  
			FROM  
				mdm.tblUserGroup S  
					INNER JOIN mdm.tblUserGroupAssignment SGA ON SGA.UserGroup_ID = S.ID  
						AND SGA.User_ID = @User_ID  
			WHERE  
				Status_ID = 1   
			ORDER BY S.Name  
  
		END  
	ELSE IF @SecurityStatus_ID = 2 --Not Member of  
		BEGIN  
			SELECT  
				S.ID,  
				S.MUID,  
				S.SID,  
				S.UserGroupType_ID,  
				S.Name,  
				S.Description  
			FROM  
				mdm.tblUserGroup S  
					LEFT JOIN mdm.tblUserGroupAssignment SGA ON SGA.UserGroup_ID = S.ID  
						AND SGA.User_ID = @User_ID  
			WHERE  
				SGA.ID IS NULL AND  
				S.Status_ID = 1  
			ORDER BY S.Name  
		END  
  
	ELSE IF @SecurityStatus_ID = 3 --ALL  
		BEGIN  
			SELECT  
				S.ID,  
				S.MUID,  
				S.SID,  
				S.UserGroupType_ID,  
				S.Name,  
				S.Description  
			FROM  
				mdm.tblUserGroup S  
			WHERE  
				Status_ID = 1  
			ORDER BY S.Name  
  
		END  
	ELSE IF @SecurityStatus_ID = 4 --Specific user group  
		BEGIN  
			SELECT  
				S.ID,  
				S.MUID,  
				S.UserGroupType_ID,  
				S.SID,  
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
				S.Status_ID = 1 AND S.ID = @UserGroup_ID  
  
		END  
  
	SET NOCOUNT OFF  
END --proc
GO
