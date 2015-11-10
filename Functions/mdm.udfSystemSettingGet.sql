SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfSystemSettingGet(N'MDMRootURL')  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSystemSettingGet]  
(  
	@SettingName 	NVARCHAR(100)  
)   
RETURNS NVARCHAR(MAX)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
	DECLARE @SettingValue 	NVARCHAR(MAX);  
  
	SELECT	@SettingValue = SettingValue  
	FROM	mdm.tblSystemSetting  
	WHERE	SettingName = @SettingName;  
  
	SET @SettingValue = ISNULL(@SettingValue, CAST(N'' AS NVARCHAR(MAX)))  
	  
	RETURN @SettingValue;  
	  
END; --fn
GO
