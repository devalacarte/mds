CREATE TABLE [mdm].[tblHierarchy]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblHierarchy_MUID] DEFAULT (newid()),
[Entity_ID] [int] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsMandatory] [bit] NOT NULL CONSTRAINT [df_tblHierarchy_IsMandatory] DEFAULT ((1)),
[EnterDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblHierarchy_EnterDTM] DEFAULT (getutcdate()),
[EnterUserID] [int] NOT NULL,
[EnterVersionID] [int] NOT NULL,
[LastChgDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblHierarchy_LastChgDTM] DEFAULT (getutcdate()),
[LastChgUserID] [int] NOT NULL,
[LastChgVersionID] [int] NOT NULL,
[LastChgTS] [timestamp] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblHierarchy] ADD CONSTRAINT [pk_tblHierarchy] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblHierarchy] ADD CONSTRAINT [ux_tblHierarchy_Name] UNIQUE NONCLUSTERED  ([Entity_ID], [Name]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblHierarchy] ADD CONSTRAINT [ux_tblHierarchy_MUID] UNIQUE NONCLUSTERED  ([MUID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblHierarchy] ADD CONSTRAINT [fk_tblHierarchy_tblEntity_Entity_ID] FOREIGN KEY ([Entity_ID]) REFERENCES [mdm].[tblEntity] ([ID])
GO
