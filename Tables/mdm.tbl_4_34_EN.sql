CREATE TABLE [mdm].[tbl_4_34_EN]
(
[Version_ID] [int] NOT NULL,
[ID] [int] NOT NULL IDENTITY(1, 1),
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_4_34_EN_Status_ID] DEFAULT ((1)),
[ValidationStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_4_34_EN_ValidationStatus_ID] DEFAULT ((0)),
[Name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Code] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ChangeTrackingMask] [int] NOT NULL CONSTRAINT [df_tbl_4_34_EN_ChangeTrackingMask] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_4_34_EN_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_4_34_EN_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL,
[AsOf_ID] [int] NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tbl_4_34_EN_MUID] DEFAULT (newid()),
[uda_34_934] [int] NULL,
[uda_34_935] [int] NULL,
[uda_34_936] [int] NULL,
[uda_34_937] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_4_34_EN] ADD CONSTRAINT [ck_tbl_4_34_EN_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(2)))
GO
ALTER TABLE [mdm].[tbl_4_34_EN] ADD CONSTRAINT [ck_tbl_4_34_EN_ValidationStatus_ID] CHECK (([ValidationStatus_ID]>=(0) AND [ValidationStatus_ID]<=(5)))
GO
ALTER TABLE [mdm].[tbl_4_34_EN] ADD CONSTRAINT [pk_tbl_4_34_EN] PRIMARY KEY CLUSTERED  ([Version_ID], [ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tbl_4_34_EN_MUID] ON [mdm].[tbl_4_34_EN] ([MUID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_EN_Version_ID_AsOf_ID] ON [mdm].[tbl_4_34_EN] ([Version_ID], [AsOf_ID]) WHERE ([AsOf_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tbl_4_34_EN_Version_ID_Code] ON [mdm].[tbl_4_34_EN] ([Version_ID], [Code]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_EN_Version_ID_LastChgDTM] ON [mdm].[tbl_4_34_EN] ([Version_ID], [LastChgDTM]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_EN_Version_ID_Name] ON [mdm].[tbl_4_34_EN] ([Version_ID], [Name]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_EN_Version_ID_uda_34_934] ON [mdm].[tbl_4_34_EN] ([Version_ID], [uda_34_934]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_EN_Version_ID_uda_34_935] ON [mdm].[tbl_4_34_EN] ([Version_ID], [uda_34_935]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_EN_Version_ID_uda_34_936] ON [mdm].[tbl_4_34_EN] ([Version_ID], [uda_34_936]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_4_34_EN_Version_ID_uda_34_937] ON [mdm].[tbl_4_34_EN] ([Version_ID], [uda_34_937]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_4_34_EN] ADD CONSTRAINT [fk_tbl_4_34_EN_tblModelVersion_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID])
GO
ALTER TABLE [mdm].[tbl_4_34_EN] ADD CONSTRAINT [fk_tbl_4_34_EN_tbl_4_39_EN_Version_ID_uda_34_934] FOREIGN KEY ([Version_ID], [uda_34_934]) REFERENCES [mdm].[tbl_4_39_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_4_34_EN] ADD CONSTRAINT [fk_tbl_4_34_EN_tbl_4_33_EN_Version_ID_uda_34_935] FOREIGN KEY ([Version_ID], [uda_34_935]) REFERENCES [mdm].[tbl_4_33_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_4_34_EN] ADD CONSTRAINT [fk_tbl_4_34_EN_tbl_4_36_EN_Version_ID_uda_34_936] FOREIGN KEY ([Version_ID], [uda_34_936]) REFERENCES [mdm].[tbl_4_36_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_4_34_EN] ADD CONSTRAINT [fk_tbl_4_34_EN_tbl_4_40_EN_Version_ID_uda_34_937] FOREIGN KEY ([Version_ID], [uda_34_937]) REFERENCES [mdm].[tbl_4_40_EN] ([Version_ID], [ID])
GO
