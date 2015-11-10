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
		FROM SERVICE [microsoft/mdm/service/stagingbatch]  
		TO SERVICE N'microsoft/mdm/service/system'  
		WITH ENCRYPTION = OFF;  
	BEGIN CONVERSATION TIMER (@handle) TIMEOUT = 1;  
	  
	ALTER QUEUE mdm.[microsoft/mdm/queue/stagingbatch] WITH ACTIVATION (STATUS = ON, PROCEDURE_NAME = mdm.udpStagingBatchQueueActivate, MAX_QUEUE_READERS = 1, EXECUTE AS CALLER);  
			  
	SELECT * FROM mdm.[microsoft/mdm/queue/stagingbatch];  
	  
	UPDATE mdm.tblSystemSetting SET SettingValue = 60 WHERE SettingName = N'StagingBatchInterval';  
*/  
CREATE PROCEDURE [mdm].[udpStagingBatchQueueActivate]  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE			  
		 @message_type_name	sysname  
		,@handle			UNIQUEIDENTIFIER  
		,@interval			INT  
		,@need_new			BIT  
		,@status			NVARCHAR(1000)  
		,@dialog			UNIQUEIDENTIFIER  
		,@User_ID			INT  
		,@Batch_ID			INT  
		,@Version_ID		INT;  
		  
	--Initialize variables  
	SELECT @handle = NULL, @need_new = NULL;   
	  
	--Load interval setting from config, and check the defaults and ranges  
	SELECT @interval = CAST(SettingValue AS INT) FROM mdm.tblSystemSetting WHERE SettingName = CAST(N'StagingBatchInterval' AS NVARCHAR(100));  
	IF @interval IS NULL SET @interval = 120; --Protect against NULL values  
	ELSE IF @interval < 10 SET @interval = 10; --Prevent negative and 'real-time' settings  
	ELSE IF @interval > 86400 SET @interval = 86400; --Check at least once per day (60 x 60 x 24)  
	  
	BEGIN TRANSACTION   
  
	WAITFOR (  
		RECEIVE TOP(1)  
			@handle = [conversation_handle],  
			@message_type_name = message_type_name  
		FROM mdm.[microsoft/mdm/queue/stagingbatch]		  
	), TIMEOUT 5000; --Always wait a constant time for any new messages  
			  
	--Got a TIMER message  
	IF (@message_type_name = CAST(N'http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer' AS NVARCHAR(128))) BEGIN  
  
		--Start a new TIMER and COMMIT the transaction before we do the real work, to avoid poisoning  
		BEGIN CONVERSATION TIMER (@handle) TIMEOUT = @interval;  
		COMMIT TRANSACTION;  
			  
		EXEC mdm.udpStagingProcessAllReadyToRun;  
  
	--Got an END DIALOG message  
	END ELSE IF (@message_type_name = CAST(N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog' AS NVARCHAR(128))) BEGIN  
		SET @need_new = 1;  
  
	--Got ERROR message  
	END ELSE IF (@message_type_name = CAST(N'http://schemas.microsoft.com/SQL/ServiceBroker/Error' AS NVARCHAR(128))) BEGIN  
		PRINT N'Error in udpStagingBatchQueueActivate error';  
		SET @need_new = 1;  
  
	--Timeout or unexpected message  
	END ELSE BEGIN   
		  
		COMMIT TRANSACTION;  
		  
	END; --if  
	  
	IF (@need_new = 1) BEGIN  
	  
		END CONVERSATION @handle;  
		  
		--DECLARE @handle UNIQUEIDENTIFIER; DECLARE @interval INT; SET @interval = 10;  
		BEGIN DIALOG CONVERSATION @handle  
			FROM SERVICE [microsoft/mdm/service/stagingbatch]  
			TO SERVICE N'microsoft/mdm/service/system'  
			WITH ENCRYPTION = OFF;  
		BEGIN CONVERSATION TIMER (@handle) TIMEOUT = @interval;  
  
		COMMIT TRANSACTION;  
					  
	END; --if  
  
	SET NOCOUNT OFF;  
END; --proc
GO
