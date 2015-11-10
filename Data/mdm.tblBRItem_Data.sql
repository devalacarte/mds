SET IDENTITY_INSERT [mdm].[tblBRItem] ON
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (1, 1, 152, 1, N'Name is required ', N'NULLIF([Name], N'''') IS NOT NULL', N'Name', N'nvarchar', 1, '60ebb5c7-1b86-43ea-b40a-9ee49e4da0df')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (2, 1, 152, 2, N'AddressLine1 is required ', N'NULLIF([AddressLine1], N'''') IS NOT NULL', N'AddressLine1', N'nvarchar', 1, '83205c58-6229-4d6a-97ed-2eb38957627c')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (3, 1, 152, 3, N'City is required ', N'NULLIF([City], N'''') IS NOT NULL', N'City', N'nvarchar', 1, '14ed73e4-7d07-4bf8-9a54-684df4cf568f')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (4, 1, 152, 4, N'StateProvince is required ', N'NULLIF([StateProvince], N'''') IS NOT NULL', N'StateProvince', N'int', 2, '12c94a2b-6e64-48f6-9c68-02ed8d209335')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (5, 1, 152, 5, N'Country is required ', N'NULLIF([Country], N'''') IS NOT NULL', N'Country', N'int', 2, 'cecb726b-875e-4e7d-8cff-dfb8a4460436')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (6, 1, 152, 6, N'PostalCode is required ', N'NULLIF([PostalCode], N'''') IS NOT NULL', N'PostalCode', N'nvarchar', 1, 'f45140e2-8441-4aee-8835-b9297084b75c')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (7, 1, 152, 7, N'CustomerType is required ', N'NULLIF([CustomerType], N'''') IS NOT NULL', N'CustomerType', N'int', 2, 'ad6fa422-913d-49b8-ba05-6ef657c9e61b')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (8, 1, 152, 8, N'SalesDistrict is required ', N'NULLIF([SalesDistrict], N'''') IS NOT NULL', N'SalesDistrict', N'int', 2, '4fc2ed31-5f11-452e-a711-041e35af0d8a')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (9, 1, 152, 9, N'AddressType is required ', N'NULLIF([AddressType], N'''') IS NOT NULL', N'AddressType', N'int', 2, '4151b0df-63ad-4c47-b15e-022a2a2cfe7c')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (10, 2, 148, 1, N'PaymentTerms defaults to CASH', N'N''CASH''', N'PaymentTerms', N'int', 2, '51fc1462-25fe-4a45-9c7c-717eecc8530a')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (11, 3, 137, 1, N'CustomerType is equal to 2', N'( (md.[CustomerType] IS NULL AND N''2'' IS NULL) OR md.[CustomerType] = N''2'' )', N'CustomerType', N'int', 2, '8492af33-e826-408c-97f9-a92567bddf5a')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (12, 4, 148, 1, N'PaymentTerms defaults to 210Net30', N'N''210Net30''', N'PaymentTerms', N'int', 2, '82b4d51e-54fe-4677-9c46-908c1c02cc94')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (13, 5, 137, 1, N'CustomerType is equal to 1', N'( (md.[CustomerType] IS NULL AND N''1'' IS NULL) OR md.[CustomerType] = N''1'' )', N'CustomerType', N'int', 2, '342637af-adf3-4cd1-9431-7c10bbe60ce9')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (14, 6, 152, 1, N'Name is required ', N'NULLIF([Name], N'''') IS NOT NULL', N'Name', N'nvarchar', 1, 'be430cc8-70ac-41ae-8686-a7245047f083')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (15, 6, 152, 2, N'ProductSubCategory is required ', N'NULLIF([ProductSubCategory], N'''') IS NOT NULL', N'ProductSubCategory', N'int', 2, 'd2dc9a1a-8be2-481a-a226-6c164ba834be')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (16, 6, 152, 3, N'Color is required ', N'NULLIF([Color], N'''') IS NOT NULL', N'Color', N'int', 2, '0210faab-4402-498d-b340-b21ace8d2e34')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (17, 6, 152, 4, N'Country is required ', N'NULLIF([Country], N'''') IS NOT NULL', N'Country', N'int', 2, '08db428d-d7c7-4b3d-b1d9-286018236ff0')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (18, 6, 152, 5, N'StandardCost is required ', N'[StandardCost] IS NOT NULL', N'StandardCost', N'decimal', 1, '4afb319f-9877-431d-934f-3818ff698881')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (19, 6, 152, 6, N'SafetyStockLevel is required ', N'[SafetyStockLevel] IS NOT NULL', N'SafetyStockLevel', N'decimal', 1, 'a17a1698-2fcb-40ce-aac9-bd7fb9030603')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (20, 6, 152, 7, N'ReorderPoint is required ', N'[ReorderPoint] IS NOT NULL', N'ReorderPoint', N'decimal', 1, '01c148a4-1e65-4395-a161-06582708ecca')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (21, 6, 152, 8, N'InHouseManufacture is required ', N'NULLIF([InHouseManufacture], N'''') IS NOT NULL', N'InHouseManufacture', N'int', 2, '3c16c416-58ab-42d9-bad9-fe20623108da')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (22, 6, 152, 9, N'SellStartDate is required ', N'[SellStartDate] IS NOT NULL', N'SellStartDate', N'datetime2', 1, '2904285a-f6a2-4413-bef4-3dad86d37e1a')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (23, 6, 152, 10, N'FinishedGoodIndicator is required ', N'NULLIF([FinishedGoodIndicator], N'''') IS NOT NULL', N'FinishedGoodIndicator', N'int', 2, 'e89b4485-8733-41a2-870b-ebe459a82583')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (24, 6, 152, 11, N'ProductLine is required ', N'NULLIF([ProductLine], N'''') IS NOT NULL', N'ProductLine', N'int', 2, '926f0341-5454-49c6-b019-60430069d3ff')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (25, 7, 159, 1, N'DaysToManufacture must be between 1 and 10', N'md.[DaysToManufacture] BETWEEN 1 AND 10', N'DaysToManufacture', N'decimal', 1, 'f140c73f-aed1-497c-8c77-862907188164')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (26, 8, 137, 1, N'InHouseManufacture is equal to Y', N'( (md.[InHouseManufacture] IS NULL AND N''Y'' IS NULL) OR md.[InHouseManufacture] = N''Y'' )', N'InHouseManufacture', N'int', 2, '3e2274ca-fbf5-40e0-b052-3c4f19a4e0ac')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (27, 9, 155, 1, N'StandardCost must be greater than 0', N'md.[StandardCost] > 0', N'StandardCost', N'decimal', 1, 'adbbeb77-a2e3-481f-99b5-83b51341d853')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (28, 10, 155, 1, N'MSRP must be greater than 0', N'md.[MSRP] > 0', N'MSRP', N'decimal', 1, '02c0273c-b033-4cf3-83fa-50f1515be980')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (29, 10, 155, 2, N'DealerCost must be greater than 0', N'md.[DealerCost] > 0', N'DealerCost', N'decimal', 1, '97136d30-18b3-4e63-985d-260cd7f2c5ef')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (30, 11, 137, 1, N'FinishedGoodIndicator is equal to Y', N'( (md.[FinishedGoodIndicator] IS NULL AND N''Y'' IS NULL) OR md.[FinishedGoodIndicator] = N''Y'' )', N'FinishedGoodIndicator', N'int', 2, '4b24647e-8a78-4ddf-a4d4-7874cff5c075')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (31, 12, 152, 2, N'LineItemDetail is required ', N'NULLIF([LineItemDetail], N'''') IS NOT NULL', N'LineItemDetail', N'int', 2, '2f9f6329-709e-495a-839b-608bcdb028fd')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (32, 12, 152, 2, N'Name is required ', N'NULLIF([Name], N'''') IS NOT NULL', N'Name', N'nvarchar', 1, 'c2b986a5-748c-4cdc-aa0f-c2d669acec74')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (33, 12, 152, 3, N'AccountType is required ', N'NULLIF([AccountType], N'''') IS NOT NULL', N'AccountType', N'int', 2, 'bd89394e-2347-4b58-854b-7de7e4f9181e')
INSERT INTO [mdm].[tblBRItem] ([ID], [BRLogicalOperatorGroup_ID], [BRItemAppliesTo_ID], [Sequence], [ItemText], [ItemSQL], [AnchorName], [AnchorDataType], [AnchorAttributeType], [MUID]) VALUES (34, 12, 152, 4, N'DebitCreditInd is required ', N'NULLIF([DebitCreditInd], N'''') IS NOT NULL', N'DebitCreditInd', N'int', 2, '43d0b87a-3d23-4521-82b0-6be5381036d0')
SET IDENTITY_INSERT [mdm].[tblBRItem] OFF