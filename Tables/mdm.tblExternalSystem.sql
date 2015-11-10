CREATE TABLE [mdm].[tblExternalSystem]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblExternalSystem_MUID] DEFAULT (newid()),
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tblExternalSystem_Status_ID] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblExternalSystem_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblExternalSystem_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblExternalSystem] ADD CONSTRAINT [ck_tblExternalSystem_Status_ID] CHECK (([Status_ID]>=(0) AND [Status_ID]<=(6)))
GO
ALTER TABLE [mdm].[tblExternalSystem] ADD CONSTRAINT [pk_tblExternalSystem] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
