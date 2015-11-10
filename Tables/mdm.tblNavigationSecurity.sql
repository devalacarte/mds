CREATE TABLE [mdm].[tblNavigationSecurity]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Navigation_ID] [int] NOT NULL,
[Foreign_ID] [int] NOT NULL,
[ForeignType_ID] [tinyint] NOT NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblModelNavigationSecurity_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblModelNavigationSecurity_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblNavigationSecurity_MUID] DEFAULT (newid()),
[Permission_ID] [bit] NOT NULL CONSTRAINT [df_tblNavigationSecurity_Permission_ID] DEFAULT ((0))
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblNavigationSecurity] ADD CONSTRAINT [pk_tblNavigationSecurity] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblNavigationSecurity] ADD CONSTRAINT [fk_tblNavigationSecurity_tblNavigation] FOREIGN KEY ([Navigation_ID]) REFERENCES [mdm].[tblNavigation] ([ID])
GO
