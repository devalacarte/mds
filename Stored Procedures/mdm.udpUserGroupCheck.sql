SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
DECLARE @Ret INT  
EXEC mdm.udpUserGroupCheck 'SysAdmin',@Ret OUTPUT  
SELECT @Ret  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupCheck]  
(  
	@UserGroupName	NVARCHAR(50),  
	@ReturnValue as INT OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
	/********************************/  
	/*	0  = OK						*/  
	/*	1+ = Already exists			*/					  
	/********************************/  
  
	DECLARE @userGroupID int  
	SELECT @userGroupID = ID FROM mdm.tblUserGroup WHERE [Name] = @UserGroupName AND Status_ID = 1  
  
	SELECT @ReturnValue = IsNull(@userGroupID, 0)  
  
	SET NOCOUNT OFF  
END --proc
GO
