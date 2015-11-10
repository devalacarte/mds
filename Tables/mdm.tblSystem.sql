CREATE TABLE [mdm].[tblSystem]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[ProductName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ProductVersion] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ProductRegistrationKey] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SchemaVersion] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblSystem_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [df_tblSystem_EnterUserID] DEFAULT (suser_sname()),
[LastChgUserID] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [df_tblSystem_LastChgUserID] DEFAULT (suser_sname()),
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblSystem_LastChgDTM] DEFAULT (getutcdate())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSystem] ADD CONSTRAINT [ck_tblSystem_ID] CHECK (([ID]=(1)))
GO
ALTER TABLE [mdm].[tblSystem] ADD CONSTRAINT [pk_tblSystem] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
