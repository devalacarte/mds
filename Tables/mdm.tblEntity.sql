CREATE TABLE [mdm].[tblEntity]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblEntity_MUID] DEFAULT (newid()),
[Model_ID] [int] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EntityTable] [sys].[sysname] NOT NULL,
[SecurityTable] [sys].[sysname] NOT NULL,
[HierarchyTable] [sys].[sysname] NULL,
[HierarchyParentTable] [sys].[sysname] NULL,
[CollectionTable] [sys].[sysname] NULL,
[CollectionMemberTable] [sys].[sysname] NULL,
[IsBase] [bit] NOT NULL CONSTRAINT [df_tblEntity_IsBase] DEFAULT ((0)),
[IsFlat] [bit] NOT NULL CONSTRAINT [df_tblEntity_IsFlat] DEFAULT ((1)),
[IsSystem] [bit] NOT NULL CONSTRAINT [df_tblEntity_IsSystem] DEFAULT ((0)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblEntity_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblEntity_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL,
[StagingBase] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblEntity] ADD CONSTRAINT [ck_tblEntity_IsFlat] CHECK (([IsFlat]=(1) AND coalesce([HierarchyTable],[HierarchyParentTable],[CollectionTable],[CollectionMemberTable]) IS NULL OR [IsFlat]=(0) AND [HierarchyTable] IS NOT NULL AND [HierarchyParentTable] IS NOT NULL AND [CollectionTable] IS NOT NULL AND [CollectionMemberTable] IS NOT NULL))
GO
ALTER TABLE [mdm].[tblEntity] ADD CONSTRAINT [pk_tblEntity] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblEntity] ADD CONSTRAINT [ux_tblEntity_Model_ID_Name] UNIQUE NONCLUSTERED  ([Model_ID], [Name]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblEntity] ADD CONSTRAINT [ux_tblEntity_MUID] UNIQUE NONCLUSTERED  ([MUID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblEntity] ADD CONSTRAINT [fk_tblEntity_tblModel_Model_ID] FOREIGN KEY ([Model_ID]) REFERENCES [mdm].[tblModel] ([ID])
GO
