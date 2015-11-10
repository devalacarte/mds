CREATE TABLE [mdm].[tblModel]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblModel_MUID] DEFAULT (newid()),
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsSystem] [bit] NOT NULL CONSTRAINT [df_tblModel_IsSystem] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblModel_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblModel_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblModel] ADD CONSTRAINT [pk_tblModel] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblModel] ADD CONSTRAINT [ux_tblModel_MUID] UNIQUE NONCLUSTERED  ([MUID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblModel] ADD CONSTRAINT [ux_tblModel_Name] UNIQUE NONCLUSTERED  ([Name]) ON [PRIMARY]
GO
