CREATE TABLE [mdm].[tblAttributeGroup]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblAttributeGroup_MUID] DEFAULT (newid()),
[Entity_ID] [int] NOT NULL,
[MemberType_ID] [tinyint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SortOrder] [int] NOT NULL,
[FreezeNameCode] [bit] NOT NULL CONSTRAINT [df_tblAttributeGroup_FreezeNameCode] DEFAULT ((0)),
[IsSystem] [bit] NOT NULL CONSTRAINT [df_tblAttributeGroup_IsSystem] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblAttributeGroup_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblAttributeGroup_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttributeGroup] ADD CONSTRAINT [ck_tblAttributeGroup_MemberType_ID] CHECK (([MemberType_ID]>=(1) AND [MemberType_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblAttributeGroup] ADD CONSTRAINT [pk_tblAttributeGroup] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttributeGroup] ADD CONSTRAINT [ux_tblAttributeGroup_Entity_ID_MemberType_ID_Name] UNIQUE NONCLUSTERED  ([Entity_ID], [MemberType_ID], [Name]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttributeGroup] ADD CONSTRAINT [ux_tblAttributeGroup_MUID] UNIQUE NONCLUSTERED  ([MUID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblAttributeGroup_MemberType_ID] ON [mdm].[tblAttributeGroup] ([MemberType_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttributeGroup] ADD CONSTRAINT [fk_tblAttributeGroup_tblEntity_Entity_ID] FOREIGN KEY ([Entity_ID]) REFERENCES [mdm].[tblEntity] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblAttributeGroup] ADD CONSTRAINT [fk_tblAttributeGroup_tblEntityMemberType_MemberType_ID] FOREIGN KEY ([MemberType_ID]) REFERENCES [mdm].[tblEntityMemberType] ([ID])
GO
