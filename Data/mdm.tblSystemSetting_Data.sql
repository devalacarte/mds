SET IDENTITY_INSERT [mdm].[tblSystemSetting] ON
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (1, 1, N'ApplicationName', N'MDM', N'Application Log Name', N'The name of the application in the application log (used for system logging)', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.640', 0, '2015-11-09 18:33:58.640', 0, '35c50a40-f3ba-46e4-b85c-77e9367d3f6f', 1, 1)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (2, 1, N'SiteTitle', N'Master Data Manager', N'Site Title', N'The title of the application that shows up in the title bar of browser', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.640', 0, '2015-11-09 18:33:58.640', 0, '592ec9fc-253d-42d4-9511-6cc11169d19d', 1, 2)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (3, 0, N'SecurityMode', N'1', N'Security Mode', N'Turn MDM security ON or OFF (off is not recommended)', 2, 1, NULL, NULL, N'lstOnOff', '2015-11-09 18:33:58.640', 0, '2015-11-09 18:33:58.640', 0, '165e01af-7fe1-4ac4-973d-63d3e5f1fff9', 2, 6)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (4, 1, N'ShowAddInText', N'1', N'Show Add-In Text', N'Show Add-in for Excel text on home page', 2, 1, NULL, NULL, N'lstYesNo', '2015-11-09 18:33:58.640', 0, '2015-11-09 18:33:58.640', 0, 'e0a4afdb-c9ff-4498-b1a6-36dd957d8fbd', 1, 4)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (5, 1, N'AddInUrl', N'http://go.microsoft.com/fwlink/?LinkId=309620', N'Add-In URL', N'Add-in for Excel installation path on home page', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.643', 0, '2015-11-09 18:33:58.643', 0, '1241b234-eaa5-4ef2-b999-70cd5366067f', 1, 5)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (6, 0, N'ApplicationLogging', N'2', N'Application Logging', N'Log all MDM system calls to the Windows Event Log?', 2, 1, NULL, NULL, N'lstOnOff', '2015-11-09 18:33:58.643', 0, '2015-11-09 18:33:58.643', 0, '62734938-34d1-4a0a-8667-8ab6999e4694', 1, 3)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (7, 1, N'ClientTimeOut', N'300', N'Client Timeout', N'Number of seconds the Silverlight UI will wait for a repsonse from the service.', 1, 2, N'10', N'86400', NULL, '2015-11-09 18:33:58.643', 0, '2015-11-09 18:33:58.643', 0, 'b89dcb61-23ae-4e1a-81ae-abcdcf6c9029', 2, 2)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (8, 1, N'ServerTimeOut', N'120000', N'Server Timeout', N'Number of seconds the MDM server will process an action', 1, 2, N'900', N'240000', NULL, '2015-11-09 18:33:58.643', 0, '2015-11-09 18:33:58.643', 0, '09a2e5ff-8774-415c-9f95-f480f79174da', 2, 2)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (9, 1, N'DatabaseConnectionTimeOut', N'60', N'Database Connection Timeout', N'Number of seconds to try connecting to a MDM database', 1, 2, N'10', N'240000', NULL, '2015-11-09 18:33:58.647', 0, '2015-11-09 18:33:58.647', 0, '682b9f3e-c464-4628-a84e-d9c61597fb00', 2, 13)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (10, 1, N'DatabaseCommandTimeOut', N'3600', N'Database Command Timeout', N'Number of seconds the MDM database server will process an action', 1, 2, N'600', N'240000', NULL, '2015-11-09 18:33:58.647', 0, '2015-11-09 18:33:58.647', 0, '80e40680-b07e-4e3b-8588-39c547e87c14', 2, 13)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (11, 1, N'ReportServer', N'http://localhost/ReportServer', N'Reporting Server', N'URL of the MDM reporting server', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.650', 0, '2015-11-09 18:33:58.650', 0, 'b68098dd-e224-4424-b5ce-1764893b179f', 2, 3)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (12, 1, N'ReportDirectory', N'MDM', N'Report Directory', N'Location of the directory on the MDM reporting server', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.653', 0, '2015-11-09 18:33:58.653', 0, '5d6b7b67-2785-40b4-ab37-93e00db12ef6', 2, 4)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (13, 1, N'EmailFormat', N'1', N'Default E-mail Format', N'Default E-mail Format', 2, 1, NULL, NULL, N'lstEmail', '2015-11-09 18:33:58.653', 0, '2015-11-09 18:33:58.653', 0, '89d80b3b-2ab0-4af8-8a7b-b6ac05ca63ba', 4, 6)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (14, 1, N'NotificationInterval', N'120', N'Notification Interval', N'Frequency that e-mail notifications are issued (seconds)', 1, 2, N'120', N'240000', NULL, '2015-11-09 18:33:58.657', 0, '2015-11-09 18:33:58.657', 0, '653f49ee-35e0-40db-a8d8-f2c7fcae6698', 2, 8)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (15, 1, N'StagingTransactionLogging', N'2', N'Staging Transaction Logging', N'Log all actions performed during staging?', 2, 1, NULL, NULL, N'lstOnOff', '2015-11-09 18:33:58.667', 0, '2015-11-09 18:33:58.667', 0, '85a2e30a-78a6-436e-9b9b-53ebff32486a', 2, 14)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (16, 1, N'CopyOnlyCommittedVersion', N'1', N'Copy Only Committed Version', N'Copy only committed versions?', 2, 1, NULL, NULL, N'lstYesNo', '2015-11-09 18:33:58.667', 0, '2015-11-09 18:33:58.667', 0, '50fe0f33-4954-4d6f-9aab-88ab0741d49b', 6, 5)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (17, 1, N'ShowNamesInHierarchy', N'1', N'Show Names In Hierarchy', N'Default the show/hide options in Hierarchy Explorer?', 2, 1, NULL, NULL, N'lstYesNo', '2015-11-09 18:33:58.673', 0, '2015-11-09 18:33:58.673', 0, '6eebdce7-1d25-442c-b8ca-c86470b47f0d', 3, 5)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (18, 1, N'RowsPerBatch', N'50', N'Rows Per Batch', N'Number of records retrieved at a time in Attribute Explorer', 1, 2, N'50', N'5000', NULL, '2015-11-09 18:33:58.673', 0, '2015-11-09 18:33:58.673', 0, '1f44fea4-4e2a-4769-ae49-17048c5c13d6', 3, 1)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (19, 1, N'DBAListRowLimit', N'50', N'Domain-Based Attribute List Limit', N'Maximum number of records to show in a dropdown list (for quick searches)', 1, 2, N'10', N'1000', NULL, '2015-11-09 18:33:58.677', 0, '2015-11-09 18:33:58.677', 0, 'f78a1b43-ee2a-410c-b2eb-1a0b97321cfe', 3, 2)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (20, 1, N'DatabaseMailProfile', N'', N'Database E-mail Profile', N'The profile used to send Notification e-mails from the Master Data Service', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.677', 0, '2015-11-09 18:33:58.677', 0, '8bb51e13-6968-4da7-8ea0-f44f2812d233', 4, 1)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (21, 1, N'MDSHubName', N'', N'Master Data Services Application Name', N'A friendly name for the Master Data Services Hub', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.680', 0, '2015-11-09 18:33:58.680', 0, '6010f5fa-36dd-49d8-bb9f-1dd6d5ed8503', 2, 15)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (22, 1, N'HierarchyChildNodeLimit', N'50', N'Hierarchy Child Node Limit', N'Maximum number of nodes to be retrieved at one time relative to its parent', 1, 2, N'10', N'1000', NULL, '2015-11-09 18:33:58.680', 0, '2015-11-09 18:33:58.680', 0, '848dc64c-de7b-409a-be60-74a8243f39c4', 3, 3)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (23, 0, N'BusinessRuleEngineIterationLimit', N'5', N'Business Rule Iteration Limit', N'Maximum number of business rule iterations', 1, 2, N'1', N'30', NULL, '2015-11-09 18:33:58.683', 0, '2015-11-09 18:33:58.683', 0, '76a52dc9-ca2f-4f71-a30f-47fb05cb6f93', 5, 1)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (24, 0, N'BusinessRuleExtensibility', N'2', N'Business Rule Extensibility', N'Turn business rule extensibility ON or OFF', 2, 1, NULL, NULL, N'lstOnOff', '2015-11-09 18:33:58.687', 0, '2015-11-09 18:33:58.687', 0, 'cb0116b5-6b55-414c-a885-459f2388028b', 5, 2)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (25, 0, N'BusinessRuleRealtimeMemberCount', N'10000', N'Real time business rule count', N'Limit on the number of members to apply business rules in real-time in Attribute Explorer.', 1, 2, N'1', N'1000000', NULL, '2015-11-09 18:33:58.693', 0, '2015-11-09 18:33:58.693', 0, '4b46739c-2e76-4c51-9142-106a83c84b72', 5, 3)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (26, 1, N'BusinessRuleDefaultPriorityIncrement', N'10', N'Business rule default priority increment', N'New business rules will be created with a priority that is this number greater than the current highest rule priority among rules pertaining to the same Entity and Member Type.', 1, 2, N'0', N'1000', NULL, '2015-11-09 18:33:58.697', 0, '2015-11-09 18:33:58.697', 0, '2c4073af-4976-4caf-9142-806a86c841af', 5, 4)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (27, 0, N'AttributeExplorerMarkAllActionMemberCount', N'1000', N'Attribute Explorer mark all member count', N'Limit on the number of members to allow the user to mark all and perform update/delete actions on in Attribute Explorer.', 1, 2, N'1', N'1000', NULL, '2015-11-09 18:33:58.700', 0, '2015-11-09 18:33:58.700', 0, 'a2c8cb4c-bb88-4228-8b76-cc8819d99cd2', 3, 6)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (28, 0, N'SecurityMemberProcessInterval', N'3600', N'Member security processing Interval', N'Frequency that MDS updates member security records (seconds)', 1, 2, N'60', N'86400', NULL, '2015-11-09 18:33:58.703', 0, '2015-11-09 18:33:58.703', 0, 'deb85251-cc50-4227-b371-7a27f4a1a094', 3, 7)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (29, 0, N'StagingBatchInterval', N'60', N'Staging Batch Interval', N'Frequency that MDM runs the queued batches(seconds)', 1, 2, N'1', N'86400', NULL, '2015-11-09 18:33:58.703', 0, '2015-11-09 18:33:58.703', 0, 'deb85251-cc50-4227-b371-7e27f4a1a09f', 3, 7)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (30, 1, N'EmailRegExPattern', N'^([a-zA-Z0-9_\-\.]+)@((\[[0-9]{1,3} \.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)+$', N'Email regular expression pattern', N'Regular Expression pattern used to validate e-mail addresses', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.703', 0, '2015-11-09 18:33:58.703', 0, 'ea46673b-9a20-4bf2-b16d-6d0c5e2f842e', 4, 7)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (31, 0, N'MDMRootURL', N'', N'WebServer URL', N'Location of the MDS Web URL', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.707', 0, '2015-11-09 18:33:58.707', 0, 'deb85251-cc50-4227-b371-de27f4a1a09d', 3, 7)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (32, 1, N'GridFilterDefaultFuzzySimilarityLevel', N'0.3', N'Default similarity level for fuzzy matches in the Grid Filter', N'In the Grid Filter, when a fuzzy match operation is selected, this value will be used as the default similarity level.', 1, 2, N'0', N'1', NULL, '2015-11-09 18:33:58.707', 0, '2015-11-09 18:33:58.707', 0, '87a073af-4ee6-adaf-714c-806a86c8228b', 3, 4)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (33, 1, N'EmailProfilePrincipalAccount', N'mds_email_user', N'Database Mail Profile account', N'Principal used for sending notifications', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.707', 0, '2015-11-09 18:33:58.707', 0, 'af18ca0b-9ee2-4e17-be5a-a885b0cefc4b', 4, 3)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (34, 1, N'NotificationsPerEmail', N'100', N'Number of notifications in a single email', N'Specifies the limit of individual notifications that can be sent in one e-mail', 1, 2, N'1', N'1000', NULL, '2015-11-09 18:33:58.707', 0, '2015-11-09 18:33:58.707', 0, 'f1f3959d-6c8b-4b91-91c9-3cbbec5d5826', 4, 8)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (35, 0, N'ValidationIssueHTML', N'<?xml version="1.0"?>  
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">  
  <xsl:variable name="rootUrl" select="root/header/root_url"/>  
  <xsl:template match="/">  
    <html>  
      <style type="text/css">  
         .style1 {  
             font-family: Verdana, Arial, Helvetica, sans-serif;  
             font-size: 10px;  
             font-weight: bold;  
         }  
         .style3 {  
            font-size: 10px;   
            font-family: Verdana, Arial, Helvetica, sans-serif;   
         }  
      </style>  
      <img>  
        <xsl:attribute name="src">  
          <xsl:value-of select="$rootUrl"/>/images/logo.jpg  
        </xsl:attribute>  
      </img>  
      <p>  
        <span class="style1">  
          <xsl:value-of select="root/header/Notification_type"/>  
        </span>  
      </p>  
      <table class="style3" border="0">  
          <tr class="style1">  
            <th>  
              <xsl:value-of select="root/header/id"/>  
            </th>  
            <th>  
              <xsl:value-of select="root/header/Model"/>  
            </th>  
            <th>  
              <xsl:value-of select="root/header/Version"/>  
            </th>  
            <th>  
              <xsl:value-of select="root/header/Entity"/>  
            </th>  
            <th>  
              <xsl:value-of select="root/header/MemberCode"/>  
            </th>  
            <th>  
              <xsl:value-of select="root/header/Message"/>  
            </th>  
            <th>  
              <xsl:value-of select="root/header/Issued"/>  
            </th>  
          </tr>  
          <xsl:for-each select="//notification">  
            <tr>  
              <td>  
                <xsl:value-of select="id"/>  
              </td>  
              <td>  
                <xsl:value-of select="model"/>  
              </td>  
              <td>  
                <xsl:value-of select="version"/>  
              </td>  
              <td>  
                <xsl:value-of select="entity"/>  
              </td>  
              <td>  
                <xsl:value-of select="member_code"/>  
              </td>  
              <td>  
                <a>  
                  <xsl:attribute name="href">  
                    <xsl:value-of select="$rootUrl"/>/Redirect.aspx?mid=<xsl:value-of select="model_id"/>&amp;vid=<xsl:value-of select="version_id"/>&amp;eid=<xsl:value-of select="entity_id"/>&amp;meid=<xsl:value-of select="member_id"/>&amp;mtid=<xsl:value-of select="member_type_id"/>  
                  </xsl:attribute>  
                  If <xsl:value-of select="condition_text"/> Then <xsl:value-of select="action_text"/>  
                </a>  
              </td>  
              <td>  
                <xsl:value-of select="issued"/>  
              </td>  
            </tr>  
          </xsl:for-each>  
      </table>  
      <p class="style3">  
          <xsl:value-of select="root/truncated_message"/>  
      </p>  
    </html>  
  </xsl:template>  
</xsl:stylesheet>', N'', N'', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.707', 0, '2015-11-09 18:33:58.707', 0, '43ed43a7-0cd6-4835-87e1-01af5c81ce54', 4, 7)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (36, 0, N'ValidationIssueText', N'<?xml version="1.0"?>  
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">  
<xsl:variable name="rootUrl" select="root/header/root_url"/>  
  <xsl:template match="/">  
    <xsl:value-of select="root/header/Notification_type"/> <xsl:text>&#10;</xsl:text><xsl:text>&#10;</xsl:text>  
    <xsl:value-of select="root/header/id"/> | <xsl:value-of select="root/header/Model"/> | <xsl:value-of select="root/header/Version"/> | <xsl:value-of select="root/header/Entity"/> | <xsl:value-of select="root/header/MemberCode"/> | <xsl:value-of select="root/header/Message"/> | <xsl:value-of select="root/header/Issued"/> <xsl:text>&#10;</xsl:text>             
      <xsl:for-each select="//notification">  
          <xsl:value-of select="id"/> | <xsl:value-of select="model"/> | <xsl:value-of select="version"/> | <xsl:value-of select="entity"/> | <xsl:value-of select="member_code"/> | If <xsl:value-of select="condition_text"/> Then <xsl:value-of select="action_text"/> | <xsl:value-of select="issued"/> <xsl:text>&#10;</xsl:text>           <xsl:value-of select="link_text"/> <xsl:text>&#32;</xsl:text> <xsl:value-of select="$rootUrl"/>/Redirect.aspx?mid=<xsl:value-of select="model_id"/>&amp;vid=<xsl:value-of select="version_id"/>&amp;eid=<xsl:value-of select="entity_id"/>&amp;meid=<xsl:value-of select="member_id"/>&amp;mtid=<xsl:value-of select="member_type_id"/><xsl:text>&#10;</xsl:text>  
      </xsl:for-each>  
    <xsl:text>&#10;</xsl:text><xsl:text>&#10;</xsl:text><xsl:value-of select="root/truncated_message"/>  
  </xsl:template>  
</xsl:stylesheet>', N'', N'', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.710', 0, '2015-11-09 18:33:58.710', 0, 'd51c5e9c-b559-4caa-b230-0db4327ac2e0', 4, 7)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (37, 0, N'VersionStatusChangeText', N'<?xml version="1.0"?>  
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">  
  <xsl:variable name="rootUrl" select="root/header/root_url"/>  
  <xsl:template match="/">  
    <xsl:value-of select="root/header/Notification_type"/> <xsl:text>&#10;</xsl:text><xsl:text>&#10;</xsl:text>  
    <xsl:value-of select="root/header/Model"/> | <xsl:value-of select="root/header/Version"/> | <xsl:value-of select="root/header/PriorStatus"/> | <xsl:value-of select="root/header/NewStatus"/> | <xsl:value-of select="root/header/Issued"/><xsl:text>&#09;</xsl:text><xsl:text>&#10;</xsl:text>  
    <xsl:for-each select="//notification">  
      <xsl:value-of select="model"/> | <xsl:value-of select="version"/>, <xsl:value-of select="version_description"/> | <xsl:value-of select="prior_status"/> | <xsl:value-of select="new_status"/> | <xsl:value-of select="issued"/><xsl:text>&#09;</xsl:text><xsl:text>&#10;</xsl:text>             
      <xsl:value-of select="link_text"/> <xsl:text>&#32;</xsl:text> <xsl:value-of select="$rootUrl"/>/Redirect.aspx<xsl:text>&#09;</xsl:text><xsl:text>&#10;</xsl:text>  
    </xsl:for-each>  
    <xsl:text>&#10;</xsl:text><xsl:text>&#10;</xsl:text><xsl:value-of select="root/truncated_message"/>  
  </xsl:template>  
</xsl:stylesheet>', N'', N'', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.710', 0, '2015-11-09 18:33:58.710', 0, '61813cfd-16f2-47dc-b5f8-ba2a8ba1f168', 4, 7)
INSERT INTO [mdm].[tblSystemSetting] ([ID], [IsVisible], [SettingName], [SettingValue], [DisplayName], [Description], [SettingType_ID], [DataType_ID], [MinValue], [MaxValue], [ListCode], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID], [SystemSettingGroup_ID], [DisplaySequence]) VALUES (38, 0, N'VersionStatusChangeHTML', N'<?xml version="1.0"?>  
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">  
  <xsl:variable name="rootUrl" select="root/header/root_url"/>  
  <xsl:template match="/">  
    <html>  
      <style type="text/css">  
         .style1 {  
             font-family: Verdana, Arial, Helvetica, sans-serif;  
             font-size: 10px;  
             font-weight: bold;  
         }  
         .style3 {  
            font-size: 10px;   
            font-family: Verdana, Arial, Helvetica, sans-serif;   
         }  
      </style>  
      <img>  
        <xsl:attribute name="src">  
          <xsl:value-of select="$rootUrl"/>/images/logo.jpg  
        </xsl:attribute>  
      </img>  
  
      <p>  
        <span class="style1">  
          <xsl:value-of select="root/header/Notification_type"/>  
        </span>  
      </p>  
        
      <table class="style3" border="0">  
        <tr class="style1">  
          <th>  
            <xsl:value-of select="root/header/Model"/>  
          </th>  
          <th>  
            <xsl:value-of select="root/header/Version"/>  
          </th>  
          <th>  
            <xsl:value-of select="root/header/PriorStatus"/>  
          </th>  
          <th>  
            <xsl:value-of select="root/header/NewStatus"/>  
          </th>  
          <th>  
            <xsl:value-of select="root/header/Issued"/>  
          </th>  
        </tr>  
        <xsl:for-each select="//notification">  
          <tr>  
            <td>  
              <xsl:value-of select="model"/>  
            </td>  
            <td>  
              <xsl:value-of select="version"/>, <xsl:value-of select="version_description"/>  
            </td>  
            <td>  
              <xsl:value-of select="prior_status"/>  
            </td>  
            <td>  
              <xsl:value-of select="new_status"/>  
            </td>  
            <td>  
              <xsl:value-of select="issued"/>  
            </td>  
          </tr>  
        </xsl:for-each>  
      </table>  
  
      <p class="style3">  
        <a>  
          <xsl:attribute name="href">  
            <xsl:value-of select="$rootUrl"/>  
          </xsl:attribute>  
          <xsl:value-of select="root/header/link_text"/>  
        </a>  
      </p>  
  
      <p>&#160;</p>  
  
      <p class="style3">  
        <xsl:value-of select="root/truncated_message"/>  
      </p>  
    </html>  
  </xsl:template>  
</xsl:stylesheet>', N'', N'', 1, 1, NULL, NULL, NULL, '2015-11-09 18:33:58.710', 0, '2015-11-09 18:33:58.710', 0, '3f0ab528-f82a-40cb-a13a-3d56def70b01', 4, 7)
SET IDENTITY_INSERT [mdm].[tblSystemSetting] OFF
