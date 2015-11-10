SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpCreateParentChildViews ;  
    EXEC mdm.udpCreateParentChildViews 3, 1, 1, null, 'test';  
    EXEC mdm.udpCreateParentChildViews 11111; --invalid  
    EXEC mdm.udpCreateAllViews;  
*/  
CREATE PROCEDURE [mdm].[udpCreateParentChildViews]   
(  
   @Entity_ID			INT,  
   @Model_ID            INT,     
   @Version_ID          INT ,  
   @VersionFlag_ID      INT = NULL,  
   @SubscriptionViewName sysname  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Defer view generation if we are in the middle of an upgrade or demo-rebuild  
    IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
        DECLARE @EntityTable			sysname,  
                @HierarchyParentTable   sysname,  
                @HierarchyTable			sysname,  
                @ViewName				sysname,  
                @SQL					NVARCHAR(MAX);  
          
        --Test for invalid parameters  
        IF (@Model_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModel WHERE ID = @Model_ID)) --Invalid Model_ID  
            OR (@Entity_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblEntity WHERE ID = @Entity_ID)) --Invalid @Entity_ID  
            OR (@Version_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModelVersion WHERE ID = @Version_ID)) -- Invalid @Version_ID  
            OR (@SubscriptionViewName IS NULL)  
        BEGIN  
            RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
            RETURN(1);  
        END; --if  
          
          
        --Initialize the variables	  
        SELECT  
            @EntityTable = E.EntityTable,  
            @HierarchyParentTable = E.HierarchyParentTable,  
            @HierarchyTable = E.HierarchyTable,  
            @ViewName = @SubscriptionViewName  
  
        FROM mdm.tblEntity E  
        INNER JOIN mdm.tblModel M ON (E.Model_ID = M.ID)  
        WHERE E.ID = @Entity_ID   
            AND E.IsFlat = 0  
            AND M.ID = @Model_ID;  
  
        IF @ViewName IS NOT NULL BEGIN --Ensure row actually exists  
  
            SELECT @SQL = N'  
                /*WITH ENCRYPTION*/ AS  
                SELECT  
                    V.Name			AS VersionName,  
                    V.Display_ID	AS VersionNumber,  
                    DV.Name			AS VersionFlag,          
                    H.Name			AS Hierarchy,          
                    ISNULL(HPP.Code, ''ROOT'')	AS ParentCode, --!Should be NULL  
                    ISNULL(HPP.Name, '''')		AS ParentName, --!Should be NULL  
                    CASE            
                       WHEN HR.ChildType_ID = 1 THEN EN.Code           
                       ELSE HPC.Code         
                    END				AS ChildCode,         
                    CASE           
                       WHEN HR.ChildType_ID = 1 THEN EN.Name          
                       ELSE HPC.Name         
                    END				AS ChildName,  
                    HR.SortOrder	AS ChildSortOrder,  
                    HR.LevelNumber	AS ChildLevelNumber,  
                    HR.EnterDTM		AS EnterDateTime  
                    ,(SELECT UserName FROM mdm.tblUser WHERE ID = HR.EnterUserID) AS EnterUserName  
                    ,(SELECT Display_ID FROM mdm.tblModelVersion WHERE ID = HR.EnterVersionID) AS EnterVersionNumber  
                    ,HR.LastChgDTM	AS LastChgDateTime  
                    ,(SELECT UserName FROM mdm.tblUser WHERE ID = HR.LastChgUserID) AS LastChgUserName  
                    ,(SELECT Display_ID FROM mdm.tblModelVersion WHERE ID = HR.LastChgVersionID) AS LastChgVersionNumber  
                FROM  
                    mdm.' + quotename(@HierarchyTable) + N' HR           
                INNER JOIN mdm.tblHierarchy H ON HR.Hierarchy_ID = H.ID          
                INNER JOIN mdm.tblModelVersion V ON HR.Version_ID = V.ID '  
                  
                  
                --Restrict by Version or Version Flag  
                IF (@Version_ID IS NOT NULL)  
                BEGIN   
                    SET @SQL = @SQL + N'   
                        AND V.ID = ' + CAST(@Version_ID AS NVARCHAR(50))   
                END  
                ELSE IF (@VersionFlag_ID IS NOT NULL) BEGIN  
                    SET @SQL = @SQL + N'   
                        AND V.VersionFlag_ID = ' + CAST(@VersionFlag_ID AS NVARCHAR(50))   
                END		  
                  
                SET @SQL = @SQL + N'   
                LEFT JOIN mdm.tblModelVersionFlag AS DV ON DV.ID = V.VersionFlag_ID '  
                  
                  
                SET @SQL = @SQL + N'  
                LEFT JOIN mdm.' + quotename(@HierarchyParentTable) + N' AS HPP   
                    ON HPP.ID = HR.Parent_HP_ID   
                    AND HPP.Version_ID = HR.Version_ID   
                    AND HPP.Hierarchy_ID = HR.Hierarchy_ID   
                    AND HPP.Status_ID = HR.Status_ID    
                LEFT JOIN mdm.' + quotename(@EntityTable) + N' AS EN   
                    ON HR.Child_EN_ID = EN.ID            
                    AND HR.Version_ID = EN.Version_ID   
                    AND HR.ChildType_ID = 1   
                    AND EN.Status_ID = 1   
                LEFT JOIN mdm.' + quotename(@HierarchyParentTable) + N' AS HPC   
                    ON HR.Child_HP_ID = HPC.ID  
                    AND HR.Version_ID = HPC.Version_ID   
                    AND HR.Hierarchy_ID = HPC.Hierarchy_ID   
                    AND HR.ChildType_ID = 2   
                    AND HPC.Status_ID = 1  
                WHERE   
                    (EN.ID IS NOT NULL OR HPC.ID IS NOT NULL);';  
                      
              
  
            SET @SQL = CASE   
                WHEN EXISTS(SELECT 1 FROM sys.views WHERE [name] = @ViewName AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER'  
                ELSE N'CREATE' END + N' VIEW mdm.' + quotename(@ViewName) + N''  
                + @SQL;  
  
            --PRINT @SQL;  
            EXEC sp_executesql @SQL;  
  
        END; --if  
  
    END; --if  
  
    SET NOCOUNT OFF  
END --proc
GO
