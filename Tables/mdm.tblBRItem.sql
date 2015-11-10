CREATE TABLE [mdm].[tblBRItem]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[BRLogicalOperatorGroup_ID] [int] NOT NULL,
[BRItemAppliesTo_ID] [int] NOT NULL,
[Sequence] [int] NOT NULL,
[ItemText] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ItemSQL] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AnchorName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AnchorDataType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AnchorAttributeType] [int] NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblBRItem_MUID] DEFAULT (newid())
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRItem] ADD CONSTRAINT [pk_tblBRItem] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblBRItem_MUID] ON [mdm].[tblBRItem] ([MUID]) INCLUDE ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRItem] ADD CONSTRAINT [fk_tblBRItem_tblBRItemTypeAppliesTo_BRItemAppliesTo_ID] FOREIGN KEY ([BRItemAppliesTo_ID]) REFERENCES [mdm].[tblBRItemTypeAppliesTo] ([ID])
GO
ALTER TABLE [mdm].[tblBRItem] ADD CONSTRAINT [fk_tblBRItem_tblLogicalOperatorGroup_BRLogicalOperatorGroup_ID] FOREIGN KEY ([BRLogicalOperatorGroup_ID]) REFERENCES [mdm].[tblBRLogicalOperatorGroup] ([ID])
GO
