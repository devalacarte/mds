CREATE TABLE [mdm].[tblLocalizedStrings]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[LanguageCode] [int] NOT NULL,
[ResourceName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LocalizedValue] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblLocalizedStrings] ADD CONSTRAINT [PK_tblLocalizedStrings] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
