CREATE TABLE [mdm].[tblTransactionAnnotation]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Transaction_ID] [int] NOT NULL,
[Comment] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EnterUserID] [int] NOT NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblTransactionAnnotation_EnterDTM] DEFAULT (getutcdate()),
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblTransactionAnnotation_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblTransactionAnnotation] ADD CONSTRAINT [pk_tblTransactionAnnotation] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblTransactionAnnotation] ADD CONSTRAINT [fk_tblTransactionAnnotation_tblTransaction_Transaction_ID] FOREIGN KEY ([Transaction_ID]) REFERENCES [mdm].[tblTransaction] ([ID]) ON DELETE CASCADE
GO
