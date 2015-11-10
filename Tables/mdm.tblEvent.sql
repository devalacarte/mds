CREATE TABLE [mdm].[tblEvent]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblEvent_MUID] DEFAULT (newid()),
[Version_ID] [int] NULL,
[EventName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EventStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_tblEvent_EventStatus_ID] DEFAULT ((1)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblEvent_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblEvent_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblEvent] ADD CONSTRAINT [ck_tblEvent_EventStatus_ID] CHECK (([EventStatus_ID]>=(1) AND [EventStatus_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblEvent] ADD CONSTRAINT [pk_tblEvent] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblEvent_MUID] ON [mdm].[tblEvent] ([MUID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblEvent] ADD CONSTRAINT [fk_tblEvent_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID]) ON DELETE CASCADE
GO
