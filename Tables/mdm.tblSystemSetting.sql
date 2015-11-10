CREATE TABLE [mdm].[tblSystemSetting]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[IsVisible] [bit] NOT NULL,
[SettingName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SettingValue] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DisplayName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SettingType_ID] [tinyint] NOT NULL CONSTRAINT [df_tblSystemSetting_SettingType_ID] DEFAULT ((1)),
[DataType_ID] [tinyint] NOT NULL CONSTRAINT [df_tblSystemSetting_DataType_ID] DEFAULT ((1)),
[MinValue] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MaxValue] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ListCode] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EnterDTM] [datetime] NOT NULL CONSTRAINT [df_tblSystemSetting_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime] NOT NULL CONSTRAINT [df_tblSystemSetting_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblSystemSetting_MUID] DEFAULT (newid()),
[SystemSettingGroup_ID] [int] NOT NULL CONSTRAINT [df_tblSystemSetting_GroupID] DEFAULT ((1)),
[DisplaySequence] [int] NOT NULL CONSTRAINT [df_tblSystemSetting_DisplaySequence] DEFAULT ((1))
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSystemSetting] ADD CONSTRAINT [pk_tblSystemSetting] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblSystemSetting_MUID] ON [mdm].[tblSystemSetting] ([MUID]) INCLUDE ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ix_tblSystemSetting_SettingName] ON [mdm].[tblSystemSetting] ([SettingName]) INCLUDE ([SettingValue]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSystemSetting] ADD CONSTRAINT [fk_tblSystemSetting_tblSystemSettingGroup] FOREIGN KEY ([SystemSettingGroup_ID]) REFERENCES [mdm].[tblSystemSettingGroup] ([ID])
GO
