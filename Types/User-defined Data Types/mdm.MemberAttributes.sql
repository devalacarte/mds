CREATE TYPE [mdm].[MemberAttributes] AS TABLE
(
[MemberCode] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AttributeName] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AttributeValue] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ErrorCode] [int] NULL,
[ErrorObjectType] [int] NULL,
[TransactionAnnotation] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
