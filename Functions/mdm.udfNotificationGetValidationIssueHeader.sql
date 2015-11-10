SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
  
SELECT CONVERT(XML, mdm.udfNotificationGetValidationIssueHeader());  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfNotificationGetValidationIssueHeader]()  
RETURNS NVARCHAR(MAX)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
	DECLARE  
		 @HeaderElement NVARCHAR(MAX)   
        ,@LocalizedNotificationTypeName NVARCHAR(MAX) = N'Validation Issue'  
        ,@LocalizedModelHeader NVARCHAR(MAX) = N'Model'  
        ,@LocalizedVersionHeader NVARCHAR(MAX) = N'Version'  
        ,@LocalizedEntityHeader NVARCHAR(MAX) = N'Entity'  
        ,@LocalizedLink NVARCHAR(MAX) = N'Link'  
        ,@LocalizedIDHeader NVARCHAR(MAX) = N'ID'  
        ,@LocalizedMemberCodeHeader NVARCHAR(MAX) = N'Member Code'  
        ,@LocalizedMessageHeader NVARCHAR(MAX) = N'Message'  
        ,@LocalizedIssuedHeader NVARCHAR(MAX) = N'Issued'  
        ,@CurrentLanguageCode INT = 1033 -- Default language code is English (US).  
	    ,@StringLanguageCode NVARCHAR(MAX) = N''  
        ,@RootUrl NVARCHAR(MAX)  
	  
	-- Use default language code to get the notification language code.  
	SELECT @StringLanguageCode = mdm.udfLocalizedStringGet(N'NotificationLCID', @CurrentLanguageCode, 1033);  
      
    IF @StringLanguageCode <> N'' BEGIN  
		SELECT @CurrentLanguageCode = CONVERT(INT, @StringLanguageCode)  
    END; -- if  
  
    -- Get the localized message texts based on the notification language code in tblLocalizedStrings.  
	SELECT @LocalizedIDHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderID', @CurrentLanguageCode, @LocalizedIDHeader);  
	SELECT @LocalizedModelHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderModel', @CurrentLanguageCode, @LocalizedModelHeader);  
	SELECT @LocalizedVersionHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderVersion', @CurrentLanguageCode, @LocalizedVersionHeader);  
	SELECT @LocalizedEntityHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderEntity', @CurrentLanguageCode, @LocalizedEntityHeader);  
	SELECT @LocalizedMemberCodeHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderMemberCode', @CurrentLanguageCode, @LocalizedMemberCodeHeader);  
	SELECT @LocalizedMessageHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderMessage', @CurrentLanguageCode, @LocalizedMessageHeader);  
	SELECT @LocalizedIssuedHeader = mdm.udfLocalizedStringGet(N'NotificationHeaderIssued', @CurrentLanguageCode, @LocalizedIssuedHeader);  
	SELECT @LocalizedLink = mdm.udfLocalizedStringGet(N'NotificationLinkText', @CurrentLanguageCode, @LocalizedLink);  
	SELECT @LocalizedNotificationTypeName = mdm.udfLocalizedStringGet(N'NotificationValidationIssue', @CurrentLanguageCode, @LocalizedNotificationTypeName);  
  
    -- Get the MDS web application root URL  
	SELECT @RootUrl = mdm.udfSystemSettingGet(N'MDMRootURL');  
  
	SELECT @HeaderElement =  
		N'<header>' +  
	        N'<Notification_type>' + @LocalizedNotificationTypeName + N'</Notification_type>' +  
	        N'<id>' + @LocalizedIDHeader + N'</id>' +  
	        N'<Model>' + @LocalizedModelHeader + N'</Model>' +  
	        N'<Version>' + @LocalizedVersionHeader + N'</Version>' +  
	        N'<Entity>' + @LocalizedEntityHeader + N'</Entity>' +  
	        N'<MemberCode>' + @LocalizedMemberCodeHeader + N'</MemberCode>' +  
	        N'<Message>' + @LocalizedMessageHeader + N'</Message>' +  
	        N'<Issued>' + @LocalizedIssuedHeader + N'</Issued>' +  
	        N'<root_url>' + @RootUrl + N'</root_url>' +  
	    N'</header>'  
	  
	RETURN @HeaderElement  
  
END --fn
GO
