SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpUserPreferencesGet 1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserPreferencesGet]  
(  
	@User_ID INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SELECT  
		PreferenceName,  
		PreferenceValue  
	FROM  
		mdm.tblUserPreference  
	WHERE   
		[User_ID] = @User_ID  
  
	SET NOCOUNT OFF  
END --proc
GO
