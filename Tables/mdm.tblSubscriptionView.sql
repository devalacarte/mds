CREATE TABLE [mdm].[tblSubscriptionView]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Entity_ID] [int] NULL,
[Model_ID] [int] NOT NULL,
[DerivedHierarchy_ID] [int] NULL,
[ViewFormat_ID] [int] NOT NULL,
[ModelVersion_ID] [int] NULL,
[ModelVersionFlag_ID] [int] NULL,
[Name] [sys].[sysname] NOT NULL,
[Levels] [int] NULL,
[IsDirty] [tinyint] NOT NULL CONSTRAINT [df_tblSubscriptionView_IsDirty] DEFAULT ((0)),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblSubscriptionView_MUID] DEFAULT (newid())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSubscriptionView] ADD CONSTRAINT [pk_tblSubscriptionView] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSubscriptionView] ADD CONSTRAINT [fk_tblSubscriptionView_tblDerivedHierarchy] FOREIGN KEY ([DerivedHierarchy_ID]) REFERENCES [mdm].[tblDerivedHierarchy] ([ID])
GO
ALTER TABLE [mdm].[tblSubscriptionView] ADD CONSTRAINT [fk_tblSubscriptionView_tblEntity] FOREIGN KEY ([Entity_ID]) REFERENCES [mdm].[tblEntity] ([ID])
GO
ALTER TABLE [mdm].[tblSubscriptionView] ADD CONSTRAINT [fk_tblSubscriptionView_tblModel] FOREIGN KEY ([Model_ID]) REFERENCES [mdm].[tblModel] ([ID])
GO
ALTER TABLE [mdm].[tblSubscriptionView] ADD CONSTRAINT [fk_tblSubscriptionView_tblModelVersion] FOREIGN KEY ([ModelVersion_ID]) REFERENCES [mdm].[tblModelVersion] ([ID])
GO
