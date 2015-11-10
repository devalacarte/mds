SET IDENTITY_INSERT [mdm].[tblUserGroupType] ON
INSERT INTO [mdm].[tblUserGroupType] ([ID], [Name], [SortOrder]) VALUES (1, N'Internal Group', 1)
INSERT INTO [mdm].[tblUserGroupType] ([ID], [Name], [SortOrder]) VALUES (2, N'Active Directory Group', 2)
INSERT INTO [mdm].[tblUserGroupType] ([ID], [Name], [SortOrder]) VALUES (3, N'Local Group', 3)
INSERT INTO [mdm].[tblUserGroupType] ([ID], [Name], [SortOrder]) VALUES (4, N'Other Group', 99)
SET IDENTITY_INSERT [mdm].[tblUserGroupType] OFF
