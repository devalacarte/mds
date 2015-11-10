CREATE QUEUE [mdm].[microsoft/mdm/queue/notification] 
WITH STATUS=ON, 
RETENTION=OFF,
POISON_MESSAGE_HANDLING (STATUS=ON), 
ACTIVATION (
STATUS=ON, 
PROCEDURE_NAME=[mdm].[udpNotificationQueueActivate], 
MAX_QUEUE_READERS=1, 
EXECUTE AS N'mds_email_user'
)
ON [PRIMARY]
