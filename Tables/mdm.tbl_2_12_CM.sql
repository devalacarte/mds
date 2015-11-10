CREATE TABLE [mdm].[tbl_2_12_CM]
(
[Version_ID] [int] NOT NULL,
[ID] [int] NOT NULL IDENTITY(1, 1),
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_2_12_CM_Status_ID] DEFAULT ((1)),
[Parent_CN_ID] [int] NOT NULL,
[ChildType_ID] [tinyint] NOT NULL,
[Child_EN_ID] [int] NULL,
[Child_HP_ID] [int] NULL,
[Child_CN_ID] [int] NULL,
[SortOrder] [int] NOT NULL,
[Weight] [decimal] (10, 3) NOT NULL CONSTRAINT [df_tbl_2_12_CM_Weight] DEFAULT ((1.0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_2_12_CM_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_2_12_CM_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL,
[AsOf_ID] [int] NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tbl_2_12_CM_MUID] DEFAULT (newid())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_2_12_CM] ADD CONSTRAINT [ck_tbl_2_12_CM_ChildType_ID] CHECK (([ChildType_ID]=(1) AND [Child_EN_ID] IS NOT NULL AND [Child_HP_ID] IS NULL AND [Child_CN_ID] IS NULL OR [ChildType_ID]=(2) AND [Child_HP_ID] IS NOT NULL AND [Child_EN_ID] IS NULL AND [Child_CN_ID] IS NULL OR [ChildType_ID]=(3) AND [Child_CN_ID] IS NOT NULL AND [Child_EN_ID] IS NULL AND [Child_HP_ID] IS NULL))
GO
ALTER TABLE [mdm].[tbl_2_12_CM] ADD CONSTRAINT [ck_tbl_2_12_CM_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(2)))
GO
ALTER TABLE [mdm].[tbl_2_12_CM] ADD CONSTRAINT [ck_tbl_2_12_CM_Parent_CN_ID_Child_CN_ID] CHECK ((NOT ([ChildType_ID]=(3) AND [Parent_CN_ID]=[Child_CN_ID])))
GO
ALTER TABLE [mdm].[tbl_2_12_CM] ADD CONSTRAINT [pk_tbl_2_12_CM] PRIMARY KEY NONCLUSTERED  ([Version_ID], [ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_CM_Version_ID_AsOf_ID] ON [mdm].[tbl_2_12_CM] ([Version_ID], [AsOf_ID]) WHERE ([AsOf_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_CM_Version_ID_Child_CN_ID] ON [mdm].[tbl_2_12_CM] ([Version_ID], [Child_CN_ID]) WHERE ([Child_CN_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_CM_Version_ID_Child_EN_ID] ON [mdm].[tbl_2_12_CM] ([Version_ID], [Child_EN_ID]) WHERE ([Child_EN_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_CM_Version_ID_Child_HP_ID] ON [mdm].[tbl_2_12_CM] ([Version_ID], [Child_HP_ID]) WHERE ([Child_HP_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_CM_Version_ID_Parent_CN_ID] ON [mdm].[tbl_2_12_CM] ([Version_ID], [Parent_CN_ID]) ON [PRIMARY]
GO
CREATE UNIQUE CLUSTERED INDEX [ux_tbl_2_12_CM_Version_ID_Parent_CN_ID_ChildType_ID_Child_CN_ID_Child_HP_ID_Child_EN_ID] ON [mdm].[tbl_2_12_CM] ([Version_ID], [Parent_CN_ID], [ChildType_ID], [Child_CN_ID], [Child_HP_ID], [Child_EN_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_2_12_CM] ADD CONSTRAINT [fk_tbl_2_12_CM_tblModelVersion_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID])
GO
ALTER TABLE [mdm].[tbl_2_12_CM] ADD CONSTRAINT [fk_tbl_2_12_CM_tbl_2_12_CN_Child_CN_ID] FOREIGN KEY ([Version_ID], [Child_CN_ID]) REFERENCES [mdm].[tbl_2_12_CN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_2_12_CM] ADD CONSTRAINT [fk_tbl_2_12_CM_tbl_2_12_EN_Child_EN_ID] FOREIGN KEY ([Version_ID], [Child_EN_ID]) REFERENCES [mdm].[tbl_2_12_EN] ([Version_ID], [ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tbl_2_12_CM] ADD CONSTRAINT [fk_tbl_2_12_CM_tbl_2_12_HP_Child_HP_ID] FOREIGN KEY ([Version_ID], [Child_HP_ID]) REFERENCES [mdm].[tbl_2_12_HP] ([Version_ID], [ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tbl_2_12_CM] ADD CONSTRAINT [fk_tbl_2_12_CM_tbl_2_12_CN_Parent_CN_ID] FOREIGN KEY ([Version_ID], [Parent_CN_ID]) REFERENCES [mdm].[tbl_2_12_CN] ([Version_ID], [ID]) ON DELETE CASCADE
GO
