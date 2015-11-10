CREATE TABLE [mdm].[tblSecurityRoleAccess]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Role_ID] [int] NOT NULL,
[Privilege_ID] [int] NOT NULL,
[Model_ID] [int] NOT NULL,
[Securable_ID] [int] NOT NULL,
[Object_ID] [int] NOT NULL,
[Description] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tblSecurityRoleAccess_Status_ID] DEFAULT ((1)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblSecurityRoleAccess_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL CONSTRAINT [df_tblSecurityRoleAccess_EnterUserID] DEFAULT ((-1)),
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblSecurityRoleAccess_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL CONSTRAINT [df_tblSecurityRoleAccess_LastChgUserID] DEFAULT ((-1)),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblSecurityRoleAccess_MUID] DEFAULT (newid())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSecurityRoleAccess] ADD CONSTRAINT [ck_tblSecurityRoleAccess_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblSecurityRoleAccess] ADD CONSTRAINT [pk_tblSecurityRoleAccess] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblSecurityRoleAccess_Model_ID_Securable_ID_Object_ID_Role_ID] ON [mdm].[tblSecurityRoleAccess] ([Model_ID], [Securable_ID], [Object_ID], [Role_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSecurityRoleAccess] ADD CONSTRAINT [fk_tblSecurityRoleAccess_tblModel_Model_ID] FOREIGN KEY ([Model_ID]) REFERENCES [mdm].[tblModel] ([ID]) ON DELETE CASCADE
GO
ALTER TABLE [mdm].[tblSecurityRoleAccess] ADD CONSTRAINT [fk_tblSecurityRoleAccess_tblSecurityPrivilege_Privilege_ID] FOREIGN KEY ([Privilege_ID]) REFERENCES [mdm].[tblSecurityPrivilege] ([ID])
GO
ALTER TABLE [mdm].[tblSecurityRoleAccess] ADD CONSTRAINT [fk_tblSecurityRoleAccess_tblSecurityRole_Role_ID] FOREIGN KEY ([Role_ID]) REFERENCES [mdm].[tblSecurityRole] ([ID]) ON DELETE CASCADE
GO
