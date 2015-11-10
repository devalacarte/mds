CREATE TABLE [mdm].[tblSecurityRoleAccessMember]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Role_ID] [int] NOT NULL,
[Privilege_ID] [int] NOT NULL,
[Object_ID] [int] NOT NULL,
[Version_ID] [int] NOT NULL,
[Entity_ID] [int] NOT NULL,
[HierarchyType_ID] [tinyint] NOT NULL,
[ExplicitHierarchy_ID] [int] NULL,
[DerivedHierarchy_ID] [int] NULL,
[Hierarchy_ID] AS (case [HierarchyType_ID] when (0) then [ExplicitHierarchy_ID] when (1) then [DerivedHierarchy_ID] end),
[Item_ID] [int] NOT NULL CONSTRAINT [df_tblSecurityRoleAccessMember_Item_ID] DEFAULT ((-1)),
[ItemType_ID] [tinyint] NOT NULL CONSTRAINT [df_tblSecurityRoleAccessMember_ItemType_ID] DEFAULT ((-1)),
[MemberType_ID] [tinyint] NOT NULL,
[Member_ID] [int] NOT NULL,
[Description] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsInitialized] [bit] NOT NULL CONSTRAINT [df_tblSecurityRoleAccessMember_Status_ID] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblSecurityRoleAccessMember_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblSecurityRoleAccessMember_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblSecurityRoleAccessMember_MUID] DEFAULT (newid())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSecurityRoleAccessMember] ADD CONSTRAINT [ck_tblSecurityRoleAccessMember_HierarchyType_ID] CHECK (([HierarchyType_ID]=(1) OR [HierarchyType_ID]=(0)))
GO
ALTER TABLE [mdm].[tblSecurityRoleAccessMember] ADD CONSTRAINT [ck_tblSecurityRoleAccessMember_MemberType_ID] CHECK (([MemberType_ID]=(2) OR [MemberType_ID]=(1)))
GO
ALTER TABLE [mdm].[tblSecurityRoleAccessMember] ADD CONSTRAINT [pk_tblSecurityRoleAccessMember] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblSecurityRoleAccessMember_Entity_ID_Version_ID_Role_ID_ExplicitHierarchy_ID_DerivedHierarchy_ID_MemberType_ID_Member_ID] ON [mdm].[tblSecurityRoleAccessMember] ([Entity_ID], [Version_ID], [Role_ID], [ExplicitHierarchy_ID], [DerivedHierarchy_ID], [MemberType_ID], [Member_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblSecurityRoleAccessMember_Role_ID] ON [mdm].[tblSecurityRoleAccessMember] ([Role_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSecurityRoleAccessMember] ADD CONSTRAINT [fk_tblSecurityRoleAccessMember_tblHierarchy_DerivedHierarchy_ID] FOREIGN KEY ([DerivedHierarchy_ID]) REFERENCES [mdm].[tblDerivedHierarchy] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblSecurityRoleAccessMember] ADD CONSTRAINT [fk_tblSecurityRoleAccessMember_tblEntity_Entity_ID] FOREIGN KEY ([Entity_ID]) REFERENCES [mdm].[tblEntity] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblSecurityRoleAccessMember] ADD CONSTRAINT [fk_tblSecurityRoleAccessMember_tblHierarchy_ExplicitHierarchy_ID] FOREIGN KEY ([ExplicitHierarchy_ID]) REFERENCES [mdm].[tblHierarchy] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblSecurityRoleAccessMember] ADD CONSTRAINT [fk_tblSecurityRoleAccessMember_tblSecurityPrivilege_Privilege_ID] FOREIGN KEY ([Privilege_ID]) REFERENCES [mdm].[tblSecurityPrivilege] ([ID])
GO
ALTER TABLE [mdm].[tblSecurityRoleAccessMember] ADD CONSTRAINT [fk_tblSecurityRoleAccessMember_tblSecurityRole_Role_ID] FOREIGN KEY ([Role_ID]) REFERENCES [mdm].[tblSecurityRole] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblSecurityRoleAccessMember] ADD CONSTRAINT [fk_tblSecurityRoleAccessMember_tblModelVersion_Version_ID] FOREIGN KEY ([Version_ID]) REFERENCES [mdm].[tblModelVersion] ([ID])
GO
