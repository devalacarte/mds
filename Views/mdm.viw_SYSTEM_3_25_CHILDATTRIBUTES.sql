SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_3_25_CHILDATTRIBUTES]  
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
                            ,[ProductGroup].Code AS [ProductGroup]  
                            ,[ProductGroup].ID AS [ProductGroup.ID]  
                            ,[ProductGroup].Code AS [ProductGroup.Code]  
                            ,[ProductGroup].Name AS [ProductGroup.Name]  
                FROM mdm.[tbl_3_25_EN] AS T  
            LEFT JOIN mdm.tblUser eu ON T.EnterUserID = eu.ID  
            LEFT JOIN mdm.tblUser lcu ON T.LastChgUserID = lcu.ID  
            LEFT JOIN mdm.tblModelVersion ev ON T.EnterVersionID = ev.ID  
            LEFT JOIN mdm.tblModelVersion lcv ON T.LastChgVersionID = lcv.ID  
  
                        LEFT JOIN mdm.[tbl_3_26_EN] AS [ProductGroup] ON [ProductGroup].ID = T.[uda_25_715]   
                            AND [ProductGroup].Version_ID = T.Version_ID  
                WHERE T.Status_ID = 1;
GO
