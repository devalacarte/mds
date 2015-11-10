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
        FROM SERVICE [microsoft/mdm/service/securitymembertimer]    
        TO SERVICE N'microsoft/mdm/service/system'    
        WITH ENCRYPTION=OFF --is by default                
    BEGIN CONVERSATION TIMER (@handle) TIMEOUT = 30;    
      
    --This will disable the activation proc on the queue  
    --ALTER QUEUE [mdm].[microsoft/mdm/queue/securitymember] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = OFF , PROCEDURE_NAME = [mdm].[udpSecurityMemberQueueActivate] , MAX_QUEUE_READERS = 1 , EXECUTE AS OWNER  )  
    --This will Enable the activation proc on the queue  
    --ALTER QUEUE [mdm].[microsoft/mdm/queue/securitymember] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [mdm].[udpSecurityMemberQueueActivate] , MAX_QUEUE_READERS = 1 , EXECUTE AS OWNER  )  
                      
    --truncate table mdm.tblServiceBrokerLog  
    select * FROM mdm.[microsoft/mdm/queue/securitymembertimer]  
    select * FROM mdm.[microsoft/mdm/queue/securitymember]  
      
    --This will generate some actual work msgs  
    Exec mdm.udpSecurityMemberQueueSave 1, 2, 4  
    Exec mdm.udpSecurityMemberQueueSave 1, 2, 4  
    Exec mdm.udpSecurityMemberQueueSave 1, 2, 4  
      
    --Call this if you don't feel like waiting   
    --EXEC mdm.udpSecurityMemberQueueActivate  
      
    --Debug logging  
    --CREATE TABLE tblServiceBrokerLog (Description NVARCHAR(MAX),EnterDTM DATETIME)  
    select count(*) from mdm.tblServiceBrokerLog  
    select top 1000 *,getdate() as CurrentTime from mdm.tblServiceBrokerLog  
          
    --Helpful to figure out whats happening is SSSB  
    select * from sys.dm_broker_activated_tasks  
    select * from sys.dm_broker_connections  
    select * from sys.dm_broker_forwarded_messages  
    select * from sys.dm_broker_queue_monitors  
