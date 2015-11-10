CREATE TABLE [mdm].[tblListRelationship]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[ParentListCode] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Parent_ID] [int] NOT NULL,
[ChildListCode] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Child_ID] [int] NOT NULL,
[ListRelationshipType_ID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblListRelationship] ADD CONSTRAINT [pk_tblListRelationship] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblListRelationship] ADD CONSTRAINT [fk_tblListRelationship_tblListRelationshipType_ListRelationshipType_ID] FOREIGN KEY ([ListRelationshipType_ID]) REFERENCES [mdm].[tblListRelationshipType] ([ID])
GO
