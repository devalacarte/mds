CREATE TABLE [mdm].[tblUserGroupAssignment]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblUserGroupAssignment_MUID] DEFAULT (newid()),
[UserGroup_ID] [int] NOT NULL,
[User_ID] [int] NOT NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblUserGroupAssignment_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblUserGroupAssignment_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblUserGroupAssignment] ADD CONSTRAINT [pk_tblUserGroupAssignment] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblUserGroupAssignment_MUID] ON [mdm].[tblUserGroupAssignment] ([MUID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblUserGroupAssignment_User_ID_UserGroup_ID] ON [mdm].[tblUserGroupAssignment] ([User_ID], [UserGroup_ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblUserGroupAssignment_UserGroup_ID_User_ID] ON [mdm].[tblUserGroupAssignment] ([UserGroup_ID], [User_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblUserGroupAssignment] ADD CONSTRAINT [fk_tblUserGroupAssignment_tblUser_UserID] FOREIGN KEY ([User_ID]) REFERENCES [mdm].[tblUser] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblUserGroupAssignment] ADD CONSTRAINT [fk_tblUserGroupAssignment_tblUserGroup_UserGroupID] FOREIGN KEY ([UserGroup_ID]) REFERENCES [mdm].[tblUserGroup] ([ID]) ON DELETE CASCADE
GO
