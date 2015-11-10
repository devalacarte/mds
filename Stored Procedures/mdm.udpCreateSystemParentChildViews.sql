SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    EXEC mdm.udpCreateSystemParentChildViews 8;  
    EXEC mdm.udpCreateSystemParentChildViews 31;  
    EXEC mdm.udpCreateSystemParentChildViews 11111; --invalid  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpCreateSystemParentChildViews]   
(  
    @Entity_ID    INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Defer view generation if we are in the middle of an upgrade or demo-rebuild  
    IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock'  
    BEGIN  
        DECLARE @EntityTable            sysname,  
                @HierarchyParentTable   sysname,  
                @HierarchyTable         sysname,  
                @CollectionTable        sysname,  
                @CollectionMemberTable  sysname,  
                @SQL                    NVARCHAR(MAX),  
                @CollectionViewName     sysname,  
                @ViewName               sysname;  
  
        --Initialize the variables  
        SELECT      
                @EntityTable = QUOTENAME(E.EntityTable),  
                @HierarchyParentTable = QUOTENAME(E.HierarchyParentTable),  
                @HierarchyTable = QUOTENAME(E.HierarchyTable),  
                @CollectionTable = QUOTENAME(E.CollectionTable),  
                @CollectionMemberTable = QUOTENAME(E.CollectionMemberTable),  
                @ViewName = QUOTENAME(N'viw_SYSTEM_' + CONVERT(NVARCHAR(30), M.ID) + N'_' + CONVERT(NVARCHAR(30), E.ID) + N'_PARENTCHILD'),  
                @CollectionViewName = QUOTENAME(N'viw_SYSTEM_' + CONVERT(NVARCHAR(30), M.ID) + N'_' + CONVERT(NVARCHAR(30), E.ID) + N'_COLLECTIONPARENTCHILD')  
            FROM mdm.tblEntity E  
            INNER JOIN mdm.tblModel M ON (E.Model_ID = M.ID)  
            WHERE E.ID = @Entity_ID AND E.IsFlat = 0;  
          
        -- Do not create parent child view if entity does not exist  
        IF @@ROWCOUNT = 0  
        BEGIN  
            RETURN;  
        END;  
  
        -- Create PARENTCHILD view  
        SET @SQL = N'  
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
                    ISNULL(HPP.Code,''ROOT'') AS Parent_Code,          
                    ISNULL(HPP.Name,'''') AS Parent_Name,          
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
                mdm.' + @HierarchyTable + N' AS HR  
                -- Changed from INNER JOIN for better performance  
                LEFT JOIN mdm.tblHierarchy H ON H.ID = HR.Hierarchy_ID  
                LEFT JOIN mdm.' + @HierarchyParentTable + N' AS HPP   
                    ON HPP.ID = HR.Parent_HP_ID   
                    AND HPP.Version_ID = HR.Version_ID   
                    AND HPP.Hierarchy_ID = HR.Hierarchy_ID   
                    AND HPP.Status_ID = HR.Status_ID    
                LEFT JOIN mdm.' + @EntityTable + N' AS EN   
                    ON HR.ChildType_ID = 1                   
                    AND HR.Child_EN_ID = EN.ID            
                    AND HR.Version_ID = EN.Version_ID   
                    AND EN.Status_ID = 1  
                LEFT JOIN mdm.' + @HierarchyParentTable + N' AS HPC   
                    ON HR.ChildType_ID = 2                   
                    AND HR.Child_HP_ID = HPC.ID  
                    AND HR.Version_ID = HPC.Version_ID   
                    AND HR.Hierarchy_ID = HPC.Hierarchy_ID   
                    AND HPC.Status_ID = 1  
                WHERE   
                    HR.Status_ID = 1 AND  
                    (EN.ID IS NOT NULL OR HPC.ID IS NOT NULL);';  
  
        SET @SQL = CASE   
                WHEN EXISTS(SELECT 1 FROM sys.views WHERE QUOTENAME([name]) = @ViewName AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER'  
                ELSE N'CREATE' END   
            + N' VIEW mdm.' + @ViewName  
            + @SQL;  
  
        --PRINT(@SQL);  
        EXEC sp_executesql @SQL  
  
        --Create the CollectionParentChild view  
        SET @SQL = N'  
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
                '''' as Hierarchy_Name,  
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
                mdm.' + @CollectionMemberTable + N' AS tCM  
                -- Changed from INNER JOIN for better performance  
                LEFT JOIN  mdm.' + @CollectionTable + N' AS tCNN   
                    ON tCNN.ID = tCM.Parent_CN_ID  
                    AND tCNN.Version_ID = tCM.Version_ID    
                LEFT JOIN mdm.' + @EntityTable + N' AS tEN   
                    ON tCM.ChildType_ID = 1   
                    AND tCM.Child_EN_ID = tEN.ID   
                    AND tCM.Version_ID = tEN.Version_ID   
                    AND tEN.Status_ID = 1    
                LEFT JOIN mdm.' + @HierarchyParentTable + N' AS tHP   
                    ON tCM.ChildType_ID = 2   
                    AND tCM.Child_HP_ID = tHP.ID   
                    AND tCM.Version_ID = tHP.Version_ID   
                    AND tHP.Status_ID = 1    
                LEFT JOIN mdm.' + @CollectionTable + N' AS tCN   
                    ON tCM.ChildType_ID = 3   
                    AND tCM.Child_CN_ID = tCN.ID    
                    AND tCM.Version_ID = tCN.Version_ID   
                    AND tCN.Status_ID = 1    
                WHERE   
                    tCNN.Status_ID = 1 AND -- Collection must be active  
                    tCM.Status_ID = 1 AND -- Collection member must be active  
                    (tEN.ID IS NOT NULL OR tHP.ID IS NOT NULL OR tCN.ID IS NOT NULL);';  
  
        SET @SQL = CASE   
                WHEN EXISTS(SELECT 1 FROM sys.views WHERE QUOTENAME([name]) = @CollectionViewName AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER'  
                ELSE N'CREATE' END   
            + N' VIEW mdm.' + @CollectionViewName   
            + @SQL;  
  
        --PRINT(@SQL);  
        EXEC sp_executesql @SQL  
  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
