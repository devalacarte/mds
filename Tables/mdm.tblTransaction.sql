CREATE TABLE [mdm].[tblTransaction]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Version_ID] [int] NOT NULL,
[TransactionType_ID] [int] NOT NULL,
[OriginalTransaction_ID] [int] NULL,
[Hierarchy_ID] [int] NULL,
[Entity_ID] [int] NULL,
[Attribute_ID] [int] NULL,
[Member_ID] [int] NOT NULL,
[MemberType_ID] [tinyint] NOT NULL,
[MemberCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OldValue] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OldCode] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewValue] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewCode] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsMapped] [tinyint] NOT NULL CONSTRAINT [df_tblTransaction_IsMapped] DEFAULT ((0)),
[Batch_ID] [int] NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblTransaction_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblTransaction_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblTransaction] ADD CONSTRAINT [ck_tblTransaction_MemberType_ID] CHECK (([MemberType_ID]>=(1) AND [MemberType_ID]<=(5)))
GO
ALTER TABLE [mdm].[tblTransaction] ADD CONSTRAINT [pk_tblTransaction] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblTransaction_Version_ID_Attribute_ID_Member_ID_TransactionType_ID_Entity_ID_MemberType_ID_EnterDTM_EnterUserID] ON [mdm].[tblTransaction] ([Version_ID], [Attribute_ID], [Member_ID], [TransactionType_ID], [Entity_ID], [MemberType_ID], [EnterDTM], [EnterUserID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblTransaction_Version_ID_Entity_ID_MemberCode] ON [mdm].[tblTransaction] ([Version_ID], [Entity_ID], [MemberCode]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblTransaction] ADD CONSTRAINT [fk_tblTransaction_tblAttribute_Attribute_ID] FOREIGN KEY ([Attribute_ID]) REFERENCES [mdm].[tblAttribute] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblTransaction] ADD CONSTRAINT [fk_tblTransaction_tblEntity_Entity_ID] FOREIGN KEY ([Entity_ID]) REFERENCES [mdm].[tblEntity] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblTransaction] ADD CONSTRAINT [fk_tblTransaction_tblHierarchy_Hierarchy_ID] FOREIGN KEY ([Hierarchy_ID]) REFERENCES [mdm].[tblHierarchy] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblTransaction] ADD CONSTRAINT [fk_tblTransaction_tblTransaction_MemberType_ID] FOREIGN KEY ([MemberType_ID]) REFERENCES [mdm].[tblEntityMemberType] ([ID])
GO
ALTER TABLE [mdm].[tblTransaction] ADD CONSTRAINT [fk_tblTransaction_tblTransactionType] FOREIGN KEY ([TransactionType_ID]) REFERENCES [mdm].[tblTransactionType] ([ID])
GO
ALTER TABLE [mdm].[tblTransaction] ADD CONSTRAINT [fk_tblTransaction_tblModelVersion_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID]) ON DELETE CASCADE
GO
