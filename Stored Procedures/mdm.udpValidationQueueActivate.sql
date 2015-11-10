SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
--Create SSB items  
CREATE QUEUE [mdm].[microsoft/mdm/queue/validation] WITH STATUS = ON , RETENTION = OFF  ON [PRIMARY]   
CREATE SERVICE [microsoft/mdm/service/validation]  AUTHORIZATION [dbo]  ON QUEUE [mdm].[microsoft/mdm/queue/validation] ([microsoft/mdm/contract/validation])  
CREATE MESSAGE TYPE [microsoft/mdm/message/validation] AUTHORIZATION [dbo] VALIDATION = WELL_FORMED_XML  
CREATE CONTRACT [microsoft/mdm/contract/validation] AUTHORIZATION [dbo] ([microsoft/mdm/message/validation] SENT BY INITIATOR)  
  
  
--Alter the queue to use the SP we just created in an activated manner  
ALTER QUEUE mdm.[microsoft/mdm/queue/validation]  
WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [mdm].[udpValidationQueueActivate] , MAX_QUEUE_READERS = 1 , EXECUTE AS CALLER  )  
  
*/  
CREATE PROCEDURE [mdm].[udpValidationQueueActivate]  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE			  
		 @message_type_name	sysname  
		,@handle			UNIQUEIDENTIFIER  
		,@interval			INT  
		,@body				XML  
		,@need_new			BIT;  
	  
	--Initialize variables  
	SELECT @handle = NULL, @need_new = NULL;   
	  
	--Load interval setting from config, and check the defaults and ranges  
	SET @interval = 120; --Protect against NULL values  
	  
	BEGIN TRANSACTION   
  
	WAITFOR (  
		RECEIVE TOP(1)  
			@handle = [conversation_handle],  
			@message_type_name = message_type_name,  
			@body = CONVERT(XML,message_body)  
		FROM mdm.[microsoft/mdm/queue/validation]		  
	), TIMEOUT 5000; --Always wait a constant time for any new messages  
			  
	--Got a TIMER message  
	IF (@message_type_name = N'microsoft/mdm/message/validation') BEGIN  
  
		--Start a new TIMER and COMMIT the transaction before we do the real work, to avoid poisoning  
		BEGIN CONVERSATION TIMER (@handle) TIMEOUT = @interval;  
		COMMIT TRANSACTION;  
		PRINT 'ValidationQueue received message';	  
		--Do the real work here - run validation  
		DECLARE 				  
				@User_ID	INT,  
				@Model_ID	INT,  
				@Version_ID INT,  
				@Entity_ID	INT,  
				@Member_ID	INT,  
				@MemberType_ID TINYINT,  
				@CommitVersion TINYINT;  
		  
		SET @User_ID = @body.value('/ValidationCriteria[1]/User_ID[1]','int');  
		SET @Model_ID = @body.value('/ValidationCriteria[1]/Model_ID[1]','int');  
		SET @Version_ID = @body.value('/ValidationCriteria[1]/Version_ID[1]','int');  
		SET @Entity_ID = @body.value('/ValidationCriteria[1]/Entity_ID[1]','int');  
		SET @Member_ID = @body.value('/ValidationCriteria[1]/Member_ID[1]','int');  
		SET @MemberType_ID = @body.value('/ValidationCriteria[1]/MemberType_ID[1]','int');  
		SET @CommitVersion = @body.value('/ValidationCriteria[1]/CommitVersion[1]','TINYINT');  
  
		IF ISNULL(@Member_ID,0) = 0  
			BEGIN  
				PRINT 'ValidationQueue processing model'	  
				IF @CommitVersion = 1  
					BEGIN  
						EXEC mdm.udpValidateModel @User_ID=@User_ID,@Model_ID=@Model_ID,@Version_ID=@Version_ID,@Status_ID=3 --Status of 3 is Committed  
					END  
				ELSE  
					BEGIN  
						EXEC mdm.udpValidateModel @User_ID=@User_ID,@Model_ID=@Model_ID,@Version_ID=@Version_ID,@Status_ID=0  
					END  
			END  
		ELSE  
			BEGIN  
				PRINT 'ValidationQueue processing member'  
				EXEC mdm.udpValidateMember @User_ID=@User_ID,@Version_ID=@Version_ID,@Entity_ID=@Entity_ID,@Member_ID=@Member_ID,@MemberType_ID=@MemberType_ID,@ReturnResults=0  
			END  
		PRINT 'ValidationQueue processed message';	  
  
	--Got an END DIALOG message  
	END ELSE IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog') BEGIN  
  
		PRINT 'ValidationQueue EndDialog'  
  
	--Got ERROR message  
	END ELSE IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error') BEGIN  
  
		PRINT 'ValidationQueue Error'  
  
	--Timeout or unexpected message  
	END ELSE BEGIN   
		  
		COMMIT TRANSACTION;  
		  
	END; --if  
	  
	SET NOCOUNT OFF;  
END --proc
GO
