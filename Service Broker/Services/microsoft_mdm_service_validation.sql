CREATE SERVICE [microsoft/mdm/service/validation]
AUTHORIZATION [mds_schema_user]
ON QUEUE [mdm].[microsoft/mdm/queue/validation]
(
[microsoft/mdm/contract/validation]
)
GO
