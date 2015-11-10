CREATE TABLE [mdm].[tblStgMemberAttribute]
(
[ID] [bigint] NOT NULL IDENTITY(1, 1),
[Batch_ID] [int] NULL,
[UserName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ModelName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EntityName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MemberType_ID] [tinyint] NOT NULL,
[MemberCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AttributeName] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AttributeValue] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tblStgMemberAttribute_Status_ID] DEFAULT ((0)),
[ErrorCode] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [df_tblStgMemberAttribute_ErrorCode] DEFAULT (N'')
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblStgMemberAttribute] ADD CONSTRAINT [ck_tblStgMemberAttributes_MemberType_ID] CHECK (([MemberType_ID]>=(1) AND [MemberType_ID]<=(5)))
GO
ALTER TABLE [mdm].[tblStgMemberAttribute] ADD CONSTRAINT [ck_tblStgMemberAttribute_Status_ID] CHECK (([Status_ID]>=(0) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblStgMemberAttribute] ADD CONSTRAINT [pk_tblStgMemberAttribute] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblStgMemberAttribute] ADD CONSTRAINT [fk_tblStgMemberAttribute_tblEntity_MemberType_ID] FOREIGN KEY ([MemberType_ID]) REFERENCES [mdm].[tblEntityMemberType] ([ID])
GO
GRANT SELECT ON  [mdm].[tblStgMemberAttribute] TO [mds_exec]
GRANT INSERT ON  [mdm].[tblStgMemberAttribute] TO [mds_exec]
GRANT DELETE ON  [mdm].[tblStgMemberAttribute] TO [mds_exec]
GRANT UPDATE ON  [mdm].[tblStgMemberAttribute] TO [mds_exec]
GO
