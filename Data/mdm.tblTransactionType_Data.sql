SET IDENTITY_INSERT [mdm].[tblTransactionType] ON
INSERT INTO [mdm].[tblTransactionType] ([ID], [Code], [Description]) VALUES (1, N'MEMBER_CREATE', N'Create Member')
INSERT INTO [mdm].[tblTransactionType] ([ID], [Code], [Description]) VALUES (2, N'MEMBER_STATUS_SET', N'Change Member Status')
INSERT INTO [mdm].[tblTransactionType] ([ID], [Code], [Description]) VALUES (3, N'MEMBER_ATTRIBUTE_SET', N'Set Attribute Value')
INSERT INTO [mdm].[tblTransactionType] ([ID], [Code], [Description]) VALUES (4, N'HIERARCHY_PARENT_SET', N'Move Member to Parent')
INSERT INTO [mdm].[tblTransactionType] ([ID], [Code], [Description]) VALUES (5, N'HIERARCHY_SIBLING_SET', N'Move Member to Sibling')
INSERT INTO [mdm].[tblTransactionType] ([ID], [Code], [Description]) VALUES (6, N'MEMBER_ANNOTATE', N'Create Member Annotation')
SET IDENTITY_INSERT [mdm].[tblTransactionType] OFF
