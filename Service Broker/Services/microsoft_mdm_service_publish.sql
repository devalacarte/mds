CREATE SERVICE [microsoft/mdm/service/publish]
AUTHORIZATION [mds_schema_user]
ON QUEUE [mdm].[microsoft/mdm/queue/publish]
(
[microsoft/mdm/contract/publish]
)
GO
