CREATE TABLE [mdm].[tblSecurityRole]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblSecurityRole_MUID] DEFAULT (newid()),
[Name] [nvarchar] (115) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tblSecurityRole_Status_ID] DEFAULT ((1)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblSecurityRole_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL CONSTRAINT [df_tblSecurityRole_EnterUserID] DEFAULT ((-1)),
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblSecurityRole_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL CONSTRAINT [df_tblSecurityRole_LastChgUserID] DEFAULT ((-1))
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSecurityRole] ADD CONSTRAINT [ck_tblSecurityRole_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblSecurityRole] ADD CONSTRAINT [pk_tblSecurityRole] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblSecurityRole_MUID] ON [mdm].[tblSecurityRole] ([MUID]) ON [PRIMARY]
GO
