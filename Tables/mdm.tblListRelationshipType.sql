CREATE TABLE [mdm].[tblListRelationshipType]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblListRelationshipType] ADD CONSTRAINT [pk_tblListRelationshipType] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
