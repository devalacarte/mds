CREATE SERVICE [microsoft/mdm/service/externalaction]
AUTHORIZATION [mds_schema_user]
ON QUEUE [mdm].[microsoft/mdm/queue/externalaction]
(
[microsoft/mdm/contract/externalaction]
)
GO
