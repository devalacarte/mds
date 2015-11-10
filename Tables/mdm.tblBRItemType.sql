CREATE TABLE [mdm].[tblBRItemType]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Priority] [int] NOT NULL,
[PropertyDelimiter] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblBRItemType_MUID] DEFAULT (newid())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRItemType] ADD CONSTRAINT [pk_tblBRItemType] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblBRItemType_MUID] ON [mdm].[tblBRItemType] ([MUID]) INCLUDE ([ID]) ON [PRIMARY]
GO
