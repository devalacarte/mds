CREATE TYPE [mdm].[MemberCodes] AS TABLE
(
[MemberCode] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MemberName] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[HierarchyName] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TransactionAnnotation] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MUID] [uniqueidentifier] NULL
)
GO
