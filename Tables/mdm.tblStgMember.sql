CREATE TABLE [mdm].[tblStgMember]
(
[ID] [bigint] NOT NULL IDENTITY(1, 1),
[Batch_ID] [int] NULL,
[UserName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ModelName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[HierarchyName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EntityName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MemberType_ID] [tinyint] NOT NULL,
[MemberName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MemberCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tblStgMember_Status_ID] DEFAULT ((0)),
[ErrorCode] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [df_tblStgMember_ErrorCode] DEFAULT (N'')
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblStgMember] ADD CONSTRAINT [ck_tblStgMember_MemberType_ID] CHECK (([MemberType_ID]>=(1) AND [MemberType_ID]<=(5)))
GO
ALTER TABLE [mdm].[tblStgMember] ADD CONSTRAINT [ck_tblStgMember_Status_ID] CHECK (([Status_ID]>=(0) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblStgMember] ADD CONSTRAINT [pk_tblStgMember] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblStgMember] ADD CONSTRAINT [fk_tblStgMember_tblEntityMemberType] FOREIGN KEY ([MemberType_ID]) REFERENCES [mdm].[tblEntityMemberType] ([ID])
GO
GRANT SELECT ON  [mdm].[tblStgMember] TO [mds_exec]
GRANT INSERT ON  [mdm].[tblStgMember] TO [mds_exec]
GRANT DELETE ON  [mdm].[tblStgMember] TO [mds_exec]
GRANT UPDATE ON  [mdm].[tblStgMember] TO [mds_exec]
GO
