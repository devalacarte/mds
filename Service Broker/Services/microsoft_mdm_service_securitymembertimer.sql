CREATE SERVICE [microsoft/mdm/service/securitymembertimer]
AUTHORIZATION [mds_schema_user]
ON QUEUE [mdm].[microsoft/mdm/queue/securitymembertimer]
(
[microsoft/mdm/contract/securitymembertimer]
)
GO
