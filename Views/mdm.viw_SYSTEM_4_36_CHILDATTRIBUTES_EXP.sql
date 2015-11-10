SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_4_36_CHILDATTRIBUTES_EXP]  
			/*WITH ENCRYPTION*/ AS  
			SELECT   
				 T.*				  
				,T.[Name]				AS [Member_Name]  
				,T.Code				AS [Member_Code]  
				,NULL AS Parent_Code  
				,NULL AS Parent_Name  
				,NULL AS Parent_HierarchyMuid  
				,NULL AS Parent_HierarchyName  
				,NULL AS Collection_Code  
				,NULL AS Collection_Name  
                ,NULL AS Collection_SortOrder  
                ,NULL AS Collection_Weight  
			FROM   
				mdm.[viw_SYSTEM_4_36_CHILDATTRIBUTES] AS T
GO
