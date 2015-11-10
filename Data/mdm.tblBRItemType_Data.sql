SET IDENTITY_INSERT [mdm].[tblBRItemType] ON
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (1, N'Equals', N'is equal to', 1, NULL, 'c6616dba-415a-4b64-a2aa-7e51c41c9cb8')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (2, N'Does not equal', N'is not equal to', 2, NULL, '387ee515-d20d-4def-a467-e8666ecd1f45')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (3, N'Contains', N'contains', 9, NULL, 'a8258615-b421-4170-9a4e-32477854d4a4')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (4, N'Starts with', N'starts with', 7, NULL, '4da019a9-f47c-43d6-8823-3909e77431a3')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (5, N'Ends with', N'ends with', 8, NULL, 'bb7cf09f-60f5-4c3d-98bc-39393b569a99')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (6, N'Contains subset', N'contains subset', 10, NULL, '68ceeec6-676d-4a45-8333-4462a6ba805e')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (7, N'Greater than', N'is greater than', 3, NULL, '4ad6c9b9-31dd-4d55-9531-82eb636029ab')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (8, N'Greater than or equal to', N'is greater than or equal to', 4, NULL, '54d164c5-b159-41c3-979e-dd8746dd093e')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (9, N'Less than', N'is less than', 5, NULL, '694db4a4-8d87-4ac5-9e58-6cd7a0113c33')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (10, N'Less than or equal to', N'is less than or equal to', 6, NULL, 'b783441c-f49d-4137-ba05-537b6036874a')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (11, N'Between', N'is between', 11, NULL, '69a40952-9474-4ef1-b3fc-8210ada895cc')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (12, N'Value', N'defaults to', 2, NULL, 'd759b772-dee8-4cc0-ad47-7fb462f8c26b')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (13, N'Generate value', N'defaults to generated value', 1, NULL, '470faa22-bde6-470a-b671-da0006547196')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (14, N'Value', N'equals', 5, NULL, '3687659a-2c63-4ca0-92e9-b7e40be25d49')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (15, N'Concatenated value', N'equals a concatenated value', 6, N' + ', 'f8a5b13d-c1d7-4f01-8ae1-2837752e79b1')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (16, N'Greater than', N'must be greater than', 12, NULL, '52a13bea-da2d-4fd1-ac4d-6aae3cd7ddee')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (17, N'Greater than or equal to', N'must be greater than or equal to', 13, NULL, 'fcb6ca05-a340-43ff-83b6-26ebc44ff017')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (18, N'Less than', N'must be less than', 14, NULL, '662fd170-b97a-408a-b37d-b4a921aa9af3')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (19, N'Less than or equal to', N'must be less than or equal to', 15, NULL, '9beb5983-9cb0-4962-af18-bbdd7226efef')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (20, N'Between', N'must be between', 10, NULL, '19e90050-77fa-4992-8e54-e2fb9b0e4405')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (21, N'Minimum length', N'must have a minimum length of', 16, NULL, '232f669e-2ab4-4cd6-853d-055620ac2ac9')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (22, N'Maximum length', N'must have a maximum length of', 17, NULL, 'ca2ce2ea-bb7c-4fd7-82e2-0e3dcdb0baaa')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (23, N'Allowable values', N'must have one of the following values', 9, N',', '062780be-4c4e-4642-a5fc-2bb481120de2')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (24, N'Unique', N'must be unique', 8, N',', '6880163d-3a8a-4304-bcab-7d3e29276f0a')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (25, N'Mandatory', N'is mandatory', 7, NULL, '75cd98a9-6a80-461d-b723-307cc78128a7')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (27, N'Invalid', N'is invalid', 19, NULL, '0d6d6ad4-fcba-4640-8739-babf4f4201e0')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (28, N'Concatenated value', N'defaults to a concatenated value', 3, N' + ', '5fb46e67-3bdd-46a5-8543-f1d39e343aa0')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (29, N'Equal', N'must be equal', 11, NULL, '32319cd8-0f85-46e4-a0a9-6be4fb4c8918')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (30, N'Contains pattern', N'contains pattern', 12, NULL, '9e4923f4-17b3-49e4-b2dc-c413f7f2fd08')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (31, N'Must contain pattern', N'must contain pattern', 22, NULL, 'b15fbf1d-e6d4-451f-89f4-53b75c6b9c27')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (32, N'Start Workflow', N'start Workflow', 1, N' ', 'd5ff633b-07e8-46fa-8298-7a10fd55cddb')
INSERT INTO [mdm].[tblBRItemType] ([ID], [Name], [Description], [Priority], [PropertyDelimiter], [MUID]) VALUES (33, N'Has changed', N'has changed', 21, NULL, 'a18b1a17-268f-443a-b052-bf794357f531')
SET IDENTITY_INSERT [mdm].[tblBRItemType] OFF
