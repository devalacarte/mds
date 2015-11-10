CREATE TABLE [mdm].[tblAttributeGroupDetail]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblAttributeGroupDetail_MUID] DEFAULT (newid()),
[AttributeGroup_ID] [int] NOT NULL,
[Attribute_ID] [int] NOT NULL,
[SortOrder] [int] NOT NULL,
[DomainBinding] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TransformGroup_ID] [int] NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblAttributeGroupDetail_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblAttributeGroupDetail_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttributeGroupDetail] ADD CONSTRAINT [pk_tblAttributeGroupDetail] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttributeGroupDetail] ADD CONSTRAINT [ux_tblAttributeGroupDetail_AttributeGroup_ID_Attribute_ID] UNIQUE NONCLUSTERED  ([AttributeGroup_ID], [Attribute_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttributeGroupDetail] ADD CONSTRAINT [ux_tblAttributeGroupDetail_MUID] UNIQUE NONCLUSTERED  ([MUID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblAttributeGroupDetail_Attribute_ID] ON [mdm].[tblAttributeGroupDetail] ([Attribute_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttributeGroupDetail] ADD CONSTRAINT [fk_tblAttributeGroupDetail_tblAttribute_AttributeID] FOREIGN KEY ([Attribute_ID]) REFERENCES [mdm].[tblAttribute] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblAttributeGroupDetail] ADD CONSTRAINT [fk_tblAttributeGroupDetail_tblAttribute_AttributeGroup_ID] FOREIGN KEY ([AttributeGroup_ID]) REFERENCES [mdm].[tblAttributeGroup] ([ID]) ON DELETE CASCADE
GO
