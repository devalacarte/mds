CREATE TABLE [stg].[Customer_Consolidated]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[ImportType] [tinyint] NOT NULL,
[ImportStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_Customer_Consolidated_ImportStatus_ID] DEFAULT ((0)),
[Batch_ID] [int] NULL,
[BatchTag] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ErrorCode] [int] NULL,
[HierarchyName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Code] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [stg].[Customer_Consolidated] ADD CONSTRAINT [ck_Customer_Consolidated_ImportStatus_ID] CHECK (([ImportStatus_ID]>=(0) AND [ImportStatus_ID]<=(3)))
GO
ALTER TABLE [stg].[Customer_Consolidated] ADD CONSTRAINT [ck_Customer_Consolidated_ImportType] CHECK (([ImportType]>=(0) AND [ImportType]<=(4)))
GO
ALTER TABLE [stg].[Customer_Consolidated] ADD CONSTRAINT [pk_Customer_Consolidated] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_Customer_Consolidated_Batch_ID] ON [stg].[Customer_Consolidated] ([Batch_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_Customer_Consolidated_BatchTag] ON [stg].[Customer_Consolidated] ([BatchTag]) ON [PRIMARY]
GO
