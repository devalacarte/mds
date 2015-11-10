SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
This proc adds a message to the securitymember queue.  
It is called when ever a change has happened that affects(could) member security  
  
--Version3/Account - Entity example call  
Exec mdm.udpSecurityMemberQueueSave @Role_ID=1, @Version_ID=4, @Entity_ID=7  
  
select * FROM mdm.[microsoft/mdm/queue/securitymembertimer]  
select * FROM mdm.[microsoft/mdm/queue/securitymember]  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityMemberQueueSave]  
(  
    @Role_ID    INT = NULL, -- Users who pertain to this Role ID will have their member count cache cleared when security is processed. Leave NULL to clear the cached counts of all users.  
    @Version_ID INT,  
    @Entity_ID  INT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
    DECLARE @messages_conversation_group UNIQUEIDENTIFIER = 0x2 --This is a constant.  Its used is udpSecurityMemberQueueActivate as well  
    --Insert a Message into the Service Broker Queue  
    DECLARE @xml AS XML;  
    SET @xml = (  
        SELECT  
            @Role_ID AS [Role_ID],  
            @Version_ID AS [Version_ID],  
            @Entity_ID AS [Entity_ID]  
        FOR XML PATH('SecurityMemberCriteria'), ELEMENTS XSINIL --IsNull are really needed but they are there to keep the message the same  
    );  
      
    --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQuestSave: Adding message to queue, @Role_ID=' + CONVERT(NVARCHAR(MAX),@Role_ID) + N', @Version_ID=' + CONVERT(NVARCHAR(MAX),@Version_ID)+ N', @Entity_ID=' + CONVERT(NVARCHAR(MAX),@Entity_ID),GETDATE();  
    --try to get an existing conversation handle  
    DECLARE @conversationHandle UNIQUEIDENTIFIER = mdm.udfServiceGetConversationHandle(  
        N'microsoft/mdm/service/system',  
        N'microsoft/mdm/service/securitymember');  
      
    ----Start a new conversation if necessary  
    IF @conversationHandle IS NULL  
        BEGIN DIALOG CONVERSATION @conversationHandle  
            FROM SERVICE [microsoft/mdm/service/system]   
            TO SERVICE N'microsoft/mdm/service/securitymember'  
            ON CONTRACT [microsoft/mdm/contract/securitymember]   
            WITH ENCRYPTION=OFF; --is by default  
  
    --Send the message  
    SEND ON CONVERSATION @conversationHandle MESSAGE TYPE [microsoft/mdm/message/securitymember](@xml);  
  
    SET NOCOUNT OFF  
END --proc
GO
