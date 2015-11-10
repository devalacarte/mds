CREATE TABLE [mdm].[tblAttribute]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblAttribute_MUID] DEFAULT (newid()),
[Entity_ID] [int] NOT NULL,
[MemberType_ID] [tinyint] NOT NULL,
[DisplayName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TableColumn] [sys].[sysname] NOT NULL,
[AttributeType_ID] [tinyint] NOT NULL,
[DataType_ID] [tinyint] NOT NULL,
[DataTypeInformation] [int] NULL,
[InputMask_ID] [int] NOT NULL,
[DisplayWidth] [int] NOT NULL,
[SortOrder] [int] NOT NULL,
[DomainEntity_ID] [int] NULL,
[ChangeTrackingGroup] [int] NOT NULL CONSTRAINT [df_tblAttribute_ChangeTrackingGroup] DEFAULT ((0)),
[IsCode] [bit] NOT NULL CONSTRAINT [df_tblAttribute_IsCode] DEFAULT ((0)),
[IsName] [bit] NOT NULL CONSTRAINT [df_tblAttribute_IsName] DEFAULT ((0)),
[IsSystem] [bit] NOT NULL CONSTRAINT [df_tblAttribute_IsSystem] DEFAULT ((0)),
[IsReadOnly] [bit] NOT NULL CONSTRAINT [df_tblAttribute_IsReadOnly] DEFAULT ((0)),
[AttributeValidation_ID] [int] NULL,
[IsRequired] [bit] NOT NULL CONSTRAINT [df_tblAttribute_IsRequired] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblAttribute_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblAttribute_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [ck_tblAttribute_AttributeType_ID] CHECK (([AttributeType_ID]>=(1) AND [AttributeType_ID]<=(4)))
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [ck_tblAttribute_DataType_ID] CHECK (([DataType_ID]>=(0) AND [DataType_ID]<=(7)))
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [pk_tblAttribute] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [ux_tblAttribute_Entity_ID_MemberType_ID_DisplayName] UNIQUE NONCLUSTERED  ([Entity_ID], [MemberType_ID], [DisplayName]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [ux_tblAttribute_Entity_ID_MemberType_ID_Name] UNIQUE NONCLUSTERED  ([Entity_ID], [MemberType_ID], [Name]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [ux_tblAttribute_Entity_ID_MemberType_ID_TableColumn] UNIQUE NONCLUSTERED  ([Entity_ID], [MemberType_ID], [TableColumn]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [ux_tblAttribute_MUID] UNIQUE NONCLUSTERED  ([MUID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblAttribute_DomainEntity_ID] ON [mdm].[tblAttribute] ([DomainEntity_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblAttribute_MemberType_ID] ON [mdm].[tblAttribute] ([MemberType_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [fk_tblAttribute_tblAttributeValidation_AttributeValidation_ID] FOREIGN KEY ([AttributeValidation_ID]) REFERENCES [mdm].[tblAttributeValidation] ([ID]) ON DELETE SET NULL
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [fk_tblAttribute_tblEntity_DomainEntity_ID] FOREIGN KEY ([DomainEntity_ID]) REFERENCES [mdm].[tblEntity] ([ID])
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [fk_tblAttribute_tblEntity_Entity_ID] FOREIGN KEY ([Entity_ID]) REFERENCES [mdm].[tblEntity] ([ID])
GO
ALTER TABLE [mdm].[tblAttribute] ADD CONSTRAINT [fk_tblAttribute_tblEntityMemberType_MemberType_ID] FOREIGN KEY ([MemberType_ID]) REFERENCES [mdm].[tblEntityMemberType] ([ID])
GO
