SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_2_14_CHILDATTRIBUTES]  
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
                            ,[Area].Code AS [Area]  
                            ,[Area].ID AS [Area.ID]  
                            ,[Area].Code AS [Area.Code]  
                            ,[Area].Name AS [Area.Name]  
                FROM mdm.[tbl_2_14_EN] AS T  
            LEFT JOIN mdm.tblUser eu ON T.EnterUserID = eu.ID  
            LEFT JOIN mdm.tblUser lcu ON T.LastChgUserID = lcu.ID  
            LEFT JOIN mdm.tblModelVersion ev ON T.EnterVersionID = ev.ID  
            LEFT JOIN mdm.tblModelVersion lcv ON T.LastChgVersionID = lcv.ID  
  
                        LEFT JOIN mdm.[tbl_2_7_EN] AS [Area] ON [Area].ID = T.[uda_14_405]   
                            AND [Area].Version_ID = T.Version_ID  
                WHERE T.Status_ID = 1;
GO
