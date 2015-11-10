CREATE TABLE [mdm].[tblNotificationType]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Description] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TextStyleSheet] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[HTMLStyleSheet] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblNotificationType] ADD CONSTRAINT [pk_tblNotificationType] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
