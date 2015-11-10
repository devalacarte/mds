SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
--Entity -Errors on temp table  
Exec mdm.udpValidationQueueSave 1, 7,20, 33, null,null  
--MEmber - works fine  
Exec mdm.udpValidationQueueSave 1, 7,20, 33, 188,1  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpValidationQueueSave]  
(  
	@User_ID	INT,   
	@Model_ID	INT,  
	@Version_ID INT,  
    @Entity_ID	INT = NULL,  
	@Member_ID	INT = NULL,  
	@MemberType_ID	INT = NULL,  
	@CommitVersion	TINYINT = NULL --1=Commit, otherwise do not commit the version  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
	--Insert a Message into the Service Broker Queue  
	DECLARE @xml AS XML;  
	SET @xml = (  
		SELECT  
			@User_ID AS [User_ID],  
			@Model_ID AS [Model_ID],  
			@Version_ID AS [Version_ID],  
			@Entity_ID AS [Entity_ID],  
			@Member_ID AS [Member_ID],  
			@MemberType_ID AS [MemberType_ID],  
			@CommitVersion AS [CommitVersion]  
		FOR XML PATH('ValidationCriteria'), ELEMENTS  
	);  
  
    --try to get an existing conversation handle  
    DECLARE @conversationHandle UNIQUEIDENTIFIER = mdm.udfServiceGetConversationHandle(  
        N'microsoft/mdm/service/system',  
        N'microsoft/mdm/service/validation');  
  
    --Start a new conversation if necessary  
    IF @conversationHandle IS NULL  
        BEGIN DIALOG @conversationHandle  
            FROM SERVICE [microsoft/mdm/service/system]   
            TO SERVICE N'microsoft/mdm/service/validation'  
            ON CONTRACT [microsoft/mdm/contract/validation]   
            WITH ENCRYPTION = OFF;  
  
    --Send a sample message  
    SEND ON CONVERSATION @conversationHandle MESSAGE TYPE [microsoft/mdm/message/validation](@xml);  
  
    SET NOCOUNT OFF  
END --proc
GO
