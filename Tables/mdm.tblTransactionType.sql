CREATE TABLE [mdm].[tblTransactionType]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Code] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblTransactionType] ADD CONSTRAINT [pk_tblTransactionType] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
