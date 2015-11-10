SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
  
SELECT CONVERT(XML, mdm.udfNotificationGetVersionStatusChangeHeader());  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfNotificationGetVersionStatusChangeHeader]()  
RETURNS NVARCHAR(MAX)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	  
	DECLARE  
		 @HeaderElement NVARCHAR(MAX)   
        ,@LocalizedNotificationTypeName NVARCHAR(MAX) = N'Version Status Change'  
        ,@LocalizedModelHeader NVARCHAR(MAX) = N'Model'  
        ,@LocalizedVersionHeader NVARCHAR(MAX) = N'Version'  
        ,@LocalizedPriorStatusHeader NVARCHAR(MAX) = N'Prior status'  
        ,@LocalizedNewStatusHeader NVARCHAR(MAX) = N'New status'  
        ,@LocalizedLink NVARCHAR(MAX) = N'Click to view'  
        ,@LocalizedIssuedHeader NVARCHAR(MAX) = N'Issued'  
        ,@LocalizedPriorStatus NVARCHAR(MAX) = N''  
        ,@LocalizedNewStatus NVARCHAR(MAX) = N''  
        ,@CurrentLanguageCode INT = 1033 -- Default language code is English (US).  
	    ,@StringLanguageCode NVARCHAR(MAX) = N''  
        ,@RootUrl NVARCHAR(MAX)  
	  
	-- Use default language code to get the notification language code.  
	SELECT @StringLanguageCode = mdm.udfLocalizedStringGet(N'NotificationLCID', @CurrentLanguageCode, 1033);  
      
    IF @StringLanguageCode <> N'' BEGIN  
		SELECT @CurrentLanguageCode = CONVERT(INT, @StringLanguageCode)  
    END; -- if  
  
    -- Get the localized message texts based on the notification language code in tblLocalizedStrings.  
	SELECT @LocalizedModelHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderModel', @CurrentLanguageCode, @LocalizedModelHeader);  
	SELECT @LocalizedVersionHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderVersion', @CurrentLanguageCode, @LocalizedVersionHeader);  
	SELECT @LocalizedPriorStatusHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderPriorStatus', @CurrentLanguageCode, @LocalizedPriorStatusHeader);  
	SELECT @LocalizedNewStatusHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderNewStatus', @CurrentLanguageCode, @LocalizedNewStatusHeader);  
	SELECT @LocalizedIssuedHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderIssued', @CurrentLanguageCode, @LocalizedIssuedHeader);  
	SELECT @LocalizedLink = mdm.udfLocalizedStringGet(N'NotificationLinkTextVerbose', @CurrentLanguageCode, @LocalizedLink);  
	SELECT @LocalizedNotificationTypeName = mdm.udfLocalizedStringGet(N'NotificationVersionStatusChange', @CurrentLanguageCode, @LocalizedNotificationTypeName);  
  
    -- Get the MDS web application root URL  
	SELECT @RootUrl = mdm.udfSystemSettingGet(N'MDMRootURL');  
  
	SELECT @HeaderElement =  
	  N'<header>' +  
        N'<Notification_type>' + @LocalizedNotificationTypeName + N'</Notification_type>' +  
        N'<Model>' + @LocalizedModelHeader + N'</Model>' +  
        N'<Version>' + @LocalizedVersionHeader + N'</Version>' +  
        N'<PriorStatus>' + @LocalizedPriorStatusHeader + N'</PriorStatus>' +  
        N'<NewStatus>' + @LocalizedNewStatusHeader + N'</NewStatus>' +  
        N'<link_text>' + @LocalizedLink + N'</link_text>' +   
        N'<Issued>' + @LocalizedIssuedHeader + N'</Issued>' +  
        N'<root_url>' + @RootUrl + N'</root_url>' +  
    N'</header>'   
	  
	RETURN @HeaderElement  
  
END --fn
GO
