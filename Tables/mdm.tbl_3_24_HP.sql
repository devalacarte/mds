CREATE TABLE [mdm].[tbl_3_24_HP]
(
[Version_ID] [int] NOT NULL,
[ID] [int] NOT NULL IDENTITY(1, 1),
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_3_24_HP_Status_ID] DEFAULT ((1)),
[ValidationStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_3_24_HP_ValidationStatus_ID] DEFAULT ((0)),
[Name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Code] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Hierarchy_ID] [int] NOT NULL,
[ChangeTrackingMask] [int] NOT NULL CONSTRAINT [df_tbl_3_24_HP_ChangeTrackingMask] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_3_24_HP_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_3_24_HP_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL,
[AsOf_ID] [int] NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tbl_3_24_HP_MUID] DEFAULT (newid())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_3_24_HP] ADD CONSTRAINT [ck_tbl_3_24_HP_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(2)))
GO
ALTER TABLE [mdm].[tbl_3_24_HP] ADD CONSTRAINT [ck_tbl_3_24_HP_ValidationStatus_ID] CHECK (([ValidationStatus_ID]>=(0) AND [ValidationStatus_ID]<=(5)))
GO
ALTER TABLE [mdm].[tbl_3_24_HP] ADD CONSTRAINT [pk_tbl_3_24_HP] PRIMARY KEY CLUSTERED  ([Version_ID], [ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tbl_3_24_HP_MUID] ON [mdm].[tbl_3_24_HP] ([MUID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_HP_Version_ID_AsOf_ID] ON [mdm].[tbl_3_24_HP] ([Version_ID], [AsOf_ID]) WHERE ([AsOf_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tbl_3_24_HP_Version_ID_Code] ON [mdm].[tbl_3_24_HP] ([Version_ID], [Code]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_HP_Version_ID_Name] ON [mdm].[tbl_3_24_HP] ([Version_ID], [Name]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_3_24_HP] ADD CONSTRAINT [fk_tbl_3_24_HP_tblHierarchy_Hierarchy_ID] FOREIGN KEY ([Hierarchy_ID]) REFERENCES [mdm].[tblHierarchy] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tbl_3_24_HP] ADD CONSTRAINT [fk_tbl_3_24_HP_tblModelVersion_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID])
GO
