CREATE TABLE [mdm].[tblUserPreference]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[User_ID] [int] NOT NULL,
[PreferenceName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PreferenceValue] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblUserPreference_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblUserPreference_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblUserPreference] ADD CONSTRAINT [pk_tblUserPreference] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ix_tblUserPreference_User_ID_PreferenceName] ON [mdm].[tblUserPreference] ([User_ID], [PreferenceName]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblUserPreference] ADD CONSTRAINT [fk_tblUserPreference_tblUserPreference_User_ID] FOREIGN KEY ([User_ID]) REFERENCES [mdm].[tblUser] ([ID]) ON DELETE CASCADE
GO
GRANT SELECT ON  [mdm].[tblUserPreference] TO [mds_exec]
GO
