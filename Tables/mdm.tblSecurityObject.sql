CREATE TABLE [mdm].[tblSecurityObject]
(
[ID] [int] NOT NULL IDENTITY(0, 1),
[Code] [char] (6) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ViewName] [sys].[sysname] NULL,
[IsActive] [bit] NOT NULL CONSTRAINT [df_tblSecurityObject_IsActive] DEFAULT ((1))
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblSecurityObject] ADD CONSTRAINT [ck_tblSecurityObject_Code] CHECK ((len(ltrim(rtrim([Code])))=(6)))
GO
ALTER TABLE [mdm].[tblSecurityObject] ADD CONSTRAINT [pk_tblSecurityObject] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
