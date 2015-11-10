SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_2_12_CHILDATTRIBUTES]  
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
                            ,T.[uda_12_389] AS [AddressLine1]  
                            ,T.[uda_12_390] AS [AddressLine2]  
                            ,T.[uda_12_391] AS [AddressLine3]  
                            ,[StateProvince].Code AS [StateProvince]  
                            ,[StateProvince].ID AS [StateProvince.ID]  
                            ,[StateProvince].Code AS [StateProvince.Code]  
                            ,[StateProvince].Name AS [StateProvince.Name]  
                            ,[Country].Code AS [Country]  
                            ,[Country].ID AS [Country.ID]  
                            ,[Country].Code AS [Country.Code]  
                            ,[Country].Name AS [Country.Name]  
                            ,T.[uda_12_394] AS [PostalCode]  
                            ,T.[uda_12_395] AS [Telephone]  
                            ,T.[uda_12_396] AS [Email]  
                            ,T.[uda_12_397] AS [Website]  
                            ,[CustomerType].Code AS [CustomerType]  
                            ,[CustomerType].ID AS [CustomerType.ID]  
                            ,[CustomerType].Code AS [CustomerType.Code]  
                            ,[CustomerType].Name AS [CustomerType.Name]  
                            ,[Salutation].Code AS [Salutation]  
                            ,[Salutation].ID AS [Salutation.ID]  
                            ,[Salutation].Code AS [Salutation.Code]  
                            ,[Salutation].Name AS [Salutation.Name]  
                            ,[BillingCurrency].Code AS [BillingCurrency]  
                            ,[BillingCurrency].ID AS [BillingCurrency.ID]  
                            ,[BillingCurrency].Code AS [BillingCurrency.Code]  
                            ,[BillingCurrency].Name AS [BillingCurrency.Name]  
                            ,[PaymentTerms].Code AS [PaymentTerms]  
                            ,[PaymentTerms].ID AS [PaymentTerms.ID]  
                            ,[PaymentTerms].Code AS [PaymentTerms.Code]  
                            ,[PaymentTerms].Name AS [PaymentTerms.Name]  
                            ,[SalesDistrict].Code AS [SalesDistrict]  
                            ,[SalesDistrict].ID AS [SalesDistrict.ID]  
                            ,[SalesDistrict].Code AS [SalesDistrict.Code]  
                            ,[SalesDistrict].Name AS [SalesDistrict.Name]  
                            ,[AddressType].Code AS [AddressType]  
                            ,[AddressType].ID AS [AddressType.ID]  
                            ,[AddressType].Code AS [AddressType.Code]  
                            ,[AddressType].Name AS [AddressType.Name]  
                            ,T.[uda_12_404] AS [City]  
                FROM mdm.[tbl_2_12_EN] AS T  
            LEFT JOIN mdm.tblUser eu ON T.EnterUserID = eu.ID  
            LEFT JOIN mdm.tblUser lcu ON T.LastChgUserID = lcu.ID  
            LEFT JOIN mdm.tblModelVersion ev ON T.EnterVersionID = ev.ID  
            LEFT JOIN mdm.tblModelVersion lcv ON T.LastChgVersionID = lcv.ID  
  
                        LEFT JOIN mdm.[tbl_2_18_EN] AS [StateProvince] ON [StateProvince].ID = T.[uda_12_392]   
                            AND [StateProvince].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_2_9_EN] AS [Country] ON [Country].ID = T.[uda_12_393]   
                            AND [Country].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_2_13_EN] AS [CustomerType] ON [CustomerType].ID = T.[uda_12_398]   
                            AND [CustomerType].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_2_17_EN] AS [Salutation] ON [Salutation].ID = T.[uda_12_399]   
                            AND [Salutation].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_2_11_EN] AS [BillingCurrency] ON [BillingCurrency].ID = T.[uda_12_400]   
                            AND [BillingCurrency].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_2_10_EN] AS [PaymentTerms] ON [PaymentTerms].ID = T.[uda_12_401]   
                            AND [PaymentTerms].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_2_15_EN] AS [SalesDistrict] ON [SalesDistrict].ID = T.[uda_12_402]   
                            AND [SalesDistrict].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_2_6_EN] AS [AddressType] ON [AddressType].ID = T.[uda_12_403]   
                            AND [AddressType].Version_ID = T.Version_ID  
                WHERE T.Status_ID = 1;
GO
