CREATE TABLE [mdm].[tblEntityMemberType]
(
[ID] [tinyint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TableCode] [nchar] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ViewSuffix] [sys].[sysname] NOT NULL,
[IsVisible] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblEntityMemberType] ADD CONSTRAINT [ck_tblEntityMemberType_ID] CHECK (([ID]>=(1) AND [ID]<=(5)))
GO
ALTER TABLE [mdm].[tblEntityMemberType] ADD CONSTRAINT [ck_tblEntityMemberType_TableCode] CHECK ((len(ltrim(rtrim([TableCode])))=(2)))
GO
ALTER TABLE [mdm].[tblEntityMemberType] ADD CONSTRAINT [pk_tblEntityMemberType] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblEntityMemberType] ADD CONSTRAINT [ux_tblEntityMemberType_Name] UNIQUE NONCLUSTERED  ([Name]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblEntityMemberType] ADD CONSTRAINT [ux_tblEntityMemberType_TableCode] UNIQUE NONCLUSTERED  ([TableCode]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblEntityMemberType] ADD CONSTRAINT [ux_tblEntityMemberType_ViewSuffix] UNIQUE NONCLUSTERED  ([ViewSuffix]) ON [PRIMARY]
GO
