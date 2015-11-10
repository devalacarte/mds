CREATE TABLE [mdm].[tblNotificationUsers]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Notification_ID] [int] NOT NULL,
[User_ID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblNotificationUsers] ADD CONSTRAINT [pk_tblNotificationUsers] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblNotificationUsers] ADD CONSTRAINT [fk_tblNotificationUsers_tblUser_UserID] FOREIGN KEY ([User_ID]) REFERENCES [mdm].[tblUser] ([ID])
GO
