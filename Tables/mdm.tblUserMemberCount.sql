CREATE TABLE [mdm].[tblUserMemberCount]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Version_ID] [int] NOT NULL,
[Entity_ID] [int] NOT NULL,
[MemberType_ID] [tinyint] NOT NULL,
[User_ID] [int] NOT NULL,
[LastCount] [int] NOT NULL CONSTRAINT [df_tblUserMemberCount_LastCount] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblUserMemberCount_EnterDTM] DEFAULT (getutcdate()),
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblUserMemberCount_LastChgDTM] DEFAULT (getutcdate())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblUserMemberCount] ADD CONSTRAINT [pk_tblUserMemberCount] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblUserMemberCount] ADD CONSTRAINT [fk_tblUserMemberCount_tblEntity_Entity_ID] FOREIGN KEY ([Entity_ID]) REFERENCES [mdm].[tblEntity] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblUserMemberCount] ADD CONSTRAINT [fk_tblUserMemberCount_tblEntityMemberType_MemberType_ID] FOREIGN KEY ([MemberType_ID]) REFERENCES [mdm].[tblEntityMemberType] ([ID])
GO
ALTER TABLE [mdm].[tblUserMemberCount] ADD CONSTRAINT [fk_tblUserMemberCount_tblUser_User_ID] FOREIGN KEY ([User_ID]) REFERENCES [mdm].[tblUser] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblUserMemberCount] ADD CONSTRAINT [fk_tblUserMemberCount_tblModelVersion_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID]) ON DELETE CASCADE
GO
