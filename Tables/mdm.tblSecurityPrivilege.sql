CREATE TABLE [mdm].[tblSecurityPrivilege]
(
[ID] [int] NOT NULL,
[Code] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsActive] [bit] NOT NULL CONSTRAINT [df_tblSecurityPrivilege_IsActive] DEFAULT ((1))
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSecurityPrivilege] ADD CONSTRAINT [pk_tblSecurityPrivilege] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
