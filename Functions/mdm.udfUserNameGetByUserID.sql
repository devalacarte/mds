SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
  
SELECT mdm.udfUserNameGetByUserID(1)  
select * from mdm.tblUser  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfUserNameGetByUserID]  
(  
	@User_ID	INT  
)   
RETURNS NVARCHAR(100)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @UserName NVARCHAR(100)  
	  
	SELECT   
		@UserName = U.UserName   
	  
	FROM   
		mdm.tblUser U  
	  
	WHERE  
		U.ID = @User_ID  
	  
	  
	RETURN @UserName	     
  
END --fn
GO
