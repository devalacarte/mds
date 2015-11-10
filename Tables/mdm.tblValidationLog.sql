CREATE TABLE [mdm].[tblValidationLog]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Status_ID] [tinyint] NOT NULL,
[Version_ID] [int] NOT NULL,
[Hierarchy_ID] [int] NOT NULL,
[Entity_ID] [int] NOT NULL,
[Member_ID] [int] NOT NULL,
[MemberCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MemberType_ID] [tinyint] NOT NULL,
[Description] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[BRBusinessRule_ID] [int] NOT NULL,
[BRItem_ID] [int] NOT NULL,
[NotificationStatus_ID] [int] NOT NULL CONSTRAINT [df_tblValidationLog_NotificationStatus_ID] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblValidatonLog_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblValidatonLog_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblValidationLog] ADD CONSTRAINT [ck_tblValidationLog_MemberType_ID] CHECK (([MemberType_ID]>=(1) AND [MemberType_ID]<=(5)))
GO
ALTER TABLE [mdm].[tblValidationLog] ADD CONSTRAINT [ck_tblValidationLog_NotificationStatus_ID] CHECK (([NotificationStatus_ID]>=(0) AND [NotificationStatus_ID]<=(5)))
GO
ALTER TABLE [mdm].[tblValidationLog] ADD CONSTRAINT [ck_tblValidationLog_Status_ID] CHECK (([Status_ID]>=(0) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblValidationLog] ADD CONSTRAINT [pk_tblValidationLog] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [idx_tblValidationLog] ON [mdm].[tblValidationLog] ([Version_ID], [Entity_ID], [Member_ID], [MemberType_ID], [BRBusinessRule_ID], [BRItem_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblValidationLog_ALL] ON [mdm].[tblValidationLog] ([Version_ID], [Entity_ID], [Member_ID], [MemberType_ID], [BRBusinessRule_ID], [BRItem_ID]) ON [PRIMARY]
GO