*/  
CREATE PROCEDURE [mdm].[udpSecurityMemberQueueActivate]  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE              
         @message_type_name sysname  
        ,@handle            UNIQUEIDENTIFIER  
        ,@msghandle         UNIQUEIDENTIFIER  
        ,@msgbody           XML  
        ,@interval          INT  
        ,@need_new          BIT  
        ,@status            NVARCHAR(1000)  
        ,@dialog            UNIQUEIDENTIFIER  
        ,@User_ID           INT  
        ,@TempVersionID     INT  
        ,@TempEntityID      INT  
        ,@UserIdList        mdm.IdList;  
          
        DECLARE @messages TABLE(handle UNIQUEIDENTIFIER,message_type_name NVARCHAR(256),message_body VARBINARY(MAX)) ;  
        DECLARE @workitems TABLE(RoleID INT, VersionID INT,EntityID INT);  
        DECLARE @dhinfo    TABLE(DerivedHierarchyID INT,EntityID INT,ParentEntityID INT);  
          
    --Initialize variables  
    SELECT @handle = NULL, @need_new = NULL;   
      
    --Load interval setting from config, and check the defaults and ranges  
    SELECT @interval = CAST(SettingValue AS INT) FROM mdm.tblSystemSetting WHERE SettingName = 'SecurityMemberProcessInterval';  
    IF @interval IS NULL SET @interval = 120; --Protect against NULL values  
    ELSE IF @interval < 10 SET @interval = 10; --Prevent negative and 'real-time' settings  
    ELSE IF @interval > 86400 SET @interval = 86400; --Check at least once per day (60 x 60 x 24)  
      
    BEGIN TRANSACTION   
  
    --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate, waiting for message...',GETDATE();  
      
    WAITFOR (  
        RECEIVE TOP(1)  
            @handle = [conversation_handle]  
            ,@message_type_name = message_type_name  
              
        FROM mdm.[microsoft/mdm/queue/securitymembertimer]          
    ), TIMEOUT 5000; --Always wait a constant time for any new messages  
      
    --Got a TIMER message  
    IF (@message_type_name = CAST(N'http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer' AS NVARCHAR(128))) BEGIN  
  
        --Start a new TIMER and COMMIT the transaction before we do the real work, to avoid poisoning  
        BEGIN CONVERSATION TIMER (@handle) TIMEOUT = @interval;  
        COMMIT TRANSACTION;  
        --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate: Got a timer msg',GETDATE()  
          
        --Look into the scuritymember queue to get the work items messages..  
        --gotta do this in a loop as the recieve statement will only get one conversation at a time  
        WHILE EXISTS(SELECT 1 FROM mdm.[microsoft/mdm/queue/securitymember])  
        BEGIN  
            --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate: Getting item from queue',GETDATE();  
            RECEIVE [conversation_handle]  
                ,message_type_name  
                ,message_body  
            FROM mdm.[microsoft/mdm/queue/securitymember]      
            INTO @messages                  
        END; --while  
              
        --DECLARE @firstMessage NVARCHAR(MAX) = COALESCE((SELECT TOP 1 CONVERT(NVARCHAR(MAX),message_body) FROM @messages), N'NULL');  
        --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate: Finished getting all work messages. First message body: ' + @firstMessage, GETDATE();  
                  
        --Loop thru the work item messages and create table with all distinct verion/entity combinations  
        WITH cte AS (SELECT CONVERT(XML, message_body) AS msg FROM @messages)  
        INSERT INTO @workitems(RoleID, VersionID, EntityID)  
        SELECT DISTINCT  
            msg.value('/SecurityMemberCriteria[1]/Role_ID[1]','int') AS [Role_ID],  
            msg.value('/SecurityMemberCriteria[1]/Version_ID[1]','int') AS Version_ID,  
            msg.value('/SecurityMemberCriteria[1]/Entity_ID[1]','int') AS Entity_ID  
        FROM cte;  
  
        DELETE FROM @messages; --We are finished working with it  
              
        --DECLARE @tempcountitems INT = (SELECT COUNT(1) FROM @workitems);  
        --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate: Finished getting all distinct combinations of role/version/entity.  Count: ' + CONVERT(NVARCHAR(MAX),@tempcountitems),GETDATE()  
          
        --Get ll the dependant entities.  
        --ie: Get all the entities in all the dereived hierarchies that these entities exist in.  
        IF EXISTS(SELECT 0 FROM @workitems)  
        BEGIN  
            WITH dhLevel AS  
            (  
                SELECT  
                     dh.ID AS DerivedHierarchy_ID  
                    ,CASE dhd.ForeignType_ID WHEN 0 THEN dhd.Foreign_ID WHEN 1 THEN a.DomainEntity_ID ELSE NULL END AS [EntityID]   
                    ,CASE dhd.ForeignType_ID WHEN 1 THEN a.Entity_ID ELSE NULL END AS [ParentEntityID]  
                FROM mdm.tblDerivedHierarchy AS dh  
                INNER JOIN mdm.tblDerivedHierarchyDetail AS dhd ON (dh.ID = dhd.DerivedHierarchy_ID) --Ensures that DH has at least one defined level  
                LEFT JOIN mdm.tblAttribute AS a ON (dhd.Foreign_ID = a.ID) --Levels join via DBAs  
            ),  
            relateditemsAll as --This could/will also include the original items  
            (  
                SELECT DISTINCT   
                    W.RoleID,  
                    W.VersionID,  
                    cte.EntityID   
                FROM dhLevel AS cte  
                INNER JOIN @workitems W ON W.EntityID = cte.[ParentEntityID]  
            ),  
            relateditems as  
            (  
                SELECT   
                    A.RoleID,  
                    A.VersionID,  
                    A.EntityID  
                FROM   
                    relateditemsAll AS A   
                LEFT JOIN @workitems AS B ON A.EntityID = B.EntityID AND A.VersionID = B.VersionID  
                WHERE  
                    B.EntityID IS NULL  
                    AND B.VersionID IS NULL          
            )  
            INSERT INTO @workitems   
            SELECT  
                RoleID,  
                VersionID,  
                EntityID   
            FROM relateditems  
        END; --if  
              
        --SET @tempcountitems = (select COUNT(0) FROM @workitems);  
        --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate: Finished getting all related entities for the combinations of role/version/entity.  Total Count: ' + CONVERT(NVARCHAR(MAX),@tempcountitems),GETDATE()  
                  
        --Loop thru the workitems table and call the process sproc  
        WHILE EXISTS(SELECT 0 FROM @workitems)  
        BEGIN          
            BEGIN TRANSACTION  
  
            BEGIN TRY                  
                SELECT TOP 1   
                     @TempVersionID = VersionID  
                    ,@TempEntityID = EntityID   
                FROM @workitems   
                ORDER BY VersionID, EntityID;  
                  
                -- Get all user IDs that apply to the current version and entity.  
                DELETE FROM @UserIdList;  
                INSERT INTO  
                    @UserIdList  
                SELECT DISTINCT  
                    u.[User_ID]  
                FROM   
                    mdm.viw_SYSTEM_SECURITY_USER_ROLE u  
                INNER JOIN @workitems w  
                    ON      u.Role_ID   = w.RoleID  
                        AND w.VersionID = @TempVersionID  
                        AND w.EntityID  = @TempEntityID  
  
                --SET @tempcountitems = (select COUNT(0) FROM @UserIdList);  
                --DECLARE @firstUserId INT = (SELECT TOP 1 ID FROM @UserIdList);  
                --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate: UserIDs Total Count: ' + CONVERT(NVARCHAR(MAX),@tempcountitems) + N', First UserID: ' + CONVERT(NVARCHAR(MAX), @firstUserId), GETDATE()  
  
                --Delete from the temp table  
                DELETE FROM @workitems WHERE VersionID=@TempVersionID AND EntityID=@TempEntityID;  
                --Delete it at top in case of error  
                  
                --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate:  Creating member security items for Entity: ' + CONVERT(NVARCHAR(MAX),@TempEntityID) + ' and VersionID: ' + CONVERT(NVARCHAR(100),@TempVersionID),GETDATE();  
                EXEC mdm.udpSecurityMemberProcess @Version_ID=@TempVersionID, @Entity_ID=@TempEntityID, @UserIdList=@UserIdList;  
                --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate:  Finished member security items for Entity: ' + CONVERT(NVARCHAR(MAX),@TempEntityID) + ' and VersionID: ' + CONVERT(NVARCHAR(100),@TempVersionID),GETDATE();  
                COMMIT TRANSACTION  
            END TRY  
            BEGIN CATCH  
                --INSERT INTO mdm.tblServiceBrokerLog SELECT 'In the workitems loop: catch',GETDATE()  
                ROLLBACK TRANSACTION  
            END CATCH              
        END; --while  
        --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate: Finished processing all security member maps for all the combinations of version/entity',GETDATE()  
          
    --Got an END DIALOG message  
    END ELSE IF (@message_type_name = CAST(N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog' AS NVARCHAR(128))) BEGIN  
        --INSERT INTO mdm.tblServiceBrokerLog SELECT  N'udpSecurityMemberQueueActivate: end dialog',GETDATE();  
        SET @need_new = 1;  
  
    --Got ERROR message  
    END ELSE IF (@message_type_name = CAST(N'http://schemas.microsoft.com/SQL/ServiceBroker/Error' AS NVARCHAR(128))) BEGIN  
        --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate: Error',GETDATE();  
        SET @need_new = 1;  
  
    --Timeout or unexpected message  
    END ELSE BEGIN   
        --INSERT INTO mdm.tblServiceBrokerLog SELECT 'udpSecurityMemberQueueActivate: Else: ' + CONVERT(NVARCHAR(MAX),ISNULL(@handle,'NULL')) + '-' + ISNULL(@message_type_name,'NULL'),GETDATE();  
        COMMIT TRANSACTION;  
          
    END; --if  
      
    IF (@need_new = 1) BEGIN  
      
        END CONVERSATION @handle;  
                  
        BEGIN DIALOG CONVERSATION @handle  
            FROM SERVICE [microsoft/mdm/service/securitymembertimer]  
            TO SERVICE N'microsoft/mdm/service/system'  
            WITH ENCRYPTION = OFF;  
        BEGIN CONVERSATION TIMER (@handle) TIMEOUT = @interval;  
  
        COMMIT TRANSACTION;  
                      
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
