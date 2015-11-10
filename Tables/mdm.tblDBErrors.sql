CREATE TABLE [mdm].[tblDBErrors]
(
[ID] [int] NOT NULL,
[Language_ID] [int] NOT NULL CONSTRAINT [DF__tblDBErro__Langu__395884C4] DEFAULT ((1033)),
[Text] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Category] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Comment] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblDBErrors] ADD CONSTRAINT [pk_tblDBErrors] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
