SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpCreateCollectionViews 1,1,1,1, 'test';  
    EXEC mdm.udpCreateCollectionViews 5111; --invalid  
  
*/  
CREATE PROCEDURE [mdm].[udpCreateCollectionViews]   
(  
    @Entity_ID			 INT,  
    @Model_ID            INT,     
    @Version_ID          INT ,  
    @VersionFlag_ID      INT,  
    @SubscriptionViewName sysname  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Defer view generation if we are in the middle of an upgrade or demo-rebuild  
    IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
        DECLARE @EntityTable  			sysname,  
                @HierarchyParentTable  	sysname,  
                @CollectionTable 		sysname,  
                @CollectionMemberTable	sysname,  
                @SQL					NVARCHAR(MAX),  
                @ViewName				sysname;  
  
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
            @CollectionTable = E.CollectionTable,  
            @CollectionMemberTable = E.CollectionMemberTable,  
            @ViewName = @SubscriptionViewName  
              
        FROM mdm.tblEntity E   
        INNER JOIN mdm.tblModel M ON E.Model_ID = M.ID  
        WHERE E.ID = @Entity_ID   
            AND E.IsFlat = 0  
            AND M.ID = @Model_ID;  
  
        IF @ViewName IS NOT NULL BEGIN --Ensure row actually exists		  
  
            SET @SQL = N'				  
                /*WITH ENCRYPTION*/  
                AS SELECT  
                    V.Name			AS VersionName,  
                    V.Display_ID	AS VersionNumber,  
                    DV.Name			AS VersionFlag,  
                    CN.Code			AS Code,  
                    CN.Name			AS Name,  
                    CASE   
                        WHEN CM.ChildType_ID = 1 THEN E.Code  
                        WHEN CM.ChildType_ID = 2 THEN HP.Code  
                        WHEN CM.ChildType_ID = 3 THEN CN2.Code  
                    END				AS MemberCode,   
                    CASE    
                        WHEN CM.ChildType_ID = 1 THEN E.Name   
                        WHEN CM.ChildType_ID = 2 THEN HP.Name   
                        WHEN CM.ChildType_ID = 3 THEN CN2.Name   
                    END				AS MemberName,  
                    CONVERT(DECIMAL(18,2), CM.Weight) AS Weight,  
                    CM.SortOrder	AS SortOrder,  
                    CN.EnterDTM		AS EnterDateTime  
                    ,(SELECT UserName FROM mdm.tblUser WHERE ID = CN.EnterUserID) AS EnterUserName  
                    ,(SELECT Display_ID FROM mdm.tblModelVersion WHERE ID = CN.EnterVersionID) AS EnterVersionNumber  
                    ,CN.LastChgDTM AS LastChgDateTime  
                    ,(SELECT UserName FROM mdm.tblUser WHERE ID = CN.LastChgUserID) AS LastChgUserName  
                    ,(SELECT Display_ID FROM mdm.tblModelVersion WHERE ID = CN.LastChgVersionID) AS LastChgVersionNumber  
                FROM   
                    mdm.' + quotename(@CollectionTable) + N' AS CN  
                INNER JOIN mdm.' + quotename(@CollectionMemberTable) + N' AS CM   
                    ON CN.ID = CM.Parent_CN_ID  
                    AND CN.Version_ID = CM.Version_ID   
                    AND CN.Status_ID = CM.Status_ID   
                INNER JOIN mdm.tblModelVersion V ON CN.Version_ID = V.ID '  
                  
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
                LEFT JOIN mdm.tblModelVersionFlag AS DV ON DV.ID = V.VersionFlag_ID   
                LEFT JOIN mdm.' + quotename(@EntityTable) + N' AS E   
                    ON CM.Child_EN_ID = E.ID   
                    AND CM.Version_ID = E.Version_ID   
                    AND E.Version_ID = CN.Version_ID  
                    AND CM.Parent_CN_ID = CN.ID  
                    AND CM.ChildType_ID = 1   
                    AND E.Status_ID = 1    
                LEFT JOIN mdm.' + quotename(@HierarchyParentTable) + N' AS HP   
                    ON CM.Child_HP_ID = HP.ID   
                    AND CM.Version_ID = HP.Version_ID   
                    AND HP.Version_ID = CN.Version_ID  
                    AND CM.Parent_CN_ID = CN.ID   
                    AND CM.ChildType_ID = 2   
                    AND HP.Status_ID = 1  
                LEFT JOIN mdm.' + quotename(@CollectionTable) + N' AS CN2   
                    ON CM.Child_CN_ID = CN2.ID    
                    AND CM.Version_ID = CN2.Version_ID   
                    AND CN2.Version_ID = CN.Version_ID   
                    AND CM.Parent_CN_ID = CN.ID   
                    AND CM.ChildType_ID = 3   
                    AND CN2.Status_ID = 1  
                WHERE   
                    CN.Status_ID = 1   
                    AND (E.ID IS NOT NULL OR HP.ID IS NOT NULL OR CN2.ID IS NOT NULL);';  
              
              
              
            SET @SQL = CASE   
                WHEN EXISTS(SELECT 1 FROM sys.views WHERE [name] = @ViewName AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER'  
                ELSE N'CREATE' END + N' VIEW mdm.' + quotename(@ViewName)  
                + @SQL;  
  
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL;  
  
        END; --if  
  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
