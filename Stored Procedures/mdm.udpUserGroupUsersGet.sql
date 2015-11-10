SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpUserGroupUsersGet 8,1  
exec mdm.udpUserGroupUsersGet 0,3  
  
select * from mdm.tblUserGroupAssignment  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupUsersGet]  
(  
	@ID					INT,  
	@SecurityStatus_ID	INT  
  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	IF @SecurityStatus_ID = 1 --Member of  
		BEGIN  
			SELECT  
				U.ID,  
				U.MUID,  
				U.UserName + N' (' + U.DisplayName + N')' as Name,  
				U.UserName  
			FROM  
				mdm.tblUser U  
					INNER JOIN mdm.tblUserGroupAssignment SGA ON  SGA.User_ID = U.ID  
						AND SGA.UserGroup_ID = @ID  
			WHERE  
				Status_ID = 1  
			ORDER BY  
				U.UserName  
		END  
	IF @SecurityStatus_ID = 2 --Not Member of  
		BEGIN  
			SELECT  
				U.ID,  
				U.MUID,  
				U.UserName + N' (' + U.DisplayName + N')' as Name,  
				U.UserName   
			FROM  
				mdm.tblUser U  
					LEFT JOIN mdm.tblUserGroupAssignment SGA ON  SGA.User_ID = U.ID  
						AND SGA.UserGroup_ID = @ID  
			WHERE  
				Status_ID = 1 AND  
				SGA.ID IS NULL  
			ORDER BY  
				U.UserName  
		END  
	IF @SecurityStatus_ID = 3 --ALL  
		BEGIN  
			SELECT  
				U.ID,  
				U.MUID,  
				U.UserName + N' (' + U.DisplayName + N')' [Name],  
				U.UserName   
			FROM  
				mdm.tblUser U  
			ORDER BY  
				U.UserName  
		END  
	IF @SecurityStatus_ID = 4 --Specific user  
		BEGIN  
			SELECT  
				U.ID,  
				U.MUID,  
				U.UserName + N' (' + U.DisplayName + N')' [Name],  
				U.UserName   
			FROM  
				mdm.tblUser U  
			WHERE  
				U.ID = @ID  
		END  
  
  
	SET NOCOUNT OFF  
END --proc
GO
