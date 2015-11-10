CREATE TABLE [stg].[Customer_Relationship]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[RelationshipType] [tinyint] NOT NULL,
[ImportStatus_ID] [tinyint] NOT NULL,
[Batch_ID] [int] NULL,
[BatchTag] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ErrorCode] [int] NULL,
[HierarchyName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ParentCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ChildCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SortOrder] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [stg].[Customer_Relationship] ADD CONSTRAINT [ck_Customer_Relationship_ImportStatus_ID] CHECK (([ImportStatus_ID]>=(0) AND [ImportStatus_ID]<=(3)))
GO
ALTER TABLE [stg].[Customer_Relationship] ADD CONSTRAINT [ck_Customer_Relationship_RelationshipType] CHECK (([RelationshipType]>=(1) AND [RelationshipType]<=(2)))
GO
ALTER TABLE [stg].[Customer_Relationship] ADD CONSTRAINT [pk_Customer_Relationship] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_Customer_Relationship_Batch_ID] ON [stg].[Customer_Relationship] ([Batch_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_Customer_Relationship_BatchTag] ON [stg].[Customer_Relationship] ([BatchTag]) ON [PRIMARY]
GO
