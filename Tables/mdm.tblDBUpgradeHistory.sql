CREATE TABLE [mdm].[tblDBUpgradeHistory]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[DBVersion] [int] NOT NULL,
[EnterUser] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [df_tblDBUpgradeHistory_EnterUser] DEFAULT (suser_sname()),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblDBUpgradeHistory_EnterDTM] DEFAULT (getutcdate())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblDBUpgradeHistory] ADD CONSTRAINT [pk_tblDBUpgradeHistory] PRIMARY KEY CLUSTERED  ([ID] DESC) ON [PRIMARY]
GO
