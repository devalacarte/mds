SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
declare @ret as NVARCHAR(250)  
exec mdm.udpUserPreferenceGet 1,1,@ret OUTPUT  
select @ret  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserPreferenceGet]  
(  
	@User_ID            INT,  
	@PreferenceName 	NVARCHAR(100),  
	@PreferenceValue 	NVARCHAR(max) = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	IF EXISTS(SELECT 1 FROM mdm.tblUserPreference WHERE  PreferenceName = @PreferenceName AND [User_ID] = @User_ID)  
		BEGIN  
			SELECT  
				@PreferenceValue = PreferenceValue  
			FROM  
				mdm.tblUserPreference  
			WHERE   
				[User_ID] = @User_ID AND  
				PreferenceName = @PreferenceName   
				  
		END  
	ELSE  
		BEGIN  
			SELECT @PreferenceValue = CAST(N'' AS NVARCHAR(max))  
		END  
  
	SET NOCOUNT OFF  
END --proc
GO
