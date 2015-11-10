CREATE TABLE [mdm].[tblModelVersion]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblModelVersion_MUID] DEFAULT (newid()),
[Model_ID] [int] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tblModelVersion_Status_ID] DEFAULT ((1)),
[Display_ID] [int] NOT NULL,
[VersionFlag_ID] [int] NULL,
[AsOfVersion_ID] [int] NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblModelVersion_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblModelVersion_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblModelVersion] ADD CONSTRAINT [ck_tblModelVersion_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblModelVersion] ADD CONSTRAINT [pk_tblModelVersion] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblModelVersion] ADD CONSTRAINT [ux_tblModelVersion_Model_ID_Name] UNIQUE NONCLUSTERED  ([Model_ID], [Name]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblModelVersion] ADD CONSTRAINT [ux_tblModelVersion_MUID] UNIQUE NONCLUSTERED  ([MUID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblModelVersion] ADD CONSTRAINT [fk_tblModelVersion_tblModel_Model_ID] FOREIGN KEY ([Model_ID]) REFERENCES [mdm].[tblModel] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblModelVersion] ADD CONSTRAINT [fk_tblModelVersion_tblModelVersionFlag_VersionFlag_ID] FOREIGN KEY ([VersionFlag_ID]) REFERENCES [mdm].[tblModelVersionFlag] ([ID])
GO
