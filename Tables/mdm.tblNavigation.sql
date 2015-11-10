CREATE TABLE [mdm].[tblNavigation]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tblNavigation_Status_ID] DEFAULT ((1)),
[Constant] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblModelNavigation_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblModelNavigation_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblNavigation] ADD CONSTRAINT [ck_tblNavigation_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblNavigation] ADD CONSTRAINT [pk_tblNavigation] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
