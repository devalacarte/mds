CREATE TABLE [mdm].[tblDerivedHierarchy]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblDerivedHierarchy_MUID] DEFAULT (newid()),
[Model_ID] [int] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AnchorNullRecursions] [bit] NOT NULL CONSTRAINT [DF__tblDerive__Ancho__3C34F16F] DEFAULT ((1)),
[Priority] [int] NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblDerivedHierarchy_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblDerivedHierarchy_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblDerivedHierarchy] ADD CONSTRAINT [pk_tblDerivedHierarchy] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblDerivedHierarchy] ADD CONSTRAINT [ux_tblDerivedHierarchy_Model_ID_Name] UNIQUE NONCLUSTERED  ([Model_ID], [Name]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblDerivedHierarchy] ADD CONSTRAINT [ux_tblDerivedHierarchy_MUID] UNIQUE NONCLUSTERED  ([MUID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblDerivedHierarchy] ADD CONSTRAINT [fk_tblDerivedHierarchy_tblModel_Model_ID] FOREIGN KEY ([Model_ID]) REFERENCES [mdm].[tblModel] ([ID]) ON DELETE CASCADE
GO
