CREATE TABLE [mdm].[tblUserGroupType]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SortOrder] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblUserGroupType] ADD CONSTRAINT [pk_tblUserGroupType] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblUserGroupType_Name] ON [mdm].[tblUserGroupType] ([Name]) ON [PRIMARY]
GO
