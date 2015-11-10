CREATE TABLE [mdm].[tblAttributeValidation]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[RegexPattern] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[RegexMask] [tinyint] NOT NULL CONSTRAINT [df_tblAttributeValidation_RegexMask] DEFAULT ((0)),
[InputMask] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Sample] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ErrorMessage] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblAttributeValidation] ADD CONSTRAINT [ck_tblAttributeValidation_InputMask] CHECK (([InputMask] IS NULL OR nullif(ltrim(rtrim([InputMask])),N'') IS NOT NULL))
GO
ALTER TABLE [mdm].[tblAttributeValidation] ADD CONSTRAINT [ck_tblAttributeValidation_RegexMask] CHECK (([RegexMask]>=(0) AND [RegexMask]<=(127)))
GO
ALTER TABLE [mdm].[tblAttributeValidation] ADD CONSTRAINT [ck_tblAttributeValidation_Name] CHECK ((nullif(ltrim(rtrim([Name])),N'') IS NOT NULL))
GO
ALTER TABLE [mdm].[tblAttributeValidation] ADD CONSTRAINT [ck_tblAttributeValidation_RegexPattern] CHECK ((nullif(ltrim(rtrim([RegexPattern])),N'') IS NOT NULL))
GO
ALTER TABLE [mdm].[tblAttributeValidation] ADD CONSTRAINT [pk_tblAttributeValidation] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_tblAttributeValidation_Name] ON [mdm].[tblAttributeValidation] ([Name]) ON [PRIMARY]
GO
