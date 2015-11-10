CREATE TABLE [mdm].[tblUserGroup]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblUserGroup_MUID] DEFAULT (newid()),
[UserGroupType_ID] [int] NOT NULL,
[Status_ID] [tinyint] NOT NULL,
[SID] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Name] [nvarchar] (355) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblUserGroup_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblUserGroup_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblUserGroup] ADD CONSTRAINT [ck_tblUserGroup_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblUserGroup] ADD CONSTRAINT [pk_tblUserGroup] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblUserGroup_MUID] ON [mdm].[tblUserGroup] ([MUID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblUserGroup_Name] ON [mdm].[tblUserGroup] ([Name]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblUserGroup_SID] ON [mdm].[tblUserGroup] ([SID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblUserGroup_UserGroupType_ID] ON [mdm].[tblUserGroup] ([UserGroupType_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblUserGroup] ADD CONSTRAINT [fk_tblUserGroup_tblUserGroupType_UserGroupType_ID] FOREIGN KEY ([UserGroupType_ID]) REFERENCES [mdm].[tblUserGroupType] ([ID])
GO
GRANT SELECT ON  [mdm].[tblUserGroup] TO [mds_exec]
GO
