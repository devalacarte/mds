CREATE TYPE [mdm].[HierarchyMembers] AS TABLE
(
[Hierarchy_ID] [int] NULL,
[HierarchyName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Parent_ID] [int] NULL,
[ParentCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Child_ID] [int] NULL,
[ChildCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ChildMemberType_ID] [int] NULL,
[Target_ID] [int] NULL,
[TargetCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TargetMemberType_ID] [int] NULL,
[TargetType_ID] [int] NULL
)
GO
