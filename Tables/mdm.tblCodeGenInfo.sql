CREATE TABLE [mdm].[tblCodeGenInfo]
(
[EntityId] [int] NOT NULL,
[Seed] [int] NOT NULL,
[LargestCodeValue] [bigint] NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblCodeGenInfo] ADD CONSTRAINT [PK_tblCodeGenInfo] PRIMARY KEY CLUSTERED  ([EntityId]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblCodeGenInfo] ADD CONSTRAINT [FK_tblCodeGenInfo_tblEntity] FOREIGN KEY ([EntityId]) REFERENCES [mdm].[tblEntity] ([ID])
GO
