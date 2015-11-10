CREATE SERVICE [microsoft/mdm/service/notification]
AUTHORIZATION [mds_schema_user]
ON QUEUE [mdm].[microsoft/mdm/queue/notification]
GO
