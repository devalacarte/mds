CREATE TABLE [mdm].[tblStgRelationship]
(
[ID] [bigint] NOT NULL IDENTITY(1, 1),
[Batch_ID] [int] NULL,
[VersionName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[UserName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ModelName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EntityName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[HierarchyName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MemberType_ID] [tinyint] NOT NULL,
[MemberCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TargetCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TargetType_ID] [int] NOT NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [df_tblStgRelationShip_SortOrder] DEFAULT ((0)),
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tblStgRelationShip_Status_ID] DEFAULT ((0)),
[ErrorCode] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [df_tblStgRelationShip_ErrorCode] DEFAULT ('')
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblStgRelationship] ADD CONSTRAINT [ck_tblStgMemberRelationship_MemberType_ID] CHECK (([MemberType_ID]>=(1) AND [MemberType_ID]<=(5)))
GO
ALTER TABLE [mdm].[tblStgRelationship] ADD CONSTRAINT [ck_tblStgMemberRelationship_Status_ID] CHECK (([Status_ID]>=(0) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblStgRelationship] ADD CONSTRAINT [pk_tblStgRelationship] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblStgRelationship] ADD CONSTRAINT [fk_tblStgRelationship_tblEntityMemberType] FOREIGN KEY ([MemberType_ID]) REFERENCES [mdm].[tblEntityMemberType] ([ID])
GO
GRANT SELECT ON  [mdm].[tblStgRelationship] TO [mds_exec]
GRANT INSERT ON  [mdm].[tblStgRelationship] TO [mds_exec]
GRANT DELETE ON  [mdm].[tblStgRelationship] TO [mds_exec]
GRANT UPDATE ON  [mdm].[tblStgRelationship] TO [mds_exec]
GO
