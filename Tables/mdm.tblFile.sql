CREATE TABLE [mdm].[tblFile]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblFile_MUID] DEFAULT (newid()),
[FileDisplayName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FileName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FileLocation] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FileContentType] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FileContentLength] [decimal] (18, 0) NOT NULL,
[FileContent] [varbinary] (max) NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblFile_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblFile_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblFile] ADD CONSTRAINT [pk_tblFile] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblFile] ADD CONSTRAINT [ux_tblFile_MUID] UNIQUE NONCLUSTERED  ([MUID]) ON [PRIMARY]
GO
