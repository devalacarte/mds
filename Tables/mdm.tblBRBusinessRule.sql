CREATE TABLE [mdm].[tblBRBusinessRule]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RuleConditionText] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RuleActionText] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RuleConditionSQL] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ForeignType_ID] [int] NOT NULL,
[Foreign_ID] [int] NOT NULL,
[Status_ID] [int] NOT NULL,
[Priority] [int] NULL,
[NotificationGroupID] [int] NULL,
[NotificationUserID] [int] NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblBRBusinessRule_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblBRBusinessRule_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblBRBusinessRule_MUID] DEFAULT (newid())
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRBusinessRule] ADD CONSTRAINT [pk_tblBRBusinessRule] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblBRBusinessRule_MUID] ON [mdm].[tblBRBusinessRule] ([MUID]) INCLUDE ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRBusinessRule] ADD CONSTRAINT [fk_tblBRBusinessRule_tblListRelationship_ForeignType_ID] FOREIGN KEY ([ForeignType_ID]) REFERENCES [mdm].[tblListRelationship] ([ID])
GO
