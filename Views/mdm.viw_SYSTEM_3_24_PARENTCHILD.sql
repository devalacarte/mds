SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_3_24_PARENTCHILD]  
            AS  
            SELECT       
                    HR.ID as HR_ID,  
                    ISNULL(HR.Parent_HP_ID,0) AS Parent_ID,  
                    HR.ChildType_ID,  
                    HR.Child_EN_ID,  
                    HR.Child_HP_ID,  
                    CASE HR.ChildType_ID WHEN 1 THEN HR.Child_EN_ID WHEN 2 THEN HR.Child_HP_ID END AS Child_ID,  
                    CASE           
                        WHEN HR.ChildType_ID = 1 THEN EN.ValidationStatus_ID          
                        ELSE HPC.ValidationStatus_ID  
                    END AS Child_ValidationStatus_ID,  
                    HR.Version_ID,  
                    HR.Hierarchy_ID,  
                    H.MUID as Hierarchy_MUID,          
                    H.Name as Hierarchy_Name,  
                    ISNULL(HPP.Code,'ROOT') AS Parent_Code,          
                    ISNULL(HPP.Name,'') AS Parent_Name,          
                    CASE            
                        WHEN HR.ChildType_ID = 1 THEN EN.Code           
                        ELSE HPC.Code         
                    END AS Child_Code,         
                    CASE           
                        WHEN HR.ChildType_ID = 1 THEN EN.Name          
                        ELSE HPC.Name         
                    END AS Child_Name,  
                    HR.SortOrder AS Child_SortOrder,  
                    HR.LevelNumber AS Child_LevelNumber  
            FROM  
                mdm.[tbl_3_24_HR] AS HR  
                -- Changed from INNER JOIN for better performance  
                LEFT JOIN mdm.tblHierarchy H ON H.ID = HR.Hierarchy_ID  
                LEFT JOIN mdm.[tbl_3_24_HP] AS HPP   
                    ON HPP.ID = HR.Parent_HP_ID   
                    AND HPP.Version_ID = HR.Version_ID   
                    AND HPP.Hierarchy_ID = HR.Hierarchy_ID   
                    AND HPP.Status_ID = HR.Status_ID    
                LEFT JOIN mdm.[tbl_3_24_EN] AS EN   
                    ON HR.ChildType_ID = 1                   
                    AND HR.Child_EN_ID = EN.ID            
                    AND HR.Version_ID = EN.Version_ID   
                    AND EN.Status_ID = 1  
                LEFT JOIN mdm.[tbl_3_24_HP] AS HPC   
                    ON HR.ChildType_ID = 2                   
                    AND HR.Child_HP_ID = HPC.ID  
                    AND HR.Version_ID = HPC.Version_ID   
                    AND HR.Hierarchy_ID = HPC.Hierarchy_ID   
                    AND HPC.Status_ID = 1  
                WHERE   
                    HR.Status_ID = 1 AND  
                    (EN.ID IS NOT NULL OR HPC.ID IS NOT NULL);
GO
