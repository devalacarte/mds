CREATE TABLE [stg].[SalesDistrict_Leaf]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[ImportType] [tinyint] NOT NULL,
[ImportStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_SalesDistrict_Leaf_ImportStatus_ID] DEFAULT ((0)),
[Batch_ID] [int] NULL,
[BatchTag] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ErrorCode] [int] NULL,
[Code] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SalesLocation] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [stg].[SalesDistrict_Leaf] ADD CONSTRAINT [ck_SalesDistrict_Leaf_ImportStatus_ID] CHECK (([ImportStatus_ID]>=(0) AND [ImportStatus_ID]<=(3)))
GO
ALTER TABLE [stg].[SalesDistrict_Leaf] ADD CONSTRAINT [ck_SalesDistrict_Leaf_ImportType] CHECK (([ImportType]>=(0) AND [ImportType]<=(6)))
GO
ALTER TABLE [stg].[SalesDistrict_Leaf] ADD CONSTRAINT [pk_SalesDistrict_Leaf] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_SalesDistrict_Leaf_Batch_ID] ON [stg].[SalesDistrict_Leaf] ([Batch_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_SalesDistrict_Leaf_BatchTag] ON [stg].[SalesDistrict_Leaf] ([BatchTag]) ON [PRIMARY]
GO
