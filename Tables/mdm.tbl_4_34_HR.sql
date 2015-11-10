CREATE TABLE [mdm].[tbl_4_34_HR]
(
[Version_ID] [int] NOT NULL,
[ID] [int] NOT NULL IDENTITY(1, 1),
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_4_34_HR_Status_ID] DEFAULT ((1)),
[ValidationStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_4_34_HR_ValidationStatus_ID] DEFAULT ((0)),
[Hierarchy_ID] [int] NOT NULL,
[Parent_HP_ID] [int] NULL,
[ChildType_ID] [tinyint] NOT NULL,
[Child_EN_ID] [int] NULL,
[Child_HP_ID] [int] NULL,
[SortOrder] [int] NOT NULL,
[LevelNumber] [smallint] NOT NULL CONSTRAINT [df_tbl_4_34_HR_LevelNumber_ID] DEFAULT ((-1)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_4_34_HR_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_4_34_HR_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL,
[AsOf_ID] [int] NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tbl_4_34_HR_MUID] DEFAULT (newid())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_4_34_HR] ADD CONSTRAINT [ck_tbl_4_34_HR_ChildType_ID] CHECK (([ChildType_ID]=(1) AND [Child_EN_ID] IS NOT NULL AND [Child_HP_ID] IS NULL OR [ChildType_ID]=(2) AND [Child_HP_ID] IS NOT NULL AND [Child_EN_ID] IS NULL))
GO
ALTER TABLE [mdm].[tbl_4_34_HR] ADD CONSTRAINT [ck_tbl_4_34_HR_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(2)))
GO
ALTER TABLE [mdm].[tbl_4_34_HR] ADD CONSTRAINT [ck_tbl_4_34_HR_ValidationStatus_ID] CHECK (([ValidationStatus_ID]>=(0) AND [ValidationStatus_ID]<=(5)))
GO
ALTER TABLE [mdm].[tbl_4_34_HR] ADD CONSTRAINT [ck_tbl_4_34_HR_Parent_HP_ID_Child_HP_ID] CHECK ((NOT ([ChildType_ID]=(2) AND [Parent_HP_ID]=[Child_HP_ID])))
GO
ALTER TABLE [mdm].[tbl_4_34_HR] ADD CONSTRAINT [pk_tbl_4_34_HR] PRIMARY KEY NONCLUSTERED  ([Version_ID], [ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_HR_Version_ID_AsOf_ID] ON [mdm].[tbl_4_34_HR] ([Version_ID], [AsOf_ID]) WHERE ([AsOf_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_HR_Version_ID_Child_EN_ID] ON [mdm].[tbl_4_34_HR] ([Version_ID], [Child_EN_ID]) WHERE ([Child_EN_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_HR_Version_ID_Child_HP_ID] ON [mdm].[tbl_4_34_HR] ([Version_ID], [Child_HP_ID]) WHERE ([Child_HP_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_HR_Version_ID_ChildType_ID_Hierarchy_ID_Child_EN_ID] ON [mdm].[tbl_4_34_HR] ([Version_ID], [ChildType_ID], [Hierarchy_ID], [Child_EN_ID]) ON [PRIMARY]
GO
CREATE UNIQUE CLUSTERED INDEX [ux_tbl_4_34_HR_Version_ID_Hierarchy_ID_ChildType_ID_Child_HP_ID_Child_EN_ID] ON [mdm].[tbl_4_34_HR] ([Version_ID], [Hierarchy_ID], [ChildType_ID], [Child_HP_ID], [Child_EN_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_HR_Version_ID_Hierarchy_ID_Parent_HP_ID] ON [mdm].[tbl_4_34_HR] ([Version_ID], [Hierarchy_ID], [Parent_HP_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_HR_Version_ID_Parent_HP_ID] ON [mdm].[tbl_4_34_HR] ([Version_ID], [Parent_HP_ID]) WHERE ([Parent_HP_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_HR_Version_ID_Status_ID_Parent_HP_ID_ChildType_ID_Child_EN_ID_Child_HP_ID_Asof_ID] ON [mdm].[tbl_4_34_HR] ([Version_ID], [Status_ID], [Parent_HP_ID], [ChildType_ID], [Child_EN_ID], [Child_HP_ID], [AsOf_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_4_34_HR] ADD CONSTRAINT [fk_tbl_4_34_HR_tblHierarchy_Hierarchy_ID] FOREIGN KEY ([Hierarchy_ID]) REFERENCES [mdm].[tblHierarchy] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tbl_4_34_HR] ADD CONSTRAINT [fk_tbl_4_34_HR_tblModelVersion_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID])
GO
ALTER TABLE [mdm].[tbl_4_34_HR] ADD CONSTRAINT [fk_tbl_4_34_HR_tbl_4_34_EN_Child_EN_ID] FOREIGN KEY ([Version_ID], [Child_EN_ID]) REFERENCES [mdm].[tbl_4_34_EN] ([Version_ID], [ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tbl_4_34_HR] ADD CONSTRAINT [fk_tbl_4_34_HR_tbl_4_34_HP_Child_HP_ID] FOREIGN KEY ([Version_ID], [Child_HP_ID]) REFERENCES [mdm].[tbl_4_34_HP] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_4_34_HR] ADD CONSTRAINT [fk_tbl_4_34_HR_tbl_4_34_HP_Parent_HP_ID] FOREIGN KEY ([Version_ID], [Parent_HP_ID]) REFERENCES [mdm].[tbl_4_34_HP] ([Version_ID], [ID])
GO
