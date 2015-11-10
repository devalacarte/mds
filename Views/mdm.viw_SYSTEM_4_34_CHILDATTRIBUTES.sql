SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_4_34_CHILDATTRIBUTES]  
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
                            ,[LineItemDetail].Code AS [LineItemDetail]  
                            ,[LineItemDetail].ID AS [LineItemDetail.ID]  
                            ,[LineItemDetail].Code AS [LineItemDetail.Code]  
                            ,[LineItemDetail].Name AS [LineItemDetail.Name]  
                            ,[AccountType].Code AS [AccountType]  
                            ,[AccountType].ID AS [AccountType.ID]  
                            ,[AccountType].Code AS [AccountType.Code]  
                            ,[AccountType].Name AS [AccountType.Name]  
                            ,[DebitCreditInd].Code AS [DebitCreditInd]  
                            ,[DebitCreditInd].ID AS [DebitCreditInd.ID]  
                            ,[DebitCreditInd].Code AS [DebitCreditInd.Code]  
                            ,[DebitCreditInd].Name AS [DebitCreditInd.Name]  
                            ,[Operator].Code AS [Operator]  
                            ,[Operator].ID AS [Operator.ID]  
                            ,[Operator].Code AS [Operator.Code]  
                            ,[Operator].Name AS [Operator.Name]  
                FROM mdm.[tbl_4_34_EN] AS T  
            LEFT JOIN mdm.tblUser eu ON T.EnterUserID = eu.ID  
            LEFT JOIN mdm.tblUser lcu ON T.LastChgUserID = lcu.ID  
            LEFT JOIN mdm.tblModelVersion ev ON T.EnterVersionID = ev.ID  
            LEFT JOIN mdm.tblModelVersion lcv ON T.LastChgVersionID = lcv.ID  
  
                        LEFT JOIN mdm.[tbl_4_39_EN] AS [LineItemDetail] ON [LineItemDetail].ID = T.[uda_34_934]   
                            AND [LineItemDetail].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_4_33_EN] AS [AccountType] ON [AccountType].ID = T.[uda_34_935]   
                            AND [AccountType].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_4_36_EN] AS [DebitCreditInd] ON [DebitCreditInd].ID = T.[uda_34_936]   
                            AND [DebitCreditInd].Version_ID = T.Version_ID  
                        LEFT JOIN mdm.[tbl_4_40_EN] AS [Operator] ON [Operator].ID = T.[uda_34_937]   
                            AND [Operator].Version_ID = T.Version_ID  
                WHERE T.Status_ID = 1;
GO
