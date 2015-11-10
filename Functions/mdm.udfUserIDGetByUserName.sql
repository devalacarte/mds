SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfUserIDGetByUserName('Administrator')  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfUserIDGetByUserName]  
(  
	@UserName	NVARCHAR(100)  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @User_ID INT;  
	  
	SELECT 	@User_ID = U.ID   
	FROM 	mdm.tblUser AS U  
	WHERE	U.UserName = @UserName   
	AND U.Status_ID = 1;  
		  
	RETURN @User_ID;  
END; --fn
GO
