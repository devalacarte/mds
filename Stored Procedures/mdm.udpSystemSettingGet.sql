SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
declare @ret as NVARCHAR(500)  
exec mdm.udpSystemSettingGet 'BuiltInAdministrator',@ret OUTPUT  
select @ret  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSystemSettingGet]  
(  
	@SettingName 	NVARCHAR(100),  
	@SettingValue 	NVARCHAR(max) = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SELECT	@SettingValue = SettingValue  
	FROM	mdm.tblSystemSetting  
	WHERE	SettingName = @SettingName  
  
	SET @SettingValue = ISNULL(@SettingValue, CAST(N'' AS NVARCHAR(max)) )  
  
	SET NOCOUNT OFF  
END --proc
GO
