SET IDENTITY_INSERT [mdm].[tblNotificationType] ON
INSERT INTO [mdm].[tblNotificationType] ([ID], [Description], [TextStyleSheet], [HTMLStyleSheet]) VALUES (1, N'Validation Issue', N'ValidationIssueText', N'ValidationIssueHTML')
INSERT INTO [mdm].[tblNotificationType] ([ID], [Description], [TextStyleSheet], [HTMLStyleSheet]) VALUES (2, N'Version Status Change', N'VersionStatusChangeText', N'VersionStatusChangeHTML')
SET IDENTITY_INSERT [mdm].[tblNotificationType] OFF
