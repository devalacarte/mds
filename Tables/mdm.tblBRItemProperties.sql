CREATE TABLE [mdm].[tblBRItemProperties]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[BRItem_ID] [int] NOT NULL,
[PropertyType_ID] [int] NOT NULL,
[PropertyName_ID] [int] NOT NULL,
[Value] [nvarchar] (999) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Sequence] [int] NOT NULL,
[IsLeftHandSide] [bit] NOT NULL,
[Parent_ID] [int] NULL,
[SuppressText] [bit] NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblBRItemProperties_MUID] DEFAULT (newid())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRItemProperties] ADD CONSTRAINT [pk_tblBRItemProperties] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblBRItemProperties_MUID] ON [mdm].[tblBRItemProperties] ([MUID]) INCLUDE ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRItemProperties] ADD CONSTRAINT [fk_tblBRItemProperties_tblBRItem_BRItem_ID] FOREIGN KEY ([BRItem_ID]) REFERENCES [mdm].[tblBRItem] ([ID])
GO
