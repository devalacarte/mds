SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
	--Run this the first time to kick off the timer  
	DECLARE @handle UNIQUEIDENTIFIER;  
	BEGIN DIALOG CONVERSATION @handle   
		FROM SERVICE [microsoft/mdm/service/notification]  
		TO SERVICE N'microsoft/mdm/service/system'  
		WITH ENCRYPTION = OFF;  
	BEGIN CONVERSATION TIMER (@handle) TIMEOUT = 1;  
	  
    ALTER QUEUE mdm.[microsoft/mdm/queue/notification]  
    WITH ACTIVATION   
    (  
	    STATUS = ON,   
	    PROCEDURE_NAME = [mdm].[udpNotificationQueueActivate],   
	    MAX_QUEUE_READERS = 1,  
	    --In the original queue declaration we used the standard mds_ssb_user context  
	    --since the appropriate login/user we needed did not exist yet.  
	    --So here we execute using the context we actually require.  
	    EXECUTE AS N'mds_email_user'  
    );			  
*/  
CREATE PROCEDURE [mdm].[udpNotificationQueueActivate]  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE			  
         @message_type_name	        sysname  
        ,@handle			        UNIQUEIDENTIFIER  
        ,@interval			        INT  
        ,@need_new			        BIT  
        ,@status			        NVARCHAR(1000)  
        ,@dialog			        UNIQUEIDENTIFIER  
        ,@User_ID			        INT  
        ,@Batch_ID			        INT  
        ,@Version_ID                INT  
        ,@databaseMailProfileName   sysname  
        ,@LocalizedEmailSubject		NVARCHAR(MAX) = N'MDS Notification'  
        ,@LocalizedTruncatedMessage NVARCHAR(MAX) = N'This list of issues is truncated at {0} lines when sent by email.  {1} issues have been truncated.'  
	    ,@CurrentLanguageCode		INT = 1033 -- Default language code is English (US).  
	    ,@StringLanguageCode		NVARCHAR(MAX) = N''  
  
	--Initialize variables  
	SELECT @handle = NULL, @need_new = NULL;   
	  
	--Load interval setting from config, and check the defaults and ranges  
	SELECT @interval = mdm.udfSystemSettingGet(N'NotificationInterval');  
	IF @interval IS NULL SET @interval = 120; --Protect against NULL values  
	ELSE IF @interval < 10 SET @interval = 10; --Prevent negative and 'real-time' settings  
	ELSE IF @interval > 86400 SET @interval = 86400; --Check at least once per day (60 x 60 x 24)  
	  
	--Load Database Profile name to use from config.  
	SELECT @databaseMailProfileName = mdm.udfSystemSettingGet(N'DatabaseMailProfile');  
  
	-- Use default language code to get the notification language code.  
	SELECT @StringLanguageCode = mdm.udfLocalizedStringGet(N'NotificationLCID', @CurrentLanguageCode, 1033);  
      
    IF @StringLanguageCode <> N'' BEGIN  
		SELECT @CurrentLanguageCode = CONVERT(INT, @StringLanguageCode)  
    END; -- if  
  
    -- Get the localized message texts based on the notification language code in tblLocalizedStrings.  
	SELECT @LocalizedEmailSubject = mdm.udfLocalizedStringGet(N'NotificationSubject', @CurrentLanguageCode, @LocalizedEmailSubject);  
	SELECT @LocalizedTruncatedMessage = mdm.udfLocalizedStringGet(N'NotificationTruncatedMessage', @CurrentLanguageCode, @LocalizedTruncatedMessage);  
          
	BEGIN TRANSACTION   
  
	WAITFOR (  
		RECEIVE TOP(1)  
			@handle = [conversation_handle],  
			@message_type_name = message_type_name  
		FROM mdm.[microsoft/mdm/queue/notification]		  
	), TIMEOUT 5000; --Always wait a constant time for any new messages  
			  
	--Got a TIMER message  
	IF (@message_type_name = CAST(N'http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer' AS sysname)) BEGIN  
  
		--Start a new TIMER and COMMIT the transaction before we do the real work, to avoid poisoning  
		BEGIN CONVERSATION TIMER (@handle) TIMEOUT = @interval;  
		COMMIT TRANSACTION;  
			  
		--Create any validation issue notifications  
		EXEC mdm.udpValidationIssueEH  
		  
		DECLARE @EmailAddress NVARCHAR(MAX)  
		DECLARE @StyleSheetName NVARCHAR(MAX)  
		DECLARE @EmailType INT  
	    DECLARE @HtmlEmailType INT = 1;  
	    DECLARE @TextEmailType INT = 2;  
	    DECLARE @ValidationIssuesNotificationType INT = 1;  
	    DECLARE @VersionStatusChangeNotificationType INT = 2;  
		DECLARE @EmailFormat NVARCHAR(10)  
		DECLARE @StyleSheet XML  
		DECLARE @MessageData XML  
		DECLARE @NotificationID INT  
		DECLARE @EmailBody NVARCHAR(MAX)  
		DECLARE @MailId INT  
		DECLARE @NotificationElements NVARCHAR(MAX);  
		DECLARE @NotificationTypeID INT  
		DECLARE @HeaderElement NVARCHAR(MAX);  
		DECLARE @ValidationIssueHeaderElement NVARCHAR(MAX)  
		DECLARE @VersionStatusChangeHeaderElement NVARCHAR(MAX)  
		DECLARE @TruncationMessageElement NVARCHAR(MAX)  
		DECLARE @UserID INT  
    	DECLARE @NotificationsPerEmail INT;  
    	DECLARE @NotificationCount INT;  
    	DECLARE @NotificationTruncationCount INT;  
  
		--Get the notifications  
		DECLARE @Notifications TABLE (  
    	     RowNumber INT IDENTITY(1,1) NOT NULL  
            ,ID INT  
            ,NotificationType_ID INT  
            ,TextStyleSheet NVARCHAR(MAX) COLLATE database_default  
            ,HTMLStyleSheet NVARCHAR(MAX) COLLATE database_default  
            ,[Message] NVARCHAR(MAX) COLLATE database_default  
            ,[User_ID] INT  
            ,EmailAddress NVARCHAR(MAX) COLLATE database_default  
            ,EmailFormat INT  
            ,DefaultEmailFormat INT  
            );  
  
		DECLARE @NotificationTypes TABLE(  
    	     RowNumber INT IDENTITY(1,1) NOT NULL  
            ,NotificationType_ID INT  
            ,StyleSheetName NVARCHAR(MAX) COLLATE database_default  
            ,EmailFormat NVARCHAR(MAX) COLLATE database_default  
            ,EmailAddress NVARCHAR(MAX) COLLATE database_default  
            ,User_ID INT  
		);  
  
		INSERT INTO @Notifications EXECUTE mdm.udpNotificationsGet  
  
		--Get distinct list of notification types and users from the list of notifications  
		INSERT INTO @NotificationTypes  
		SELECT DISTINCT  
			NotificationType_ID  
			,CASE WHEN COALESCE(EmailFormat, DefaultEmailFormat) = @HtmlEmailType THEN HTMLStyleSheet ELSE TextStyleSheet END  
			,CASE WHEN COALESCE(EmailFormat, DefaultEmailFormat) = @HtmlEmailType THEN N'HTML' ELSE N'TEXT' END  
			,EmailAddress  
			,User_ID  
		FROM @Notifications  
  
		SELECT @ValidationIssueHeaderElement = mdm.udfNotificationGetValidationIssueHeader();  
		SELECT @VersionStatusChangeHeaderElement = mdm.udfNotificationGetVersionStatusChangeHeader();  
		  
		--Load Notifications per email limit from config.  
		SELECT @NotificationsPerEmail = mdm.udfSystemSettingGet(N'NotificationsPerEmail');  
		IF @NotificationsPerEmail IS NULL SET @NotificationsPerEmail = 100; --Protect against NULL values  
		ELSE IF @NotificationsPerEmail < 1 SET @NotificationsPerEmail = 100; --Prevent zero and negative values  
  
    	DECLARE @Counter INT = 1;  
	    DECLARE @MaxCounter INT = (SELECT MAX(RowNumber) FROM @NotificationTypes);  
  
    	-- Loop through the distinct list of notification types and users to email a batched list of notifications  
    	WHILE @Counter <= @MaxCounter  
		BEGIN  
			--Get the vars  
			SELECT   
				 @NotificationTypeID = NotificationType_ID  
				,@StyleSheetName = StyleSheetName  
				,@EmailAddress = EmailAddress  
				,@EmailFormat = EmailFormat  
				,@UserID = User_ID  
			FROM @NotificationTypes  
            WHERE RowNumber = @Counter;  
  
			SELECT @NotificationElements=N'';  
  
			IF @NotificationTypeID = @ValidationIssuesNotificationType  
				SELECT @HeaderElement = @ValidationIssueHeaderElement;  
			ELSE   
				SELECT @HeaderElement = @VersionStatusChangeHeaderElement;  
  
			--Get the number of notifications  
			SELECT  
				@NotificationCount = COUNT(*)  
			FROM @Notifications  
			WHERE NotificationType_ID = @NotificationTypeID  
			AND	User_ID = @UserID  
			  
			SELECT @TruncationMessageElement = N'';  
			  
			-- Check the number of notifications against the email notification limit config.  
			IF @NotificationCount > @NotificationsPerEmail BEGIN  
				SELECT @NotificationTruncationCount = @NotificationCount - @NotificationsPerEmail  
				-- Replace placeholders in the message.  
				SELECT @LocalizedTruncatedMessage = REPLACE(@LocalizedTruncatedMessage, N'{0}' , CONVERT(NVARCHAR(20), @NotificationsPerEmail));  
				SELECT @LocalizedTruncatedMessage = REPLACE(@LocalizedTruncatedMessage, N'{1}' , CONVERT(NVARCHAR(20), @NotificationTruncationCount));  
				-- Add the XML element tags.  
				SELECT @TruncationMessageElement = N'<truncated_message>' + @LocalizedTruncatedMessage + N'</truncated_message>'	  
			END  
  
			-- Construct the list of notification XML elements for the distinct notification type and user.  
			SELECT TOP(@NotificationsPerEmail)  
				@NotificationElements += [Message]  
			FROM @Notifications  
			WHERE NotificationType_ID = @NotificationTypeID  
			AND	User_ID = @UserID  
  
			--Construct XML message data  
			SELECT @MessageData = CONVERT(XML,N'<root>' + @HeaderElement + N'<notifications>' + @NotificationElements + N'</notifications>' + @TruncationMessageElement + N'</root>');  
  
			--Get XSLT stylesheet  
			SELECT @StyleSheet = CONVERT(XML, mdm.udfSystemSettingGet(@StyleSheetName));  
  
			--Apply stylesheet to create email body  
			SET @EmailBody = mdq.XmlTransform(@MessageData, @StyleSheet);				  
  
			--Send Email					  
		    EXECUTE [msdb].[dbo].[sp_send_dbmail]  
			    @profile_name = @databaseMailProfileName  
			    ,@recipients  = @EmailAddress  
			    ,@body        = @EmailBody  
			    ,@subject     = @LocalizedEmailSubject  
			    ,@body_format = @EmailFormat  
			    ,@mailitem_id = @MailId OUTPUT  
  
			--Update the SentDTM  
			UPDATE mdm.tblNotificationQueue SET SentDTM=GETUTCDATE() WHERE ID IN  
				(SELECT ID   
				 FROM	@Notifications  
	  			 WHERE	NotificationType_ID = @NotificationTypeID  
				 AND	User_ID = @UserID)  
  
			SET @Counter += 1;  
			--PRINT N'Processed notification ID: ' + CONVERT(NVARCHAR(MAX),@NotificationID);  
		END; --while  
  
		  
	--Got an END DIALOG message  
	END ELSE IF (@message_type_name = CAST(N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog' AS NVARCHAR(128))) BEGIN  
		PRINT N'Error in udpNotificationQueueActivate end dialog';  
		SET @need_new = 1;  
  
	--Got ERROR message  
	END ELSE IF (@message_type_name = CAST(N'http://schemas.microsoft.com/SQL/ServiceBroker/Error' AS NVARCHAR(128))) BEGIN  
		PRINT N'Error in udpNotificationQueueActivate error';  
		SET @need_new = 1;  
  
	--Timeout or unexpected message  
	END ELSE BEGIN   
		  
		COMMIT TRANSACTION;  
		  
	END; --if  
	  
	IF (@need_new = 1) BEGIN  
	  
		END CONVERSATION @handle;  
		  
		--DECLARE @handle UNIQUEIDENTIFIER; DECLARE @interval INT; SET @interval = 10;  
		BEGIN DIALOG CONVERSATION @handle  
			FROM SERVICE [microsoft/mdm/service/notification]  
			TO SERVICE N'microsoft/mdm/service/system'  
			WITH ENCRYPTION = OFF;  
		BEGIN CONVERSATION TIMER (@handle) TIMEOUT = @interval;  
  
		COMMIT TRANSACTION;  
					  
	END; --if  
  
	SET NOCOUNT OFF;  
END; --proc
GO
GRANT EXECUTE ON  [mdm].[udpNotificationQueueActivate] TO [mds_email_user]
GO
