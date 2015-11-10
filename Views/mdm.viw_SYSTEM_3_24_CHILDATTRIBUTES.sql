SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_3_24_CHILDATTRIBUTES]  
                /*WITH ENCRYPTION*/ AS SELECT   
                 T.ID  
                ,T.Version_ID  
                ,T.ValidationStatus_ID  
                --Change Tracking  
                ,T.ChangeTrackingMask  
                 --Auditing columns (Creation)  
                ,T.EnterDTM  
                ,T.EnterUserID  
                ,eu.[UserName] AS EnterUserName  
                ,eu.MUID AS EnterUserMuid  
                  
                ,T.EnterVersionID AS EnterVersionId  
                ,ev.[Name] AS EnterVersionName  
                ,ev.MUID AS EnterVersionMuid  
  
                --Auditing columns (Updates)  
                ,T.LastChgDTM  
                ,T.LastChgUserID  
                ,lcu.[UserName] AS LastChgUserName  
                ,lcu.MUID AS LastChgUserMuid  
  
                ,T.LastChgVersionID AS LastChgVersionId  
                ,lcv.[Name] AS LastChgVersionName  
                ,lcv.MUID AS LastChgVersionMuid  
                --Custom attributes  
                            ,T.[Name] AS [Name]  
                            ,T.[Code] AS [Code]  
                            ,[ProductSubCategory].Code AS [ProductSubCategory]  
                            ,[ProductSubCategory].ID AS [ProductSubCategory.ID]  
                            ,[ProductSubCategory].Code AS [ProductSubCategory.Code]  
                            ,[ProductSubCategory].Name AS [ProductSubCategory.Name]  
                            ,[Color].Code AS [Color]  
                            ,[Color].ID AS [Color.ID]  
                            ,[Color].Code AS [Color.Code]  
                            ,[Color].Name AS [Color.Name]  
                            ,[Class].Code AS [Class]  
                            ,[Class].ID AS [Class.ID]  
                            ,[Class].Code AS [Class.Code]  
                            ,[Class].Name AS [Class.Name]  
                            ,[Style].Code AS [Style]  
                            ,[Style].ID AS [Style.ID]  
                            ,[Style].Code AS [Style.Code]  
                            ,[Style].Name AS [Style.Name]  
                            ,[Country].Code AS [Country]  
                            ,[Country].ID AS [Country.ID]  
                            ,[Country].Code AS [Country.Code]  
                            ,[Country].Name AS [Country.Name]  
                            ,T.[uda_24_695] AS [StandardCost]  
                            ,T.[uda_24_696] AS [SafetyStockLevel]  
                            ,T.[uda_24_697] AS [ReorderPoint]  
                            ,T.[uda_24_698] AS [MSRP]  
                            ,T.[uda_24_699] AS [Weight]  
                            ,T.[uda_24_700] AS [DaysToManufacture]  
                            ,T.[uda_24_701] AS [DealerCost]  
                            ,T.[uda_24_702] AS [DocumentationURL]  
                            ,T.[uda_24_703] AS [SellStartDate]  
                            ,T.[uda_24_704] AS [SellEndDate]  
                            ,[SizeUoM].Code AS [SizeUoM]  
                            ,[SizeUoM].ID AS [SizeUoM.ID]  
                            ,[SizeUoM].Code AS [SizeUoM.Code]  
                            ,[SizeUoM].Name AS [SizeUoM.Name]  
                            ,[WeightUoM].Code AS [WeightUoM]  
                            ,[WeightUoM].ID AS [WeightUoM.ID]  
                            ,[WeightUoM].Code AS [WeightUoM.Code]  
                            ,[WeightUoM].Name AS [WeightUoM.Name]  
                            ,[InHouseManufacture].Code AS [InHouseManufacture]  
                            ,[InHouseManufacture].ID AS [InHouseManufacture.ID]  
                            ,[InHouseManufacture].Code AS [InHouseManufacture.Code]  
                            ,[InHouseManufacture].Name AS [InHouseManufacture.Name]  
                            ,[FinishedGoodIndicator].Code AS [FinishedGoodIndicator]  
                            ,[FinishedGoodIndicator].ID AS [FinishedGoodIndicator.ID]  
                            ,[FinishedGoodIndicator].Code AS [FinishedGoodIndicator.Code]  
                            ,[FinishedGoodIndicator].Name AS [FinishedGoodIndicator.Name]  
                            ,[DiscontinuedItemInd].Code AS [DiscontinuedItemInd]  
                            ,[DiscontinuedItemInd].ID AS [DiscontinuedItemInd.ID]  
                            ,[DiscontinuedItemInd].Code AS [DiscontinuedItemInd.Code]  
                            ,[DiscontinuedItemInd].Name AS [DiscontinuedItemInd.Name]  
                            ,T.[uda_24_710] AS [DiscontiuedDate]  
                            ,[ProductLine].Code AS [ProductLine]  
                            ,[ProductLine].ID AS [ProductLine.ID]  
                            ,[ProductLine].Code AS [ProductLine.Code]  
                            ,[ProductLine].Name AS [ProductLine.Name]  
                            ,[DealerCostCurrencyCode].Code AS [DealerCostCurrencyCode]  
                            ,[DealerCostCurrencyCode].ID AS [DealerCostCurrencyCode.ID]  
                            ,[DealerCostCurrencyCode].Code AS [DealerCostCurrencyCode.Code]  
                            ,[DealerCostCurrencyCode].Name AS [DealerCostCurrencyCode.Name]  
                            ,[MSRPCurrencyCode].Code AS [MSRPCurrencyCode]  
                            ,[MSRPCurrencyCode].ID AS [MSRPCurrencyCode.ID]  
                            ,[MSRPCurrencyCode].Code AS [MSRPCurrencyCode.Code]  
                            ,[MSRPCurrencyCode].Name AS [MSRPCurrencyCode.Name]  
                            ,[Size].Code AS [Size]  
                            ,[Size].ID AS [Size.ID]  
                            ,[Size].Code AS [Size.Code]  
                            ,[Size].Name AS [Size.Name]  
                FROM mdm.[tbl_3_24_EN] AS T  
            LEFT JOIN mdm.tblUser eu ON T.EnterUserID = eu.ID  
            LEFT JOIN mdm.tblUser lcu ON T.LastChgUserID = lcu.ID  
            LEFT JOIN mdm.tblModelVersion ev ON T.EnterVersionID = ev.ID  
            LEFT JOIN mdm.tblModelVersion lcv ON T.LastChgVersionID = lcv.ID  
  
                        LEFT JOIN mdm.[tbl_3_28_EN] AS [ProductSubCategory] ON [ProductSubCategory].ID = T.[uda_24_690]   
                            AND [ProductSubCategory].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_21_EN] AS [Color] ON [Color].ID = T.[uda_24_691]   
                            AND [Color].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_20_EN] AS [Class] ON [Class].ID = T.[uda_24_692]   
                            AND [Class].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_30_EN] AS [Style] ON [Style].ID = T.[uda_24_693]   
                            AND [Style].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_22_EN] AS [Country] ON [Country].ID = T.[uda_24_694]   
                            AND [Country].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_31_EN] AS [SizeUoM] ON [SizeUoM].ID = T.[uda_24_705]   
                            AND [SizeUoM].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_31_EN] AS [WeightUoM] ON [WeightUoM].ID = T.[uda_24_706]   
                            AND [WeightUoM].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_32_EN] AS [InHouseManufacture] ON [InHouseManufacture].ID = T.[uda_24_707]   
                            AND [InHouseManufacture].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_32_EN] AS [FinishedGoodIndicator] ON [FinishedGoodIndicator].ID = T.[uda_24_708]   
                            AND [FinishedGoodIndicator].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_32_EN] AS [DiscontinuedItemInd] ON [DiscontinuedItemInd].ID = T.[uda_24_709]   
                            AND [DiscontinuedItemInd].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_27_EN] AS [ProductLine] ON [ProductLine].ID = T.[uda_24_711]   
                            AND [ProductLine].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_23_EN] AS [DealerCostCurrencyCode] ON [DealerCostCurrencyCode].ID = T.[uda_24_712]   
                            AND [DealerCostCurrencyCode].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_23_EN] AS [MSRPCurrencyCode] ON [MSRPCurrencyCode].ID = T.[uda_24_713]   
                            AND [MSRPCurrencyCode].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_3_29_EN] AS [Size] ON [Size].ID = T.[uda_24_714]   
                            AND [Size].Version_ID = T.Version_ID  
                WHERE T.Status_ID = 1;
GO
