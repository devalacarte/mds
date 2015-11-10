CREATE TABLE [mdm].[tblDerivedHierarchyDetail]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblDerivedHierarchyDetail_MUID] DEFAULT (newid()),
[DerivedHierarchy_ID] [int] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DisplayName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ForeignParent_ID] [int] NULL,
[Foreign_ID] [int] NULL,
[ForeignType_ID] [tinyint] NOT NULL,
[Level_ID] [int] NULL,
[SortOrder] [int] NULL,
[IsVisible] [bit] NOT NULL,
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblDerivedHierarchyDetail_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblDerivedHierarchyDetail_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblDerivedHierarchyDetail] ADD CONSTRAINT [ck_tblDerivedHierarchyDetail_ForeignType_ID] CHECK (([ForeignType_ID]>=(0) AND [ForeignType_ID]<=(4)))
GO
ALTER TABLE [mdm].[tblDerivedHierarchyDetail] ADD CONSTRAINT [pk_tblDerivedHierarchyDetail] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblDerivedHierarchyDetail] ADD CONSTRAINT [ck_tblDerivedHierarchyDetail_MUID] UNIQUE NONCLUSTERED  ([MUID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblDerivedHierarchyDetail_DerivedHierarchy_ID] ON [mdm].[tblDerivedHierarchyDetail] ([DerivedHierarchy_ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblDerivedHierarchyDetail] ADD CONSTRAINT [fk_tblDerivedHierarchyDetail_tblDerivedHierarchy_DerivedHierarchy_ID] FOREIGN KEY ([DerivedHierarchy_ID]) REFERENCES [mdm].[tblDerivedHierarchy] ([ID]) ON DELETE CASCADE
GO
