SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_2_12_COLLECTIONPARENTCHILD]  
            AS  
            SELECT  
                tCM.Version_ID,   
                tCNN.Code Parent_Code,   
                tCNN.Name Parent_Name,  
                3 as ParentType_ID,   
                tCNN.ID as Parent_ID,   
                CASE    
                    WHEN tCM.ChildType_ID = 1 THEN tEN.ID  
                    WHEN tCM.ChildType_ID = 2 THEN tHP.ID  
                    WHEN tCM.ChildType_ID = 3 THEN tCN.ID  
                END Member_ID,   
                tCM.ChildType_ID MemberType_ID,   
                CASE    
                    WHEN tCM.ChildType_ID = 1 THEN 0  
                    WHEN tCM.ChildType_ID = 2 THEN tHP.Hierarchy_ID  
                    WHEN tCM.ChildType_ID = 3 THEN tCN.ID  
                END Hierarchy_ID,   
                null as Hierarchy_MUID,          
                '' as Hierarchy_Name,  
                tCM.SortOrder,   
                CASE    
                    WHEN tCM.ChildType_ID = 1 THEN tEN.Code  
                    WHEN tCM.ChildType_ID = 2 THEN tHP.Code  
                    WHEN tCM.ChildType_ID = 3 THEN tCN.Code  
                END Code,   
                CASE    
                    WHEN tCM.ChildType_ID = 1 THEN tEN.Name   
                    WHEN tCM.ChildType_ID = 2 THEN tHP.Name  
                    WHEN tCM.ChildType_ID = 3 THEN tCN.Name   
                END Name,   
                CONVERT(DECIMAL(18, 2), tCM.Weight) AS Weight,   
                tCM.ChildType_ID,   
                tCM.Child_EN_ID,   
                tCM.Child_HP_ID,   
                tCM.Child_CN_ID,  
                CASE tCM.ChildType_ID WHEN 1 THEN tCM.Child_EN_ID WHEN 2 THEN tCM.Child_HP_ID WHEN 3 THEN tCM.Child_CN_ID END AS Child_ID,  
                CASE    
                    WHEN tCM.ChildType_ID = 1 THEN 0  
                    WHEN tCM.ChildType_ID = 2 THEN tHP.Hierarchy_ID  
                    WHEN tCM.ChildType_ID = 3 THEN tCN.ID  
                END NextHierarchy_ID,   
                CASE    
                    WHEN tCM.ChildType_ID = 3 THEN 2  
                    ELSE 0  
                END NextHierarchyType_ID           
            FROM   
                mdm.[tbl_2_12_CM] AS tCM  
                -- Changed from INNER JOIN for better performance  
                LEFT JOIN  mdm.[tbl_2_12_CN] AS tCNN   
                    ON tCNN.ID = tCM.Parent_CN_ID  
                    AND tCNN.Version_ID = tCM.Version_ID    
                LEFT JOIN mdm.[tbl_2_12_EN] AS tEN   
                    ON tCM.ChildType_ID = 1   
                    AND tCM.Child_EN_ID = tEN.ID   
                    AND tCM.Version_ID = tEN.Version_ID   
                    AND tEN.Status_ID = 1    
                LEFT JOIN mdm.[tbl_2_12_HP] AS tHP   
                    ON tCM.ChildType_ID = 2   
                    AND tCM.Child_HP_ID = tHP.ID   
                    AND tCM.Version_ID = tHP.Version_ID   
                    AND tHP.Status_ID = 1    
                LEFT JOIN mdm.[tbl_2_12_CN] AS tCN   
                    ON tCM.ChildType_ID = 3   
                    AND tCM.Child_CN_ID = tCN.ID    
                    AND tCM.Version_ID = tCN.Version_ID   
                    AND tCN.Status_ID = 1    
                WHERE   
                    tCNN.Status_ID = 1 AND -- Collection must be active  
                    tCM.Status_ID = 1 AND -- Collection member must be active  
                    (tEN.ID IS NOT NULL OR tHP.ID IS NOT NULL OR tCN.ID IS NOT NULL);
GO
