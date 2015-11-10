CREATE TABLE [mdm].[tblBRLogicalOperatorGroup]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[LogicalOperator_ID] [int] NULL,
[Parent_ID] [int] NULL,
[BusinessRule_ID] [int] NOT NULL,
[Sequence] [int] NOT NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblBRLogicalOperatorGroup_MUID] DEFAULT (newid())
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRLogicalOperatorGroup] ADD CONSTRAINT [pk_tblBRLogicalOperatorGroup] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblBRLogicalOperatorGroup_MUID] ON [mdm].[tblBRLogicalOperatorGroup] ([MUID]) INCLUDE ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRLogicalOperatorGroup] ADD CONSTRAINT [fk_tblBRLogicalOperatorGroup_tblBRBusinessRule_BusinessRule_ID] FOREIGN KEY ([BusinessRule_ID]) REFERENCES [mdm].[tblBRBusinessRule] ([ID])
GO
