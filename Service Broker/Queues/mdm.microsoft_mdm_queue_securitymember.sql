CREATE QUEUE [mdm].[microsoft/mdm/queue/securitymember] 
WITH STATUS=ON, 
RETENTION=OFF,
POISON_MESSAGE_HANDLING (STATUS=ON)
ON [PRIMARY]
