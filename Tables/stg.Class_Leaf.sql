CREATE TABLE [stg].[Class_Leaf]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[ImportType] [tinyint] NOT NULL,
[ImportStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_Class_Leaf_ImportStatus_ID] DEFAULT ((0)),
[Batch_ID] [int] NULL,
[BatchTag] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ErrorCode] [int] NULL,
[Code] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [stg].[Class_Leaf] ADD CONSTRAINT [ck_Class_Leaf_ImportStatus_ID] CHECK (([ImportStatus_ID]>=(0) AND [ImportStatus_ID]<=(3)))
GO
ALTER TABLE [stg].[Class_Leaf] ADD CONSTRAINT [ck_Class_Leaf_ImportType] CHECK (([ImportType]>=(0) AND [ImportType]<=(6)))
GO
ALTER TABLE [stg].[Class_Leaf] ADD CONSTRAINT [pk_Class_Leaf] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_Class_Leaf_Batch_ID] ON [stg].[Class_Leaf] ([Batch_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_Class_Leaf_BatchTag] ON [stg].[Class_Leaf] ([BatchTag]) ON [PRIMARY]
GO
