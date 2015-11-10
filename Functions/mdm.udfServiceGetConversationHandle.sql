SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
/*  
Function   : mdm.udfServiceGetConversationHandle  
Component  : Service Broker  
Description: mdm.udfServiceGetConversationHandle returns a GUID that is the current conversation handle between the two SSB services passed in.  
Parameters : sourceService, farService  
Return     : GUID queried from sys.conversation_endpoints  
Example 1  : SET @conversationHandle = mdm.udfServiceGetConversationHandle(N'microsoft/mdm/service/system', N'microsoft/mdm/service/securitymember')  
*/  
  
CREATE FUNCTION [mdm].[udfServiceGetConversationHandle]  
(  
    @sourceService NVARCHAR(100),   
    @farService NVARCHAR(100)  
)  
RETURNS UNIQUEIDENTIFIER  
WITH EXECUTE AS N'mds_schema_user' -- Execute as a user that, unlike mds_ssb_user, has permission to see the services defined in sys.services.  
AS  
BEGIN  
    DECLARE @conversationHandle UNIQUEIDENTIFIER = NULL;  
      
    --get the existing conversation handle if possible  
    SELECT   
        @conversationHandle = cep.conversation_handle  
    FROM sys.conversation_groups as cgs  
    INNER JOIN sys.services as svc  
        ON svc.service_id = cgs.service_id  
    INNER JOIN sys.conversation_endpoints as cep  
        ON cgs.conversation_group_id = cep.conversation_group_id  
    WHERE svc.name = @sourceService  
        AND cep.far_service = @farService  
        AND cep.state <> N'ER' --exclude conversations in a state of ERROR   
        AND cep.state <> N'CD' --CLOSED  
        AND cep.state <> N'DI' --Disconnected Inbound  
        AND cep.state <> N'DO' --Disconnected Outbound  
          
      
    RETURN @conversationHandle;  
END
GO
