CREATE TABLE [mdm].[tbl_1_5_MS]
(
[Version_ID] [int] NOT NULL,
[SecurityRole_ID] [int] NOT NULL,
[MemberType_ID] [tinyint] NOT NULL,
[EN_ID] [int] NULL,
[HP_ID] [int] NULL,
[Privilege_ID] [tinyint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_1_5_MS] ADD CONSTRAINT [ck_tbl_1_5_MS_MemberType_ID] CHECK (([MemberType_ID]=(1) AND [EN_ID] IS NOT NULL AND [HP_ID] IS NULL OR [MemberType_ID]=(2) AND [HP_ID] IS NOT NULL AND [EN_ID] IS NULL))
GO
ALTER TABLE [mdm].[tbl_1_5_MS] ADD CONSTRAINT [fk_tbl_1_5_MS_Privilege_ID] CHECK (([Privilege_ID]>=(1) AND [Privilege_ID]<=(3)))
GO
CREATE NONCLUSTERED INDEX [ix_tbl_1_5_MS_SecurityRole_ID] ON [mdm].[tbl_1_5_MS] ([SecurityRole_ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tbl_1_5_MS_Version_ID_EN_ID_SecurityRole_ID] ON [mdm].[tbl_1_5_MS] ([Version_ID], [EN_ID], [SecurityRole_ID]) WHERE ([EN_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tbl_1_5_MS_Version_ID_HP_ID_SecurityRole_ID] ON [mdm].[tbl_1_5_MS] ([Version_ID], [HP_ID], [SecurityRole_ID]) WHERE ([HP_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE UNIQUE CLUSTERED INDEX [ux_tbl_1_5_MS_Version_ID_SecurityRole_ID_MemberType_ID_EN_ID_HP_ID] ON [mdm].[tbl_1_5_MS] ([Version_ID], [SecurityRole_ID], [MemberType_ID], [EN_ID], [HP_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_1_5_MS] ADD CONSTRAINT [fk_tbl_1_5_MS_tblSecurityRole_SecurityRole_ID] FOREIGN KEY ([SecurityRole_ID]) REFERENCES [mdm].[tblSecurityRole] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tbl_1_5_MS] ADD CONSTRAINT [fk_tbl_1_5_MS_tbl_1_5_EN_Version_ID_EN_ID] FOREIGN KEY ([Version_ID], [EN_ID]) REFERENCES [mdm].[tbl_1_5_EN] ([Version_ID], [ID]) ON DELETE CASCADE
GO
