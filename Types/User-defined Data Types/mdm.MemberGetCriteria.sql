CREATE TYPE [mdm].[MemberGetCriteria] AS TABLE
(
[ID] [int] NULL,
[SchemaName] [sys].[sysname] NULL,
[ObjectName] [sys].[sysname] NOT NULL,
[Operator] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OperatorParameters] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[GroupId] [int] NOT NULL,
[Value] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
GRANT EXECUTE ON TYPE:: [mdm].[MemberGetCriteria] TO [mds_email_user]
GO
