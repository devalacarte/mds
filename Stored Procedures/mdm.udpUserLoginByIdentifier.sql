SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpUserLoginByIdentifier 'bbarnett',''  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserLoginByIdentifier]  
(  
	@SID				NVARCHAR(250) = NULL,	  
	@UserName			NVARCHAR(100) = NULL,  
	@Return_ID			INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SET @SID = NULLIF(LTRIM(RTRIM(@SID)), N'');  
	  
	IF ((@SID IS NULL OR LEN(@SID) = 0) AND (@UserName IS NULL OR LEN(@UserName) = 0) )  
		SET @Return_ID = NULL;  
	ELSE BEGIN  
		  
		SELECT 	@Return_ID = ID   
		FROM 	mdm.tblUser  
		WHERE   
			(@SID IS NULL OR SID = @SID)  
			AND UserName = CASE WHEN @SID IS NULL OR LEN(@SID) = 0 THEN @UserName ELSE UserName END  
		AND Status_ID = 1;  
			  
		UPDATE mdm.tblUser SET LastLoginDTM = GETUTCDATE() WHERE ID = @Return_ID;  
	END; --if  
	  
	EXEC mdm.udpUserGet @Return_ID;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
