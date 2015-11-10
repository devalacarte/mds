CREATE TABLE [mdm].[tblUser]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblUser_MUID] DEFAULT (newid()),
[Status_ID] [tinyint] NOT NULL,
[SID] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[UserName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DisplayName] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EmailAddress] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LastLoginDTM] [datetime2] (3) NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblUser_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblUser_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblUser] ADD CONSTRAINT [ck_tblUser_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblUser] ADD CONSTRAINT [pk_tblUser] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblUser_MUID] ON [mdm].[tblUser] ([MUID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblUser_SID] ON [mdm].[tblUser] ([SID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblUser_UserName] ON [mdm].[tblUser] ([UserName]) ON [PRIMARY]
GO
GRANT SELECT ON  [mdm].[tblUser] TO [mds_exec]
GO
