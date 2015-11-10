CREATE QUEUE [mdm].[microsoft/mdm/queue/stagingbatch] 
WITH STATUS=ON, 
RETENTION=OFF,
POISON_MESSAGE_HANDLING (STATUS=ON), 
ACTIVATION (
STATUS=ON, 
PROCEDURE_NAME=[mdm].[udpStagingBatchQueueActivate], 
MAX_QUEUE_READERS=1, 
EXECUTE AS N'mds_ssb_user'
)
ON [PRIMARY]
