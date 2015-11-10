CREATE TABLE [mdm].[tblSecurityAccessControl]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[PrincipalType_ID] [int] NOT NULL CONSTRAINT [df_tblSecurityAccessControl_PrincipalType_ID] DEFAULT ((0)),
[Principal_ID] [int] NOT NULL,
[Role_ID] [int] NOT NULL,
[Description] [nvarchar] (110) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tblSecurityAccessControl_Status_ID] DEFAULT ((1)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblSecurityAccessControl_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL CONSTRAINT [df_tblSecurityAccessControl_EnterUserID] DEFAULT ((-1)),
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblSecurityAccessControl_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL CONSTRAINT [df_tblSecurityAccessControl_LastChgUserID] DEFAULT ((-1)),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblSecurityAccessControl_MUID] DEFAULT (newid())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSecurityAccessControl] ADD CONSTRAINT [ck_tblSecurityAccessControl_PrincipalType_ID] CHECK (([PrincipalType_ID]>=(0) AND [PrincipalType_ID]<=(2)))
GO
ALTER TABLE [mdm].[tblSecurityAccessControl] ADD CONSTRAINT [ck_tblSecurityAccessControl_Status_ID] CHECK (([Status_ID]>=(1) AND [Status_ID]<=(3)))
GO
ALTER TABLE [mdm].[tblSecurityAccessControl] ADD CONSTRAINT [pk_tblSecurityAccessControl] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblSecurityAccessControl_Principal_ID] ON [mdm].[tblSecurityAccessControl] ([Principal_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblSecurityAccessControl_Role_ID] ON [mdm].[tblSecurityAccessControl] ([Role_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSecurityAccessControl] ADD CONSTRAINT [fk_tblSecurityAccessControl_tblSecurityRole_Role_ID] FOREIGN KEY ([Role_ID]) REFERENCES [mdm].[tblSecurityRole] ([ID])
GO
