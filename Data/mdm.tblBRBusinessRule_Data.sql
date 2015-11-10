SET IDENTITY_INSERT [mdm].[tblBRBusinessRule] ON
INSERT INTO [mdm].[tblBRBusinessRule] ([ID], [Name], [Description], [RuleConditionText], [RuleActionText], [RuleConditionSQL], [ForeignType_ID], [Foreign_ID], [Status_ID], [Priority], [NotificationGroupID], [NotificationUserID], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID]) VALUES (1, N'Required fields', N'Required fields', N'None', N'    Name is required 
    AddressLine1 is required 
    City is required 
    StateProvince is required 
    Country is required 
    PostalCode is required 
    CustomerType is required 
    SalesDistrict is required 
    AddressType is required 
', N'1=1', 1, 12, 1, 10, NULL, NULL, '2015-11-10 05:59:47.093', 1, '2015-11-10 05:59:48.020', 1, '3866d154-f0ab-45f3-95f2-c17aecfd9c4e')
INSERT INTO [mdm].[tblBRBusinessRule] ([ID], [Name], [Description], [RuleConditionText], [RuleActionText], [RuleConditionSQL], [ForeignType_ID], [Foreign_ID], [Status_ID], [Priority], [NotificationGroupID], [NotificationUserID], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID]) VALUES (2, N'Person pmt terms', N'Default payment terms for persons', N'CustomerType is equal to 2', N'    PaymentTerms defaults to CASH
', N'((( (md.[CustomerType] IS NULL AND N''2'' IS NULL) OR md.[CustomerType] = N''2'' )))', 1, 12, 1, 20, NULL, NULL, '2015-11-10 05:59:48.123', 1, '2015-11-10 05:59:48.277', 1, 'ea8fca23-942c-419c-9e93-8d0912e15a24')
INSERT INTO [mdm].[tblBRBusinessRule] ([ID], [Name], [Description], [RuleConditionText], [RuleActionText], [RuleConditionSQL], [ForeignType_ID], [Foreign_ID], [Status_ID], [Priority], [NotificationGroupID], [NotificationUserID], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID]) VALUES (3, N'Org pmt terms', N'Default payment terms for organizations', N'CustomerType is equal to 1', N'    PaymentTerms defaults to 210Net30
', N'((( (md.[CustomerType] IS NULL AND N''1'' IS NULL) OR md.[CustomerType] = N''1'' )))', 1, 12, 1, 30, NULL, NULL, '2015-11-10 05:59:48.280', 1, '2015-11-10 05:59:48.297', 1, 'b02b190a-fc37-43af-b69c-44f000e2d451')
INSERT INTO [mdm].[tblBRBusinessRule] ([ID], [Name], [Description], [RuleConditionText], [RuleActionText], [RuleConditionSQL], [ForeignType_ID], [Foreign_ID], [Status_ID], [Priority], [NotificationGroupID], [NotificationUserID], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID]) VALUES (4, N'Required fields', N'Required fields', N'None', N'    Name is required 
    ProductSubCategory is required 
    Color is required 
    Country is required 
    StandardCost is required 
    SafetyStockLevel is required 
    ReorderPoint is required 
    InHouseManufacture is required 
    SellStartDate is required 
    FinishedGoodIndicator is required 
    ProductLine is required 
', N'1=1', 1, 24, 1, 10, NULL, NULL, '2015-11-10 06:01:16.510', 1, '2015-11-10 06:01:16.927', 1, 'e47e098f-9a18-4242-a8fe-c620e66b24eb')
INSERT INTO [mdm].[tblBRBusinessRule] ([ID], [Name], [Description], [RuleConditionText], [RuleActionText], [RuleConditionSQL], [ForeignType_ID], [Foreign_ID], [Status_ID], [Priority], [NotificationGroupID], [NotificationUserID], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID]) VALUES (5, N'DaysToManufacture', N'Days to manufacture', N'InHouseManufacture is equal to Y', N'    DaysToManufacture must be between 1 and 10
', N'((( (md.[InHouseManufacture] IS NULL AND N''Y'' IS NULL) OR md.[InHouseManufacture] = N''Y'' )))', 1, 24, 1, 20, NULL, NULL, '2015-11-10 06:01:16.930', 1, '2015-11-10 06:01:16.983', 1, '7309585c-1653-4aa9-b7e9-be7af6581054')
INSERT INTO [mdm].[tblBRBusinessRule] ([ID], [Name], [Description], [RuleConditionText], [RuleActionText], [RuleConditionSQL], [ForeignType_ID], [Foreign_ID], [Status_ID], [Priority], [NotificationGroupID], [NotificationUserID], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID]) VALUES (6, N'Std Cost', N'Std cost must be &amp;gt; 0', N'None', N'    StandardCost must be greater than 0
', N'1=1', 1, 24, 1, 30, NULL, NULL, '2015-11-10 06:01:16.983', 1, '2015-11-10 06:01:16.997', 1, 'e9ccb062-913e-448f-be03-45aca7e44532')
INSERT INTO [mdm].[tblBRBusinessRule] ([ID], [Name], [Description], [RuleConditionText], [RuleActionText], [RuleConditionSQL], [ForeignType_ID], [Foreign_ID], [Status_ID], [Priority], [NotificationGroupID], [NotificationUserID], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID]) VALUES (7, N'FG MSRP Cost', N'FG''s must have msrp & dealer cost', N'FinishedGoodIndicator is equal to Y', N'    MSRP must be greater than 0
    DealerCost must be greater than 0
', N'((( (md.[FinishedGoodIndicator] IS NULL AND N''Y'' IS NULL) OR md.[FinishedGoodIndicator] = N''Y'' )))', 1, 24, 1, 40, NULL, NULL, '2015-11-10 06:01:16.997', 1, '2015-11-10 06:01:17.017', 1, '6263deb6-cf8f-477e-9f2c-5a6fe49e7aba')
INSERT INTO [mdm].[tblBRBusinessRule] ([ID], [Name], [Description], [RuleConditionText], [RuleActionText], [RuleConditionSQL], [ForeignType_ID], [Foreign_ID], [Status_ID], [Priority], [NotificationGroupID], [NotificationUserID], [EnterDTM], [EnterUserID], [LastChgDTM], [LastChgUserID], [MUID]) VALUES (8, N'Required fields', N'', N'None', N'    LineItemDetail is required 
    Name is required 
    AccountType is required 
    DebitCreditInd is required 
', N'1=1', 1, 34, 1, 10, NULL, NULL, '2015-11-10 06:02:14.773', 1, '2015-11-10 06:02:15.183', 1, '7e060c2d-1970-4844-bfed-81586883b668')
SET IDENTITY_INSERT [mdm].[tblBRBusinessRule] OFF
