SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @LocalizedEmailSubject		NVARCHAR(MAX) = N'MDS Notification';  
	SELECT @LocalizedEmailSubject = mdm.udfLocalizedStringGet(N'NotificationSubject', 1033, @LocalizedEmailSubject);  
	SELECT @LocalizedEmailSubject;  
	  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfLocalizedStringGet]  
(  
	 @ResourceName		 	NVARCHAR(100)  
	,@CurrentLanguageCode	INT = 1033   
	,@DefaultValue			NVARCHAR(MAX) = N''  
)   
RETURNS NVARCHAR(MAX)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
	DECLARE @LocalizedValue 	NVARCHAR(MAX);  
  
	SELECT	@LocalizedValue = LocalizedValue  
	FROM	mdm.tblLocalizedStrings   
	WHERE	LanguageCode = @CurrentLanguageCode   
	AND		ResourceName = @ResourceName;   
  
	SELECT	@LocalizedValue = ISNULL(@LocalizedValue,@DefaultValue)   
	  
	RETURN @LocalizedValue;  
	  
END; --fn
GO
