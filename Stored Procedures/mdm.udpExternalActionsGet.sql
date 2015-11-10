SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpExternalActionsGet]  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE			  
		 @message_type_name	sysname  
		,@handle			UNIQUEIDENTIFIER  
		,@body				XML;  
	  
	--Initialize variables  
	SELECT @handle = NULL;   
	  
	BEGIN TRANSACTION   
  
	WAITFOR (  
		RECEIVE TOP(1)  
			@handle = [conversation_handle],  
			@message_type_name = message_type_name,  
			@body = CONVERT(XML,message_body)  
		FROM mdm.[microsoft/mdm/queue/externalaction]		  
	), TIMEOUT 5000; --Always wait a constant time for any new messages  
			  
	--Got a TIMER message  
	IF (@message_type_name = N'microsoft/mdm/message/externalaction') BEGIN  
  
		COMMIT TRANSACTION;  
		PRINT 'ExternalActionQueue received message';	  
		SELECT @body  
  
	--Got an END DIALOG message  
	END ELSE IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog') BEGIN  
  
		PRINT 'ExternalActionQueue EndDialog'  
  
	--Got ERROR message  
	END ELSE IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error') BEGIN  
  
		PRINT 'ExternalActionQueue Error'  
  
	--Timeout or unexpected message  
	END ELSE BEGIN   
		  
		COMMIT TRANSACTION;  
		  
	END; --if  
	  
	SET NOCOUNT OFF;  
END --proc
GO
