SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpCreateDerivedHierarchyParentChildView 1,1,1,1,'TEST';  
    EXEC mdm.udpCreateAllViews;  
*/  
CREATE PROCEDURE [mdm].[udpCreateDerivedHierarchyParentChildView]  
(  
    @DerivedHierarchy_ID	INT,  
    @Model_ID				INT,  
    @Version_ID				INT,  
    @VersionFlag_ID			INT=NULL,  
    @SubscriptionViewName	sysname  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Defer view generation if we are in the middle of an upgrade or demo-rebuild  
    IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
        DECLARE @ViewName 				sysname,  
                @ViewLookupName 		sysname,  
                @SQL					NVARCHAR(MAX);  
                  
        IF  (@Model_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModel WHERE ID = @Model_ID)) --Invalid @Model_ID  
            OR (@DerivedHierarchy_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblDerivedHierarchy WHERE ID = @DerivedHierarchy_ID)) --Invalid @DerivedHierarchy_ID  
            OR (@Version_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModelVersion WHERE ID = @Version_ID)) --Invalid @ModelVersion_ID  
            or (@VersionFlag_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModelVersionFlag WHERE ID = @VersionFlag_ID)) --Invalid @ModelVersionFlag_ID  
            OR (@SubscriptionViewName IS NULL)  
            OR (LEN(@SubscriptionViewName) = 0) --Must enter @SubscriptionViewName  
              
        BEGIN  
            RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
            RETURN(1);  
        END; --if  
      
        SELECT  
            @ViewName = @SubscriptionViewName ,  
            @ViewLookupName = CAST(N'viw_SYSTEM_' + CONVERT(NVARCHAR(30), M.ID) + N'_' + CONVERT(NVARCHAR(30), H.ID) + N'_PARENTCHILD_DERIVED' AS sysname)  
        FROM mdm.tblDerivedHierarchy AS H  
        INNER JOIN mdm.tblModel M ON H.Model_ID = M.ID  
        WHERE H.ID = @DerivedHierarchy_ID  
                AND H.Model_ID = @Model_ID;  
  
        IF @ViewName IS NOT NULL BEGIN --Ensure row actually exists  
  
            --If derived hierarchy structure has actually been defined  
            IF EXISTS(SELECT ID FROM mdm.tblDerivedHierarchyDetail WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID) BEGIN  
  
                SET @SQL = N'  
                    /*WITH ENCRYPTION*/  
                    AS SELECT  
                          
                        V.Name			AS VersionName,  
                        V.Display_ID	AS VersionNumber,  
                        DV.Name			AS VersionFlag,  
                             
                        (SELECT H.[Name]  
                            FROM mdm.tblDerivedHierarchy AS H  
                            INNER JOIN mdm.tblModel M ON H.Model_ID = M.ID  
                            WHERE H.ID = ' + cast(@DerivedHierarchy_ID as nvarchar(25)) + N'  
                            AND H.Model_ID = ' + cast(@Model_ID as nvarchar(25)) + N') AS [Hierarchy],  
                        ChildType_ID,  
                        Child_ID,  
                        ChildCode,  
                        ChildName,  
                        E.ID         AS Child_Entity_ID,      
                        E.Name       AS Child_EntityName,      
                        ParentType_ID,  
                        Parent_ID,  
                        ParentCode,  
                        ParentName,  
                        CASE   
                            WHEN T.ParentItemType_ID = 2 THEN (SELECT Entity_ID FROM mdm.tblHierarchy WHERE ID = T.ParentItem_ID)  
                            WHEN T.ParentItemType_ID = 1 THEN (SELECT DomainEntity_ID from mdm.tblAttribute WHERE ID = T.ParentItem_ID)  
                            ELSE Epar.ID  
                        END AS Parent_Entity_ID,   
  
                        CASE   
                            WHEN T.ParentItemType_ID = 2 THEN (SELECT E.Name FROM mdm.tblEntity E   
                                                                INNER JOIN mdm.tblHierarchy H ON H.Entity_ID = E.ID   
                                                                    AND H.ID = T.ParentItem_ID)  
                            WHEN T.ParentItemType_ID = 1 THEN (SELECT E.Name FROM mdm.tblEntity E   
                                                                INNER JOIN mdm.tblAttribute A ON A.DomainEntity_ID = E.ID  
                                                                    AND A.ID = T.ParentItem_ID)  
                            ELSE Epar.Name  
                        END	AS Parent_EntityName    
                    FROM  
                        mdm.' + quotename(@ViewLookupName) + N' AS T  
                    INNER JOIN mdm.[tblModelVersion] AS V ON V.ID = T.Version_ID '  
                      
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
                    LEFT JOIN mdm.[tblModelVersionFlag] AS DV ON DV.ID = V.VersionFlag_ID '  
                      
                    SET @SQL = @SQL + N'   
                    INNER JOIN mdm.[tblEntity] E ON T.Entity_ID = E.ID '  
  
                    SET @SQL = @SQL + N'  
                    LEFT OUTER JOIN mdm.[tblEntity] Epar on T.ParentItem_ID = Epar.ID;';    
  
                SET @SQL = CASE   
                    WHEN EXISTS(SELECT 1 FROM sys.views WHERE [name] = @ViewName AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER '  
                    ELSE N'CREATE ' END + N'VIEW mdm.' + quotename(@ViewName) + N''  
                    + @SQL;  
  
                --PRINT @SQL;  
                EXEC sp_executesql @SQL;  
  
            END; --if  
  
        END; --if  
  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
