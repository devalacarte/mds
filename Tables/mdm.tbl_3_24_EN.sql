CREATE TABLE [mdm].[tbl_3_24_EN]
(
[Version_ID] [int] NOT NULL,
[ID] [int] NOT NULL IDENTITY(1, 1),
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_3_24_EN_Status_ID] DEFAULT ((1)),
[ValidationStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_tbl_3_24_EN_ValidationStatus_ID] DEFAULT ((0)),
[Name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Code] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ChangeTrackingMask] [int] NOT NULL CONSTRAINT [df_tbl_3_24_EN_ChangeTrackingMask] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_3_24_EN_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tbl_3_24_EN_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL,
[AsOf_ID] [int] NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tbl_3_24_EN_MUID] DEFAULT (newid()),
[uda_24_690] [int] NULL,
[uda_24_691] [int] NULL,
[uda_24_692] [int] NULL,
[uda_24_693] [int] NULL,
[uda_24_694] [int] NULL,
[uda_24_695] [decimal] (38, 2) NULL,
[uda_24_696] [decimal] (38, 0) NULL,
[uda_24_697] [decimal] (38, 0) NULL,
[uda_24_698] [decimal] (38, 4) NULL,
[uda_24_699] [decimal] (38, 4) NULL,
[uda_24_700] [decimal] (38, 0) NULL,
[uda_24_701] [decimal] (38, 2) NULL,
[uda_24_702] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[uda_24_703] [datetime2] (3) NULL,
[uda_24_704] [datetime2] (3) NULL,
[uda_24_705] [int] NULL,
[uda_24_706] [int] NULL,
[uda_24_707] [int] NULL,
[uda_24_708] [int] NULL,
[uda_24_709] [int] NULL,
[uda_24_710] [datetime2] (3) NULL,
[uda_24_711] [int] NULL,
[uda_24_712] [int] NULL,
[uda_24_713] [int] NULL,
[uda_24_714] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [ck_tbl_3_24_EN_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(2)))
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [ck_tbl_3_24_EN_ValidationStatus_ID] CHECK (([ValidationStatus_ID]>=(0) AND [ValidationStatus_ID]<=(5)))
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [pk_tbl_3_24_EN] PRIMARY KEY CLUSTERED  ([Version_ID], [ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tbl_3_24_EN_MUID] ON [mdm].[tbl_3_24_EN] ([MUID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_AsOf_ID] ON [mdm].[tbl_3_24_EN] ([Version_ID], [AsOf_ID]) WHERE ([AsOf_ID] IS NOT NULL) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tbl_3_24_EN_Version_ID_Code] ON [mdm].[tbl_3_24_EN] ([Version_ID], [Code]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_LastChgDTM] ON [mdm].[tbl_3_24_EN] ([Version_ID], [LastChgDTM]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_Name] ON [mdm].[tbl_3_24_EN] ([Version_ID], [Name]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_690] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_690]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_691] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_691]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_692] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_692]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_693] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_693]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_694] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_694]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_705] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_705]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_706] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_706]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_707] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_707]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_708] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_708]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_709] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_709]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_711] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_711]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_712] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_712]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_713] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_713]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tbl_3_24_EN_Version_ID_uda_24_714] ON [mdm].[tbl_3_24_EN] ([Version_ID], [uda_24_714]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tblModelVersion_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_28_EN_Version_ID_uda_24_690] FOREIGN KEY ([Version_ID], [uda_24_690]) REFERENCES [mdm].[tbl_3_28_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_21_EN_Version_ID_uda_24_691] FOREIGN KEY ([Version_ID], [uda_24_691]) REFERENCES [mdm].[tbl_3_21_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_20_EN_Version_ID_uda_24_692] FOREIGN KEY ([Version_ID], [uda_24_692]) REFERENCES [mdm].[tbl_3_20_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_30_EN_Version_ID_uda_24_693] FOREIGN KEY ([Version_ID], [uda_24_693]) REFERENCES [mdm].[tbl_3_30_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_22_EN_Version_ID_uda_24_694] FOREIGN KEY ([Version_ID], [uda_24_694]) REFERENCES [mdm].[tbl_3_22_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_31_EN_Version_ID_uda_24_705] FOREIGN KEY ([Version_ID], [uda_24_705]) REFERENCES [mdm].[tbl_3_31_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_31_EN_Version_ID_uda_24_706] FOREIGN KEY ([Version_ID], [uda_24_706]) REFERENCES [mdm].[tbl_3_31_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_32_EN_Version_ID_uda_24_707] FOREIGN KEY ([Version_ID], [uda_24_707]) REFERENCES [mdm].[tbl_3_32_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_32_EN_Version_ID_uda_24_708] FOREIGN KEY ([Version_ID], [uda_24_708]) REFERENCES [mdm].[tbl_3_32_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_32_EN_Version_ID_uda_24_709] FOREIGN KEY ([Version_ID], [uda_24_709]) REFERENCES [mdm].[tbl_3_32_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_27_EN_Version_ID_uda_24_711] FOREIGN KEY ([Version_ID], [uda_24_711]) REFERENCES [mdm].[tbl_3_27_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_23_EN_Version_ID_uda_24_712] FOREIGN KEY ([Version_ID], [uda_24_712]) REFERENCES [mdm].[tbl_3_23_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_23_EN_Version_ID_uda_24_713] FOREIGN KEY ([Version_ID], [uda_24_713]) REFERENCES [mdm].[tbl_3_23_EN] ([Version_ID], [ID])
GO
ALTER TABLE [mdm].[tbl_3_24_EN] ADD CONSTRAINT [fk_tbl_3_24_EN_tbl_3_29_EN_Version_ID_uda_24_714] FOREIGN KEY ([Version_ID], [uda_24_714]) REFERENCES [mdm].[tbl_3_29_EN] ([Version_ID], [ID])
GO
