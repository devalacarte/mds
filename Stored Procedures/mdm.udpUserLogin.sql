SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpUserLogin 'bbarnett',''  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserLogin]  
(  
	@UserName       NVARCHAR(100),  
	@Return_ID			INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @User_ID as INT  
	SELECT @User_ID = mdm.udfUserIDGetByUserName(@UserName)  
  
	UPDATE mdm.tblUser SET LastLoginDTM = GETUTCDATE() WHERE ID = @User_ID  
	SELECT @Return_ID = @User_ID	  
  
	EXEC mdm.udpUserGet @User_ID  
  
	SET NOCOUNT OFF  
END --proc
GO
