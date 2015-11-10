CREATE TABLE [mdm].[tblList]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[ListCode] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ListName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Seq] [int] NOT NULL,
[ListOption] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OptionID] [int] NOT NULL,
[IsVisible] [bit] NOT NULL,
[Group_ID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblList] ADD CONSTRAINT [pk_tblList] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ix_tblList_ListCode_ListOption] ON [mdm].[tblList] ([ListCode], [ListOption]) INCLUDE ([OptionID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ix_tblList_ListCode_OptionID_Group_ID] ON [mdm].[tblList] ([ListCode], [OptionID], [Group_ID]) ON [PRIMARY]
GO
