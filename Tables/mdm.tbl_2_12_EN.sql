CREATE TABLE [mdm].[tbl_2_12_EN]
(
[Version_ID] [int] NOT NULL,
[ID] [int] NOT NULL IDENTITY(1, 1),
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_2_12_EN_Status_ID] DEFAULT ((1)),
[ValidationStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_2_12_EN_ValidationStatus_ID] DEFAULT ((0)),
[Name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Code] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ChangeTrackingMask] [int] NOT NULL CONSTRAINT [df_tbl_2_12_EN_ChangeTrackingMask] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_2_12_EN_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_2_12_EN_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL,
[AsOf_ID] [int] NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tbl_2_12_EN_MUID] DEFAULT (newid()),
[uda_12_389] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[uda_12_390] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[uda_12_391] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[uda_12_392] [int] NULL,
[uda_12_393] [int] NULL,
[uda_12_394] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[uda_12_395] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[uda_12_396] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[uda_12_397] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[uda_12_398] [int] NULL,
[uda_12_399] [int] NULL,
[uda_12_400] [int] NULL,
[uda_12_401] [int] NULL,
[uda_12_402] [int] NULL,
[uda_12_403] [int] NULL,
[uda_12_404] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [ck_tbl_2_12_EN_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(2)))
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [ck_tbl_2_12_EN_ValidationStatus_ID] CHECK (([ValidationStatus_ID]>=(0) AND [ValidationStatus_ID]<=(5)))
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [pk_tbl_2_12_EN] PRIMARY KEY CLUSTERED  ([Version_ID], [ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tbl_2_12_EN_MUID] ON [mdm].[tbl_2_12_EN] ([MUID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_AsOf_ID] ON [mdm].[tbl_2_12_EN] ([Version_ID], [AsOf_ID]) WHERE ([AsOf_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tbl_2_12_EN_Version_ID_Code] ON [mdm].[tbl_2_12_EN] ([Version_ID], [Code]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_LastChgDTM] ON [mdm].[tbl_2_12_EN] ([Version_ID], [LastChgDTM]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_Name] ON [mdm].[tbl_2_12_EN] ([Version_ID], [Name]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_uda_12_392] ON [mdm].[tbl_2_12_EN] ([Version_ID], [uda_12_392]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_uda_12_393] ON [mdm].[tbl_2_12_EN] ([Version_ID], [uda_12_393]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_uda_12_398] ON [mdm].[tbl_2_12_EN] ([Version_ID], [uda_12_398]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_uda_12_399] ON [mdm].[tbl_2_12_EN] ([Version_ID], [uda_12_399]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_uda_12_400] ON [mdm].[tbl_2_12_EN] ([Version_ID], [uda_12_400]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_uda_12_401] ON [mdm].[tbl_2_12_EN] ([Version_ID], [uda_12_401]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_uda_12_402] ON [mdm].[tbl_2_12_EN] ([Version_ID], [uda_12_402]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_2_12_EN_Version_ID_uda_12_403] ON [mdm].[tbl_2_12_EN] ([Version_ID], [uda_12_403]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [fk_tbl_2_12_EN_tblModelVersion_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID])
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [fk_tbl_2_12_EN_tbl_2_18_EN_Version_ID_uda_12_392] FOREIGN KEY ([Version_ID], [uda_12_392]) REFERENCES [mdm].[tbl_2_18_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [fk_tbl_2_12_EN_tbl_2_9_EN_Version_ID_uda_12_393] FOREIGN KEY ([Version_ID], [uda_12_393]) REFERENCES [mdm].[tbl_2_9_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [fk_tbl_2_12_EN_tbl_2_13_EN_Version_ID_uda_12_398] FOREIGN KEY ([Version_ID], [uda_12_398]) REFERENCES [mdm].[tbl_2_13_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [fk_tbl_2_12_EN_tbl_2_17_EN_Version_ID_uda_12_399] FOREIGN KEY ([Version_ID], [uda_12_399]) REFERENCES [mdm].[tbl_2_17_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [fk_tbl_2_12_EN_tbl_2_11_EN_Version_ID_uda_12_400] FOREIGN KEY ([Version_ID], [uda_12_400]) REFERENCES [mdm].[tbl_2_11_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [fk_tbl_2_12_EN_tbl_2_10_EN_Version_ID_uda_12_401] FOREIGN KEY ([Version_ID], [uda_12_401]) REFERENCES [mdm].[tbl_2_10_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [fk_tbl_2_12_EN_tbl_2_15_EN_Version_ID_uda_12_402] FOREIGN KEY ([Version_ID], [uda_12_402]) REFERENCES [mdm].[tbl_2_15_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_2_12_EN] ADD CONSTRAINT [fk_tbl_2_12_EN_tbl_2_6_EN_Version_ID_uda_12_403] FOREIGN KEY ([Version_ID], [uda_12_403]) REFERENCES [mdm].[tbl_2_6_EN] ([Version_ID], [ID])
GO
