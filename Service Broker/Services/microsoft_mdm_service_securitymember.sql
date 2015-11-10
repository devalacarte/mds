CREATE SERVICE [microsoft/mdm/service/securitymember]
AUTHORIZATION [mds_schema_user]
ON QUEUE [mdm].[microsoft/mdm/queue/securitymember]
(
[microsoft/mdm/contract/securitymember]
)
GO
