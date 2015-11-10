SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpCreateDerivedHierarchyLevelView 1,1,1,1,NULL,' TEST';  
      
*/  
 CREATE PROCEDURE [mdm].[udpCreateDerivedHierarchyLevelView]    
 (  
    @DerivedHierarchy_ID INT,   
    @Levels INT,   
    @Model_ID INT,   
    @Version_ID INT,   
    @VersionFlag_ID INT=NULL,   
    @SubscriptionViewName [sysname]    
 )  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN   
    
    SET NOCOUNT ON;    
    
    --Defer view generation if we are in the middle of an upgrade or demo-rebuild    
    IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN    
    
        DECLARE @ViewName 						sysname,    
                @EntitySQL						NVARCHAR(MAX),  
                @SQL							NVARCHAR(MAX),  
                @From							NVARCHAR(MAX),  
                @Where							NVARCHAR(MAX),  
                @ColumnList						NVARCHAR(MAX),  
                @LeafID							NVARCHAR(MAX),  
                @LeafName						NVARCHAR(MAX),  
                @LeafCode						NVARCHAR(MAX),  
                @ColumnListSelect				NVARCHAR(MAX),  
                @e								NVARCHAR(200),  
                @ColumnName						NVARCHAR(500),  
                @PriorColumnName				NVARCHAR(500),				  
                @TempLookupViewName				NVARCHAR(500),  
                @HierarchyName					NVARCHAR(50),  
                @VersionName					NVARCHAR(50),  
                @VersionNumber					NVARCHAR(50),  
                @VersionFlagName				NVARCHAR(50),  
                @EntityName						NVARCHAR(50),  
                @LeafEntityName					NVARCHAR(50),  
                @LeafEntityIDString             NVARCHAR(50),        
                @ColumnAlias					NVARCHAR(50),  
                @HierarchyItemType_Hierarchy	INT,  
                @ColumnCounter					INT,  
                @LeafCounter					INT,  
                @LeafCounterString				NVARCHAR(3),  
                @HierarchyCounter				INT,  
                @MaxLevel						INT,  
                @HierarchyLevels				INT,  
                @IsBasicDerivedHierarchy		BIT;  
                  
        --Initialize the variables    
        SELECT     
            @ViewName = @SubscriptionViewName,   
            @HierarchyName = H.Name,  
            @EntitySQL = CAST(N'' AS NVARCHAR(max)),    
            @SQL = CAST(N'' AS NVARCHAR(max)),    
            @From = CAST(N'' AS NVARCHAR(max)),   
            @Where = CAST(N'' AS NVARCHAR(max)),  
            @LeafID = CAST(N'' AS NVARCHAR(max)),  
            @LeafName = CAST(N'' AS NVARCHAR(max)),  
            @LeafCode = CAST(N'' AS NVARCHAR(max)),  
            @TempLookupViewName = N'viw_SYSTEM_' + CAST(M.ID AS NVARCHAR(30)) + N'_' + CAST(H.ID AS NVARCHAR(30)) + N'_PARENTCHILD_DERIVED',  
            @ColumnList	= CAST(N'' AS NVARCHAR(max)),  
            @ColumnListSelect= CAST(N'' AS NVARCHAR(max)),  
            @ColumnName = CAST(N'' AS NVARCHAR(500)),  
            @PriorColumnName = CAST(N'' AS NVARCHAR(500)),  
            @e = OBJECT_NAME(@@PROCID),  
            @HierarchyItemType_Hierarchy = 2,  
            @MaxLevel = 99,  
            @HierarchyLevels = 1,  
            @IsBasicDerivedHierarchy = 1  
        FROM mdm.tblDerivedHierarchy H    
        INNER JOIN mdm.tblModel M ON H.Model_ID = M.ID    
        WHERE H.ID = @DerivedHierarchy_ID    
            AND H.Model_ID = @Model_ID;   
          
        SET @VersionName	 = CAST(N'' AS NVARCHAR(500))  
        SET @VersionNumber	 = CAST(N'' AS NVARCHAR(500))  
        SET @VersionFlagName = CAST(N'' AS NVARCHAR(500))  
         
        --Validate @Model_ID    
        IF (@Model_ID IS NULL OR @Model_ID = 0 OR  
            NOT EXISTS (SELECT 1 FROM mdm.tblDerivedHierarchy WHERE Model_ID = @Model_ID))  
        BEGIN    
            RAISERROR('MDSERR100011|The Model ID is not valid.', 16, 1);  
            RETURN;          
        END;    
          
        --Validate @DerivedHierarchy_ID    
        IF (@DerivedHierarchy_ID IS NULL OR @DerivedHierarchy_ID = 0 OR  
            NOT EXISTS (SELECT 1 FROM mdm.tblDerivedHierarchy WHERE ID = @DerivedHierarchy_ID))  
        BEGIN    
            RAISERROR('MDSERR100006|The DerivedHierarchy ID is not valid.', 16, 1);  
            RETURN;   
        END;    
        
        IF @ViewName IS NOT NULL BEGIN --Ensure row actually exists    
          
            --Start transaction, being careful to check if we are nested    
            DECLARE @TranCounter INT;     
            SET @TranCounter = @@TRANCOUNT;    
            IF @TranCounter > 0 SAVE TRANSACTION TX;    
            ELSE BEGIN TRANSACTION;    
            
            BEGIN TRY    
    
                -- Check if we have a specialized hierarchy - e.g recursive or explicit cap  
                IF EXISTS ( --test for recursive query  
                            SELECT 1   
                            FROM mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS  
                            WHERE   Hierarchy_ID = @DerivedHierarchy_ID  
                                AND IsRecursive = 1  
                            --Test for explicit cap  
                            UNION ALL  
                            SELECT 1   
                            FROM mdm.tblDerivedHierarchyDetail HD2  
                            WHERE HD2.ForeignType_ID = @HierarchyItemType_Hierarchy  
                                AND HD2.DerivedHierarchy_ID = @DerivedHierarchy_ID)   
                                  
                    SET @IsBasicDerivedHierarchy = 0;  
                      
                    -- Limit the columns for the view to 99 ( Applies to Specialized Hierarchies only)  
                    IF @Levels > @MaxLevel SET @Levels = @MaxLevel;  
  
                    SET @ColumnListSelect = N'  
                            L0.Child_ID AS [[@ColumnAlias]_ID],  
                            L0.ChildCode AS [[@ColumnAlias]_Code],  
                            L0.ChildName AS [[@ColumnAlias]_Name],';  
                      
                    IF (@IsBasicDerivedHierarchy = 0) BEGIN  
                            SET  @ColumnListSelect = N'  
                            L0.ChildType_ID AS [[@ColumnAlias]_Type_ID],  
                            L0.Entity_ID AS [[@ColumnAlias]_Entity_ID],' + @ColumnListSelect;  
                    END --IF  
                              
                    IF (@IsBasicDerivedHierarchy = 1) BEGIN          
                            -- Get the Entity Name for Top Level ParentCode = 'ROOT'  
							SELECT TOP 1  
								@EntityName = CASE WHEN dhd.ForeignType_ID = 0 THEN e.Name ELSE e2.Name END,  
								@HierarchyCounter = dhd.Level_ID  
							FROM mdm.tblDerivedHierarchyDetail dhd   
								LEFT JOIN mdm.tblEntity e ON dhd.Foreign_ID = e.ID  
								LEFT JOIN mdm.tblAttribute a ON dhd.Foreign_ID = a.ID  
								LEFT JOIN mdm.tblEntity e2 ON a.DomainEntity_ID = e2.ID  
							WHERE  
								dhd.DerivedHierarchy_ID = @DerivedHierarchy_ID AND  
								dhd.IsVisible = 1  
							ORDER BY dhd.Level_ID DESC;  
                              
                            -- Get the maximum visible levels in the Hierarchy  
                            SELECT @HierarchyLevels = COUNT(Level_ID)  
                            FROM mdm.tblDerivedHierarchyDetail D  
                            WHERE D.DerivedHierarchy_ID = @DerivedHierarchy_ID AND  
                                D.IsVisible = 1;  
                          
                            SET @ColumnListSelect = REPLACE(@ColumnListSelect, N'[@ColumnAlias]', @EntityName);  
                              
                            -- Limit the columns for the view to the maximum visible level in the basic hierarchy  
                            IF @Levels > @HierarchyLevels SET @Levels = @HierarchyLevels;  
                              
                    END;  
                    ELSE BEGIN  
                        SET @ColumnListSelect = REPLACE(@ColumnListSelect, N'[@ColumnAlias]', 'L0');  
                    END;  
                      
                    SET @From = N'   
                        FROM mdm.' + @TempLookupViewName + N' L0  
                        INNER JOIN mdm.tblModelVersion AS V ON V.ID = L0.Version_ID						  
                         LEFT JOIN mdm.tblModelVersionFlag AS VF on VF.ID = V.VersionFlag_ID'					  
                                          
                    SET @Where = N'   
                        WHERE L0.ParentCode = ''ROOT''   
                          AND L0.Version_ID = ';  
                            --Restrict by Version or Version Flag  
                      
                    IF (@VersionFlag_ID IS NOT NULL) BEGIN  
                        SET @Where = @Where + N'   
                             [mdm].[udfModelVersionIDGetbyFlagID](' + CAST(@VersionFlag_ID AS NVARCHAR(50)) + N')'  
                    END	  
                    ELSE IF (@Version_ID IS NOT NULL)  
                    BEGIN   
                        SET @Where = @Where + CAST(@Version_ID AS NVARCHAR(50))   
                    END  
                      
                    SET @ColumnCounter = 1;  
          
                    -- Loop through the levels to build the columns   
                    WHILE @ColumnCounter < @Levels BEGIN  
                        SET @ColumnName = CAST( @ColumnCounter AS NVARCHAR(30));  
                        SET @PriorColumnName = CAST( (@ColumnCounter - 1) AS NVARCHAR(30));  
                        IF (@IsBasicDerivedHierarchy = 0) BEGIN-- Add ID for base entities.  
                             --only need for non standard derived hierarchies  
                            SET  @ColumnListSelect =  @ColumnListSelect + N'  
                            L[@ColumnName].ChildType_ID AS [[@ColumnAlias]_Type_ID],  
                            L[@ColumnName].Entity_ID AS [[@ColumnAlias]_Entity_ID],';  
                        END  
                            --all drived hierarchies have these columns  
                            SET @ColumnListSelect = @ColumnListSelect + N'  
                            L[@ColumnName].Child_ID AS [[@ColumnAlias]_ID],  
                            L[@ColumnName].ChildCode AS [[@ColumnAlias]_Code],  
                            L[@ColumnName].ChildName AS [[@ColumnAlias]_Name],';  
                      
                        SET @ColumnListSelect = Replace(@ColumnListSelect, '[@ColumnName]', @ColumnName);  
                          
                        IF (@IsBasicDerivedHierarchy = 1) BEGIN  
  
                            SET @EntityName = NULL;  
                              
                            ---- Try to get the Entity Name for the current levels if it is visible  
							SELECT TOP 1  
								@EntityName = CASE WHEN dhd.ForeignType_ID = 0 THEN e.Name ELSE e2.Name END,  
								@HierarchyCounter = dhd.Level_ID  
							FROM mdm.tblDerivedHierarchyDetail dhd   
								LEFT JOIN mdm.tblEntity e ON dhd.Foreign_ID = e.ID  
								LEFT JOIN mdm.tblAttribute a ON dhd.Foreign_ID = a.ID  
								LEFT JOIN mdm.tblEntity e2 ON a.DomainEntity_ID = e2.ID  
							WHERE  
								dhd.DerivedHierarchy_ID = @DerivedHierarchy_ID AND  
								dhd.IsVisible = 1 AND  
								dhd.Level_ID < @HierarchyCounter  
							ORDER BY dhd.Level_ID DESC;  
  
                            SET @ColumnListSelect = REPLACE(@ColumnListSelect, N'[@ColumnAlias]', @EntityName);  
                                                          
                        END;  
                        ELSE BEGIN  
                            SET @ColumnListSelect = REPLACE(@ColumnListSelect, N'[@ColumnAlias]', N'L' + @ColumnName);  
                        END;  
                  
                        SET @From = @From + N'   
                            LEFT OUTER JOIN mdm.' + @TempLookupViewName + ' L[@ColumnName]  
                                        ON  L[@ColumnName].Parent_ID = L[@PriorColumnName].Child_ID AND  
                                            L[@ColumnName].ParentCode = L[@PriorColumnName].ChildCode AND  
                                            (L[@ColumnName].ParentEntity_ID = L[@PriorColumnName].Entity_ID OR  
                                            L[@ColumnName].Entity_ID = L[@PriorColumnName].NextEntity_ID) AND   
                                            L[@ColumnName].Version_ID = '	   
                                              
                        IF @VersionFlag_ID IS NULL BEGIN  
                            SET @From = @From +  CAST(@Version_ID AS NVARCHAR(30));		  
                        END  
                        ELSE BEGIN  
                            SET @From = @From + N'[mdm].[udfModelVersionIDGetbyFlagID](' + CAST(@VersionFlag_ID AS NVARCHAR(30)) + ')'				  
                        END					  
                        SET	@From = REPLACE(REPLACE(@From, 	'[@ColumnName]', @ColumnName), '[@PriorColumnName]', @PriorColumnName);  
                  
                        SET @ColumnCounter = @ColumnCounter + 1;  
                          
                    END;    
                    -- Remove the last comma  
                    SET @ColumnListSelect = SUBSTRING(@ColumnListSelect, 0, LEN(@ColumnListSelect));  
                      
                    --If this is a derived RECURSIVE or EXPLICIT CAP then add the EntityName_ID etc for leaf entities...  
                    IF @IsBasicDerivedHierarchy = 0 BEGIN  
                        SELECT @LeafEntityName = e.Name, @LeafEntityIDString = CAST(e.ID AS NVARCHAR(50))  
                        FROM mdm.tblEntity e  
                        INNER JOIN mdm.tblDerivedHierarchyDetail hd ON hd.Foreign_ID = e.ID  
                        WHERE hd.DerivedHierarchy_ID = @DerivedHierarchy_ID  
                          AND hd.Level_ID = 1;  
                            
                        SET @LeafID = N'  
                            COALESCE(NULL,';  
                        SET	@LeafCode = @LeafID;  
                        SET @LeafName = @LeafID;  
                          
                        SET @LeafCounter = @Levels - 1;  
                        WHILE @LeafCounter>= 0 BEGIN  
                            SET @LeafCounterString = CONVERT(NVARCHAR(3),@LeafCounter);  
                            SET @LeafID += N'CASE WHEN L' + @LeafCounterString + N'.ChildType_ID = 1 AND L' + @LeafCounterString + N'.Entity_ID = ' + @LeafEntityIDString +	N' THEN L' + @LeafCounterString + N'.Child_ID ELSE NULL END'  
                            SET @LeafCode += N'CASE WHEN L' + @LeafCounterString + N'.ChildType_ID = 1 AND L' + @LeafCounterString + N'.Entity_ID = ' + @LeafEntityIDString +	N' 	THEN L' + @LeafCounterString + N'.ChildCode ELSE NULL END'  
                            SET @LeafName += N'CASE WHEN L' + @LeafCounterString + N'.ChildType_ID = 1 AND L' + @LeafCounterString + N'.Entity_ID = ' + @LeafEntityIDString +	N' 	THEN L' + @LeafCounterString + N'.ChildName ELSE NULL END'  
                            IF @LeafCounter <> 0 BEGIN  
                                SET @LeafID += N'  
                                       ,';  
                                SET @LeafCode += N'  
                                       ,';  
                                SET @LeafName += N'  
                                       ,';  
                            END;  
                              
                            SET @LeafCounter = @LeafCounter - 1;  
                        END;  
                        SET @LeafID += N') AS [' + @LeafEntityName + N'_ID],'  
                        SET @LeafCode += N') AS [' + @LeafEntityName + N'_Code],'  
                        SET @LeafName += N') AS [' + @LeafEntityName + N'_Name],'  
                              
                        SET @ColumnListSelect = @LeafID + @LeafCode + @LeafName + @ColumnListSelect;  
                        -- PRINT @ColumnListSelect;  
                    END;   
                    -- Build the SQL for the view data  
                    SELECT @SQL = N'SELECT V.Name AS VersionName,  
                                        V.Display_ID AS VersionNumber,   
                                        VF.Name AS VersionFlag,   
                                N''' +  @HierarchyName + N''' AS Hierarchy,   
                                N''ROOT'' AS [ROOT], ' +  
                                @ColumnListSelect +   
                                @From +  
                                @Where  
                              
                    SET @SQL = CASE   
                        WHEN EXISTS(SELECT 1 FROM sys.views WHERE [name] = @ViewName AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER '  
                        ELSE N'CREATE ' END + N'VIEW mdm.' + quotename(@ViewName) + N'  
                        AS '  
                        + @SQL;  
                          
                    -- PRINT @SQL;	  
                    EXEC sp_executesql @SQL;  
                      
                    --Commit only if we are not nested    
                    IF @TranCounter = 0 COMMIT TRANSACTION;    
    
            END TRY     
            --Compensate as necessary    
            BEGIN CATCH    
            
                -- Get error info  
                DECLARE  
                    @ErrorMessage NVARCHAR(4000),  
                    @ErrorSeverity INT,  
                    @ErrorState INT;  
                EXEC mdm.udpGetErrorInfo  
                    @ErrorMessage = @ErrorMessage OUTPUT,  
                    @ErrorSeverity = @ErrorSeverity OUTPUT,  
                    @ErrorState = @ErrorState OUTPUT;  
                  
                IF @TranCounter = 0 ROLLBACK TRANSACTION;    
                ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;    
            
                RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);    
            
            END CATCH;    
                          
        END;  
    END;    
    SET NOCOUNT OFF;    
END --proc
GO
