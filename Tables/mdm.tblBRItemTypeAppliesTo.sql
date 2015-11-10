CREATE TABLE [mdm].[tblBRItemTypeAppliesTo]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[BRItemType_ID] [int] NOT NULL,
[ApplyTo_ID] [int] NOT NULL,
[Sequence] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRItemTypeAppliesTo] ADD CONSTRAINT [pk_tblBRItemTypeAppliesTo] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRItemTypeAppliesTo] ADD CONSTRAINT [fk_tblBRItemTypeAppliesTo_tblListRelationship_ApplyTo_ID] FOREIGN KEY ([ApplyTo_ID]) REFERENCES [mdm].[tblListRelationship] ([ID])
GO
ALTER TABLE [mdm].[tblBRItemTypeAppliesTo] ADD CONSTRAINT [fk_tblBRItemTypeAppliesTo_tblBRItemType_BRItemType_ID] FOREIGN KEY ([BRItemType_ID]) REFERENCES [mdm].[tblBRItemType] ([ID])
GO
