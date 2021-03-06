SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_4_34_CHILDATTRIBUTES_EXP]  
			/*WITH ENCRYPTION*/ AS  
			SELECT   
				 T.*				  
				,T.[Name]				AS [Member_Name]  
				,T.Code				AS [Member_Code]  
				,PDL.*  
				,CDL.Parent_Code as Collection_Code  
				,CDL.Parent_Name as Collection_Name  
				,CDL.SortOrder AS Collection_SortOrder  
                ,CDL.[Weight] AS Collection_Weight  
			FROM   
				mdm.[viw_SYSTEM_4_34_CHILDATTRIBUTES] AS T	  
			OUTER APPLY (  
				SELECT   
					Parent_Code			AS [Parent_Code],  
					Parent_Name			AS [Parent_Name],  
					Hierarchy_MUID		AS [Parent_HierarchyMuid],   
					Hierarchy_Name		AS [Parent_HierarchyName],  
					Hierarchy_ID		AS [Parent_HierarchyId],  
					Child_SortOrder     AS [Child_SortOrder]  
				FROM  
					mdm.[viw_SYSTEM_4_34_PARENTCHILD]  
				WHERE   
					Version_ID = T.Version_ID AND   
					T.ID =  Child_EN_ID  AND   
					ChildType_ID = 1  
				--FOR XML PATH (N'Parent'), ELEMENTS, TYPE  
			) AS PDL --PDL(XmlColumn);	  
			LEFT JOIN  
					mdm.[viw_SYSTEM_4_34_COLLECTIONPARENTCHILD] CDL  
					ON   
					CDL.Version_ID = T.Version_ID AND   
					T.ID =  CDL.Child_EN_ID  AND   
					CDL.ChildType_ID = 1  
				
GO
