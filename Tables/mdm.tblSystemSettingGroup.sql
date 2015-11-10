CREATE TABLE [mdm].[tblSystemSettingGroup]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblSystemSettingGroup_MUID] DEFAULT (newid()),
[GroupName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DisplayName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DisplaySequence] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSystemSettingGroup] ADD CONSTRAINT [pk_tblSystemSettingGroup] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblSystemSettingGroup_MUID] ON [mdm].[tblSystemSettingGroup] ([MUID]) INCLUDE ([ID]) ON [PRIMARY]
GO
