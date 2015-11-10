CREATE TABLE [mdm].[tblValidationLogHistory]
(
[ID] [int] NOT NULL,
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
[NotificationStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_tblValidationLogHistory_NotificationStatus_ID] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblValidatonLogHistory_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblValidatonLogHistory_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblValidationLogHistory] ADD CONSTRAINT [ck_tblValidationLogHistory_MemberType_ID] CHECK (([MemberType_ID]>=(1) AND [MemberType_ID]<=(5)))
GO
ALTER TABLE [mdm].[tblValidationLogHistory] ADD CONSTRAINT [ck_tblValidationLogHistory_NotificationStatus_ID] CHECK (([NotificationStatus_ID]>=(0) AND [NotificationStatus_ID]<=(5)))
GO
ALTER TABLE [mdm].[tblValidationLogHistory] ADD CONSTRAINT [ck_tblValidationLogHistory_Status_ID] CHECK (([Status_ID]>=(0) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblValidationLogHistory] ADD CONSTRAINT [pk_tblValidationLogHistory] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
