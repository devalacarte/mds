CREATE TABLE [mdm].[tblNotificationQueue]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[NotificationType_ID] [int] NOT NULL,
[NotificationSourceID] [int] NULL,
[Version_ID] [int] NULL,
[Model_ID] [int] NULL,
[Entity_ID] [int] NULL,
[Hierarchy_ID] [int] NULL,
[Member_ID] [int] NULL,
[MemberType_ID] [tinyint] NULL,
[Description] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Message] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[BRBusinessRule_ID] [int] NULL,
[PriorityRank] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblNotificationQueue_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[DueDTM] [datetime2] (3) NULL,
[SentDTM] [datetime2] (3) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblNotificationQueue] ADD CONSTRAINT [pk_tblNotificationQueue] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblNotificationQueue] ADD CONSTRAINT [fk_tblNotificationQueue_tblNotificationQueue_MemberType_ID] FOREIGN KEY ([MemberType_ID]) REFERENCES [mdm].[tblEntityMemberType] ([ID])
GO
ALTER TABLE [mdm].[tblNotificationQueue] ADD CONSTRAINT [fk_tblNotificationQueue_tblModel_Model_ID] FOREIGN KEY ([Model_ID]) REFERENCES [mdm].[tblModel] ([ID])
GO
ALTER TABLE [mdm].[tblNotificationQueue] ADD CONSTRAINT [fk_tblNotificationQueue_tblNotificationType_NotificationType_ID] FOREIGN KEY ([NotificationType_ID]) REFERENCES [mdm].[tblNotificationType] ([ID])
GO
ALTER TABLE [mdm].[tblNotificationQueue] ADD CONSTRAINT [fk_tblNotificationQueue_tblModelVersion_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID])
GO
