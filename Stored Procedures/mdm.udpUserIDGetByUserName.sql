SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpUserIDGetByUserName 'cthompson'  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserIDGetByUserName]  
(  
	@UserName	NVARCHAR(100)	  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @User_ID AS INTEGER  
  
	SELECT @User_ID = ISNULL(mdm.udfUserIDGetByUserName(@UserName),0)  
  
	SELECT @User_ID as UserID  
  
	SET NOCOUNT OFF  
END --proc
GO
