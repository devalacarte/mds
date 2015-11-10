SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_3_24_COLLECTIONATTRIBUTES_EXP]  
			/*WITH ENCRYPTION*/ AS  
			SELECT   
				 T.*				  
				,T.[Name]				AS [Member_Name]  
				,T.Code				AS [Member_Code]  
				,NULL AS Parent_Code  
				,NULL AS Parent_Name  
				,NULL AS Parent_HierarchyMuid  
				,NULL AS Parent_HierarchyName  
				,CDL.Parent_Code AS Collection_Code  
				,CDL.Parent_Name AS Collection_Name  
                ,CDL.SortOrder AS Collection_SortOrder  
                ,CDL.[Weight] AS Collection_Weight  
			FROM   
				mdm.[viw_SYSTEM_3_24_COLLECTIONATTRIBUTES] AS T	  
			LEFT JOIN  
					mdm.[viw_SYSTEM_3_24_COLLECTIONPARENTCHILD] CDL  
					ON   
					CDL.Version_ID = T.Version_ID AND   
					T.ID =  CDL.Child_CN_ID  AND   
					CDL.ChildType_ID = 3  
				
GO
