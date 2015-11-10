SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*	  
    EXEC mdm.udpCreateSystemDerivedHierarchyParentChildView 1;  
    EXEC mdm.udpCreateSystemDerivedHierarchyParentChildView 2;  
    EXEC mdm.udpCreateSystemDerivedHierarchyParentChildView 5;  
    EXEC mdm.udpCreateSystemDerivedHierarchyParentChildView 10;  
    EXEC mdm.udpCreateSystemDerivedHierarchyParentChildView 11111; --invalid  
    EXEC mdm.udpCreateAllViews;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpCreateSystemDerivedHierarchyParentChildView]  
(  
    @DerivedHierarchy_ID	INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Defer view generation if we are in the middle of an upgrade or demo-rebuild  
    IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
        DECLARE @ViewName 						sysname,			  
                @Select							NVARCHAR(MAX),  
                @From							NVARCHAR(MAX),  
                @TempItem_ID 					INT,  
                @TempSubItem_ID 				INT,    
                @TempItem_MUID 					uniqueIdentifier,  
                @TempLookupPriorEntity_ID       INT,  
                @TempLookupPriorEntity_MUID		uniqueidentifier,  
                @TempItemType_ID 				INT,  
                @TempSubItemType_ID 			INT,  
                @TempNextItem_ID				INT,  
                @TempNextItem_ID_Clause			NVARCHAR(MAX),  --injection safe.  Only INT values appended into CASE statement  
                @TempNextItemType_ID			INT,  
                @TempNextItemType_ID_Clause		NVARCHAR(MAX),  --injection safe.  Only INT values appended into CASE statement  
                @TempLookupNextItem_ID 			INT,  
                @TempLookupNextItemType_ID 		INT,  
                @TempLookupEntity_ID 			INT,  
                @TempLookupViewName 			sysname,  
                @TempLookupSubViewName 			sysname,  
                @TempLookupPriorViewName 		sysname,  
                @TempLookupPriorSubViewName 	sysname,  
                @TempLookupPriorVisibleViewName sysname,  
                @TempLookupAttributeName 		NVARCHAR(50),  
                @TempLookupSubAttributeName 	NVARCHAR(50),  
                @TempTotalCounter				INT,  
                @TempCounter					INT,  
                @TempSubCounter					INT,  
                @TempLookupPriorItemType_ID 	INT,  
                @TempLookupPriorItem_ID			INT,  
                @TempLookupPriorAttributeName 	NVARCHAR(50),  
                @MaxLevel_ID					INT,  
                @TopLevel_ID					INT,  
                @BottomLevel_ID					INT,  
                @CurrentLevel_ID				INT,  
                @PriorLevel_ID					INT,  
                @NextLevel_ID					INT,  
                @TempLookupIsVisible 			BIT,  
                @IsRecursive					BIT,  
                @PriorIsRecursive				BIT,  
                @TempNextEntity_ID_Clause 		NVARCHAR(MAX),  
                @ChildTypeID_Clause				NVARCHAR(MAX),  
                @ParentType_ID					INT,  
                @HierarchyItemType_DBA          INT,  
                @TempAttributeEntity_ID			NVARCHAR(1000),  
                @TempLookupEntity_MUID			uniqueidentifier,  
                @TempNextEntity_MUID_Clause		NVARCHAR(MAX),  
                @TempSortColumn 				sysname,  
                @LookupID                       INT,  
                @AnchorNullRecursions			BIT;  
                                  
        SELECT   
            @ViewName = CAST(N'viw_SYSTEM_' + CONVERT(NVARCHAR(30), M.ID) + N'_' + CONVERT(NVARCHAR(30), H.ID) + N'_PARENTCHILD_DERIVED' AS sysname),  
            @TempCounter = 0,  
            @TempLookupPriorViewName = CAST(N'' AS sysname),  
            @Select = CAST(N'' AS NVARCHAR(max)),  
            @From = CAST(N'' AS NVARCHAR(max)),  
            @ChildTypeID_Clause = CAST(N'' AS NVARCHAR(1000)),  
            @ParentType_ID = NULL,  
            @HierarchyItemType_DBA = 1,  
            @AnchorNullRecursions =  H.AnchorNullRecursions  
        FROM mdm.tblDerivedHierarchy H  
        INNER JOIN mdm.tblModel M ON H.Model_ID = M.ID  
        WHERE H.ID = @DerivedHierarchy_ID;  
  
        IF @ViewName IS NOT NULL BEGIN --Ensure row actually exists  
  
            DECLARE @TempTable		TABLE (  
                Item_ID INT NOT NULL  
                ,ItemType_ID INT NOT NULL  
                ,Level_ID INT NOT NULL  
                ,IsVisible BIT NOT NULL  
                ,SortOrder INT NOT NULL);  
              
            DECLARE @TempSubTable	TABLE (  
                Item_ID INT NOT NULL  
                ,ItemType_ID INT NOT NULL  
                ,Level_ID INT NOT NULL);  
  
            --Loop Through All Levels in DH and Create Union Statements for each Levels  
            INSERT INTO @TempTable   
            SELECT Foreign_ID,ForeignType_ID,Level_ID,IsVisible,SortOrder   
            FROM mdm.tblDerivedHierarchyDetail   
            WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID   
            ORDER BY Level_ID DESC;  
  
            SELECT @TempTotalCounter = COUNT(*) FROM @TempTable;  
            SELECT @MaxLevel_ID = MAX(Level_ID) FROM @TempTable WHERE IsVisible = 1;  
            SELECT @TopLevel_ID = MAX(Level_ID) FROM @TempTable  
            SELECT @BottomLevel_ID = MIN(Level_ID) FROM @TempTable  
  
            --Check to make sure the TopMost or the BottomMost levels are NOT Invisible,   
            --if so Exit and do not as this means the DerivedHierarchy was not setup properly  
            --An error is not thrown as this sproc is called for all derivedhierarchies and it should continue so it will print a message out instead..  
            IF ((SELECT IsVisible FROM @TempTable WHERE Level_ID =@TopLevel_ID) =0 OR (SELECT IsVisible FROM @TempTable WHERE Level_ID =@BottomLevel_ID)=0)   
            BEGIN  
                PRINT @ViewName + ' will not be created due to invalid invisible levels'   
                RETURN 0;  
            END  
                  
  
            --If derived hierarchy structure has actually been defined  
            IF (@TempTotalCounter > 0) BEGIN   
                WHILE EXISTS(SELECT Item_ID FROM @TempTable) BEGIN  
                    SELECT @TempCounter = @TempCounter + 1;  
                    SET @IsRecursive = 0;  
  
                    --Get ID's  
                    SELECT TOP 1   
                        @TempItem_ID = Item_ID,  
                        @TempItemType_ID = ItemType_ID   
                    FROM @TempTable WHERE IsVisible = 1  
                    ORDER BY Level_ID DESC;  
  
                    SET @TempLookupEntity_ID = CASE  
                        WHEN @TempItemType_ID = 3 THEN @TempItem_ID  
                        WHEN @TempItemType_ID = 2 THEN (SELECT Entity_ID FROM mdm.tblHierarchy WHERE ID = @TempItem_ID)  
                        WHEN @TempItemType_ID = 1 THEN (SELECT DomainEntity_ID FROM mdm.tblAttribute WHERE ID = @TempItem_ID)  
                        WHEN @TempItemType_ID = 0 THEN @TempItem_ID  
                    END; --case  
                    SELECT @TempLookupEntity_MUID = MUID FROM mdm.tblEntity WHERE ID=@TempLookupEntity_ID;  
                      
                    -- Check to see if the level is recursive.  
                    IF ((SELECT Entity_ID FROM mdm.tblAttribute WHERE ID = @TempItem_ID) = @TempLookupEntity_ID)  
                    BEGIN     
                        SET @IsRecursive = 1    
                    END  
  
                    --Get the Item_MUID  
                    SET @TempItem_MUID = CASE  
                        WHEN @TempItemType_ID = 3 THEN @TempLookupEntity_MUID  
                        WHEN @TempItemType_ID = 2 THEN (SELECT MUID FROM mdm.tblHierarchy WHERE ID = @TempItem_ID)  
                        WHEN @TempItemType_ID = 1 THEN (SELECT MUID FROM mdm.tblAttribute WHERE ID = @TempItem_ID)  
                        WHEN @TempItemType_ID = 0 THEN @TempLookupEntity_MUID  
                    END; --case  
                      
                    --Get Lookup ViewName  
                    SET @TempLookupViewName = CASE  
                        WHEN @TempItemType_ID = 3 THEN mdm.udfViewNameGetByID(@TempLookupEntity_ID,2,0)	  
                        WHEN @TempItemType_ID = 2 THEN mdm.udfViewNameGetByID(@TempLookupEntity_ID,4,0)	  
                        WHEN @TempItemType_ID = 1 THEN mdm.udfViewNameGetByID(@TempLookupEntity_ID,1,0)	  
                        WHEN @TempItemType_ID = 0 THEN mdm.udfViewNameGetByID(@TempLookupEntity_ID,1,0)	  
                    END; --case  
  
                    --Get Current and Prior Visible Level  
                    -- Always use an ORDER BY when selecting TOP  
                    SELECT TOP 1   
                        @CurrentLevel_ID = Level_ID,  
                        @TempLookupIsVisible = IsVisible   
                    FROM @TempTable WHERE IsVisible = 1  
                    ORDER BY Level_ID DESC;  
  
                    -- Always use an ORDER BY when selecting TOP  
                    SELECT TOP 1 @PriorLevel_ID = Level_ID   
                    FROM mdm.tblDerivedHierarchyDetail   
                    WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID AND Level_ID > @CurrentLevel_ID AND IsVisible = 1   
                    ORDER BY Level_ID ASC;  
  
                    -- Always use an ORDER BY when selecting TOP  
                    SELECT TOP 1 @NextLevel_ID = Level_ID   
                    FROM mdm.tblDerivedHierarchyDetail   
                    WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID AND Level_ID < @CurrentLevel_ID AND IsVisible = 1   
                    ORDER BY Level_ID DESC;  
                    SET @NextLevel_ID = ISNULL(@NextLevel_ID, -1);  
  
                    IF @TempItemType_ID = 2 BEGIN  
                        -- Get the next item type\id from the next visible level.  
                        SELECT TOP 1   
                            @TempNextItem_ID = Item_ID,   
                            @TempNextItemType_ID = ItemType_ID   
                        FROM @TempTable   
                        WHERE Level_ID < @NextLevel_ID AND IsVisible = 1   
                        ORDER BY Level_ID DESC  
                          
                        SET @TempNextItem_ID = ISNULL(@TempNextItem_ID, -1);    
                        SET @TempNextItemType_ID = ISNULL(@TempNextItemType_ID, -1);    
                        SET @TempSortColumn = CAST(N' CONVERT(SQL_VARIANT,T.Child_SortOrder)' AS NVARCHAR(128));  
                    END ELSE BEGIN  
                        SET @TempNextItem_ID = ISNULL((SELECT Item_ID FROM @TempTable WHERE Level_ID = @NextLevel_ID), -1);  
                        SET @TempNextItemType_ID = ISNULL((SELECT ItemType_ID FROM @TempTable WHERE Level_ID = @NextLevel_ID), -1);  
                        SET @TempSortColumn = CAST(N' T.Code'  AS NVARCHAR(128));  
                    END; --if  
  
                      
                    --Get Attribtue DBA Column Name	  
                    IF @TempNextItemType_ID = 2 BEGIN  
                        --SELECT @TempLookupAttributeName = 'Child_Code'  
                        SET @TempLookupAttributeName = (SELECT [Name] FROM mdm.tblAttribute WHERE ID = @TempItem_ID);  
                    END ELSE BEGIN  
                        SET @TempLookupAttributeName = (SELECT [Name] FROM mdm.tblAttribute WHERE ID = @TempItem_ID);  
                    END; --if  
                      
                    --Get NextEntity_ID   
                    IF @TempItemType_ID = 2 AND (@TempNextItemType_ID = 3 OR @TempNextItemType_ID = 0) BEGIN  
                        SET @TempNextEntity_ID_Clause = CAST(N'  
                            CASE   
                                WHEN ChildType_ID = 1 THEN ' + CONVERT(NVARCHAR(30), @TempNextItem_ID) + N'  
                                WHEN ChildType_ID = 2 THEN (SELECT Entity_ID FROM mdm.tblHierarchy WHERE ID = ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N')   
                            END '  AS NVARCHAR(1000));  
                        SET @TempNextEntity_MUID_Clause = N'  
                            CASE   
                                WHEN ChildType_ID = 1 THEN ''' + (SELECT CONVERT(NVARCHAR(36),MUID) FROM mdm.tblEntity WHERE ID=@TempNextItem_ID) + '''  
                                WHEN ChildType_ID = 2 THEN (SELECT CONVERT(NVARCHAR(36),MUID) FROM mdm.tblEntity WHERE ID=(SELECT Entity_ID FROM mdm.tblHierarchy WHERE ID = ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N'))  
                            END ';				  
                    END	ELSE IF @TempItemType_ID = 2 AND @TempNextItemType_ID = 1 BEGIN  
                        SET @TempNextEntity_ID_Clause = CAST(N'  
                            CASE   
                                WHEN ChildType_ID = 1 THEN ISNULL((SELECT DomainEntity_ID FROM mdm.tblAttribute WHERE ID = ' + CONVERT(NVARCHAR(30), @TempNextItem_ID) + N'), -1)   
                                WHEN ChildType_ID = 2 THEN (SELECT Entity_ID FROM mdm.tblHierarchy WHERE ID = ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N')   
                            END ' AS NVARCHAR(1000));  
                        SET @TempNextEntity_MUID_Clause = CAST(N'  
                            CASE   
                                WHEN ChildType_ID = 1 THEN ISNULL((SELECT CONVERT(NVARCHAR(36),MUID) FROM mdm.tblEntity WHERE ID=(SELECT DomainEntity_ID FROM mdm.tblAttribute WHERE ID = ' + CONVERT(NVARCHAR(30), @TempNextItem_ID) + N')), -1)   
                                WHEN ChildType_ID = 2 THEN (SELECT CONVERT(NVARCHAR(36),MUID) FROM mdm.tblEntity WHERE ID=(SELECT Entity_ID FROM mdm.tblHierarchy WHERE ID = ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N'))  
                            END ' AS NVARCHAR(1000));  
                    END ELSE BEGIN  
                        IF @TempNextItemType_ID = 3 BEGIN  
                            SET @TempNextEntity_ID_Clause = CAST(@TempNextItem_ID AS NVARCHAR(1000));  
                            SELECT @TempNextEntity_MUID_Clause = CAST(N'''' + CONVERT(NVARCHAR(36), MUID) + N'''' AS NVARCHAR(1000)) FROM mdm.tblEntity WHERE ID = @TempNextItem_ID  
                        END ELSE IF @TempNextItemType_ID = 2 BEGIN  
                            SET @TempNextEntity_ID_Clause = (SELECT Entity_ID FROM mdm.tblHierarchy WHERE ID = @TempNextItem_ID);  
                            SELECT @LookupID =Entity_ID FROM mdm.tblHierarchy WHERE ID = @TempNextItem_ID  
                            SELECT @TempNextEntity_MUID_Clause = CAST(N'''' + CONVERT(NVARCHAR(36), MUID) + N''''  AS NVARCHAR(1000)) FROM mdm.tblEntity WHERE ID = @LookupID                        
                        END ELSE IF @TempNextItemType_ID = 1 BEGIN  
                            SET @TempNextEntity_ID_Clause = (SELECT DomainEntity_ID FROM mdm.tblAttribute WHERE ID = @TempNextItem_ID);  
                            SELECT @LookupID=DomainEntity_ID FROM mdm.tblAttribute WHERE ID = @TempNextItem_ID  
                            SELECT @TempNextEntity_MUID_Clause = CAST(N'''' + CONVERT(NVARCHAR(36), MUID) + N''''  AS NVARCHAR(1000)) FROM mdm.tblEntity WHERE ID = @LookupID  
                        END ELSE IF @TempNextItemType_ID = 0 BEGIN  
                            SET @TempNextEntity_ID_Clause = CAST(@TempNextItem_ID AS NVARCHAR(1000));  
                            SELECT @TempNextEntity_MUID_Clause = CAST(N'''' + CONVERT(NVARCHAR(36), MUID) + N''''  AS NVARCHAR(1000)) FROM mdm.tblEntity WHERE ID = @TempNextItem_ID  
                        END ELSE BEGIN  
                            SET @TempNextEntity_ID_Clause = @TempNextItemType_ID  
                            SET @TempNextEntity_MUID_Clause = CAST(N'''' + CONVERT(NVARCHAR(36), @TempLookupEntity_MUID) + N''''  AS NVARCHAR(1000))					  
                        END; --if  
                    END; --if  
  
                    --Get AttributeEntity_ID  
                    IF @TempItemType_ID = 0 BEGIN  
                        SET @TempAttributeEntity_ID = CAST(N'-1' AS NVARCHAR(1000));  
                    END ELSE IF @TempItemType_ID = 1 BEGIN  
                        SET @TempAttributeEntity_ID = CAST(@TempItem_ID AS NVARCHAR(1000));  
                    END ELSE IF @TempItemType_ID = 2 BEGIN  
                        SET @TempAttributeEntity_ID = CAST(N'  
                            CASE   
                                WHEN ChildType_ID = 1 THEN (SELECT ForeignParent_ID FROM mdm.tblDerivedHierarchyDetail   
                                        WHERE DerivedHierarchy_ID = ' + CONVERT(NVARCHAR(30), @DerivedHierarchy_ID) + N'   
                                        AND Foreign_ID = ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N'   
                                        AND ForeignType_ID = 2)   
                                WHEN ChildType_ID = 2 THEN ''''   
                            END ' AS NVARCHAR(1000));  
                    END ELSE IF @TempItemType_ID = 3 BEGIN  
                        SET @TempAttributeEntity_ID = CAST(@TempItem_ID AS NVARCHAR(1000));  
                    END; --if  
  
                    SELECT   
                        @ChildTypeID_Clause = CASE --Get ChildType_ID  
                            WHEN @TempItemType_ID = 2 THEN N'ChildType_ID'  
                            WHEN @TempNextItemType_ID = 2 THEN N'2'  
                            ELSE N'1'  
                        END, --case	  
                        @ParentType_ID = CASE --Get ParentType_ID  
                            WHEN @TempItemType_ID = 3 THEN 1  
                            WHEN @TempItemType_ID = 2 THEN 2  
                            WHEN @TempNextItemType_ID = 2 THEN 2  
                            ELSE 1  
                        END, --case		  
                        @TempNextItem_ID_Clause = CASE --Get Next Item and ItemType  
                            WHEN @TempItemType_ID = 2 THEN N'  
                                CASE   
                                    WHEN ChildType_ID = 1 THEN ' + CONVERT(NVARCHAR(30), @TempNextItem_ID) + N'   
                                    WHEN ChildType_ID = 2 THEN ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N' END '  
                            ELSE CAST(@TempNextItem_ID AS NVARCHAR(100))  
                        END, --case  
                        @TempNextItemType_ID_Clause = CASE    
                            WHEN @TempItemType_ID = 2 THEN N'  
                                CASE   
                                    WHEN ChildType_ID = 1 THEN ' + CONVERT(NVARCHAR(30), @TempNextItemType_ID) + N'  
                                    WHEN ChildType_ID = 2 THEN 2 END '  
                            ELSE CAST(@TempNextItemType_ID AS NVARCHAR(100))  
                        END; --case		  
  
                    --First Level  
                    IF @TempCounter = 1 BEGIN  
                        SET @Select = CAST(N'SELECT ' AS NVARCHAR(max));  
  
                        IF @TempItemType_ID = 2   
                            SET @Select = @Select + CASE WHEN @TempItemType_ID = 2 THEN N'Parent_ID' ELSE N'ID' END + N' AS Parent_ID, ';  
                        ELSE   
                            SET @Select = @Select + N' 0 AS Parent_ID, ';  
  
                        SET @Select = @Select + N'  
                            ' + CASE WHEN @TempItemType_ID = 2 THEN N'CASE ChildType_ID WHEN 1 THEN Child_EN_ID WHEN 2 THEN Child_HP_ID END' ELSE N'ID' END + N' AS Child_ID,  
                            Version_ID AS Version_ID,  
                            ' + @TempAttributeEntity_ID + N' AS AttributeEntity_ID,  
                            ' + CASE WHEN @TempItemType_ID = 2 THEN N'CASE ChildType_ID WHEN 1 THEN Child_EN_ID WHEN 2 THEN Child_HP_ID END' ELSE N'ID' END + N' AS AttributeEntityValue,  
                            1 AS ParentVisible,  
                            ' + CONVERT(NVARCHAR(30), @TempLookupEntity_ID) + N' as Entity_ID,  
                            ''' + CAST(@TempLookupEntity_MUID  as NVARCHAR(36)) + N''' as Entity_MUID,  
                            ' + @TempNextEntity_ID_Clause + N' as NextEntity_ID,				  
                            ' + @TempNextEntity_MUID_Clause + N' as NextEntity_MUID,  
                            ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N' AS Item_ID,  
                            ''' + CAST(@TempItem_MUID as NVARCHAR(36)) + N''' as Item_MUID,  
                            ' + CONVERT(NVARCHAR(30), @TempItemType_ID) + N' AS ItemType_ID,';  
  
                        IF @TempItemType_ID = 2 SET @Select = @Select + N'  
                            CASE WHEN T.Parent_ID<>0 THEN ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N' ELSE 0 END as ParentItem_ID,  
                            CASE WHEN T.Parent_ID<>0 THEN ' + CONVERT(NVARCHAR(30), @TempItemType_ID) + N' ELSE 0 END as ParentItemType_ID,  
                            NULL as ParentEntity_ID,  
                            NULL as ParentEntity_MUID,';  
                              
                        ELSE SET @Select = @Select + N'  
                            0 as ParentItem_ID,  
                            0 as ParentItemType_ID,  
                            NULL as ParentEntity_ID,  
                            NULL as ParentEntity_MUID,';  
  
                        SET @Select = @Select + N'  
                            ' + @TempNextItem_ID_Clause + N' as NextItem_ID,  
                            ' + @TempNextItemType_ID_Clause + N' as NextItemType_ID,  
                            ' + CASE WHEN @TempItemType_ID = 2 THEN N'Child_Code' ELSE N'Code' END + N' as ChildCode,   
                            ' + CASE WHEN @TempItemType_ID = 2 THEN N'Child_Name' ELSE N'Name' END + N' as ChildName,   
                            CASE  
                                WHEN ' + CONVERT(NVARCHAR(30), @TempItemType_ID) + N' = 2 THEN '   
                                    +  CASE WHEN @TempItemType_ID = 2 THEN N'Parent_Code' ELSE N'Code' END + N'  
                                ELSE ''ROOT''   
                            END as ParentCode, --case  
                            CASE  
                                WHEN ' + CONVERT(NVARCHAR(30), @TempItemType_ID) + N' = 2 THEN ' +   
                                CASE  
                                WHEN @TempItemType_ID = 2 THEN N'Parent_Name'  
                                ELSE N'Name' END  
                                + N'  
                                ELSE ''''   
                            END as ParentName, --case  
                            ' + @ChildTypeID_Clause + N' as ChildType_ID,  
                            CASE  
                                WHEN ' + CONVERT(NVARCHAR(30), @TempItemType_ID) + N' <> 2 THEN 2  
                                ELSE ' + CONVERT(NVARCHAR(1000),@ParentType_ID) + N'  
                            END as ParentType_ID, --case  
                            ' + CONVERT(NVARCHAR(30), @CurrentLevel_ID) + N' as Level,  
                            ' + @TempSortColumn + N' as SortItem  
                            FROM mdm.' + quotename(@TempLookupViewName) + N' AS T ';  
  
                        IF @TempItemType_ID = 2 BEGIN  
                            SET @Select = @Select + N'  
                            WHERE Hierarchy_ID = ' + CONVERT(NVARCHAR(30), @TempItem_ID);  
                        END; --if  
                          
                        --Rendering for anchored recursive hierarchies.  
                        IF @IsRecursive = 1 AND @AnchorNullRecursions = 1 AND @TempItemType_ID = @HierarchyItemType_DBA BEGIN  
                            SET @Select = @Select + N'  
                            WHERE ' + QUOTENAME(@TempLookupAttributeName) + N' IS NULL'  
                        END;  
          
                    END ELSE BEGIN  
                    --All other Levels  
                      
                        --Check to see if Levels are skipped----------------  
                        IF @CurrentLevel_ID <> @PriorLevel_ID - 1 BEGIN  
  
                            SET @Select = @Select + N'  
                                UNION ALL  
                                SELECT  
                                    ' + CASE WHEN @TempLookupPriorItemType_ID = 2 THEN N'CASE P.ChildType_ID WHEN 1 THEN P.Child_EN_ID WHEN 2 THEN P.Child_HP_ID END' ELSE N'P.ID' END + N' AS Parent_ID,  
                                    T.ID AS Child_ID,  
                                    T.Version_ID as Version_ID,   
                                    ' + @TempAttributeEntity_ID + N' as AttributeEntity_ID,  
                                    ' + CASE WHEN @TempItemType_ID = 2 THEN N'CASE T.ChildType_ID WHEN 1 THEN T.Child_EN_ID WHEN 2 THEN T.Child_HP_ID END' ELSE N'T.ID' END + N' as AttributeEntityValue,  
                                    0 as ParentVisible,  
                                    ' + CONVERT(NVARCHAR(25),@TempLookupEntity_ID) + N' as Entity_ID,  
                                    ''' + CAST(@TempLookupEntity_MUID  as NVARCHAR(36))+ N''' as Entity_MUID,  
                                    ' + @TempNextEntity_ID_Clause + N' as NextEntity_ID,  
                                    ' + @TempNextEntity_MUID_Clause + N' as NextEntity_MUID,  
                                    ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N' as Item_ID,  
                                    ''' + CAST(@TempItem_MUID AS NVARCHAR(36))+ N''' as Item_MUID,  
                                    ' + CONVERT(NVARCHAR(30), @TempItemType_ID) + N' as ItemType_ID,  
                                    ' + CONVERT(NVARCHAR(30), @TempLookupPriorItem_ID) + N' as ParentItem_ID,  
                                    ' + CONVERT(NVARCHAR(30), @TempLookupPriorItemType_ID) + N' as ParentItemType_ID,  
                                    ''' + CAST(@TempLookupPriorEntity_ID  as NVARCHAR(30)) + N''' as ParentEntity_ID,  
                                    ''' + CAST(@TempLookupPriorEntity_MUID  as NVARCHAR(36)) + N''' as ParentEntity_MUID,  
                                    ' + @TempNextItem_ID_Clause + N' as NextItem_ID,  
                                    ' + @TempNextItemType_ID_Clause + N' as NextItemType_ID,  
                                    T.Code as ChildCode,   
                                        T.Name as ChildName,   
                                    P.' + quotename(CASE WHEN @TempLookupPriorItemType_ID = 2 THEN N'Child_Code' ELSE N'Code' END) + N' as ParentCode,  
                                    P.' + quotename(CASE WHEN @TempLookupPriorItemType_ID = 2 THEN N'Child_Name' ELSE N'Name' END) + N' as ParentName,  
                                    ' + @ChildTypeID_Clause + N' as ChildType_ID,  
                                    ' + CONVERT(NVARCHAR(1000),@ParentType_ID) + N' as ParentType_ID,  
                                    ' + CONVERT(NVARCHAR(30), @CurrentLevel_ID) + N' as Level,  
                                    ' + @TempSortColumn + N' as SortItem  
                                FROM  
                                    mdm.' + quotename(@TempLookupViewName) + N' AS T ';  
  
                            ---Loop through all NonVisible Levels  
                            --Get List of tables to join to if skipping levels  
                            SELECT   
                                @From = CAST(N''  AS NVARCHAR(max)),  
                                @TempSubCounter = 0;  
  
                            INSERT INTO @TempSubTable   
                            SELECT Item_ID,ItemType_ID,Level_ID FROM @TempTable   
                            WHERE Level_ID BETWEEN @CurrentLevel_ID AND @PriorLevel_ID   
                            AND Level_ID != @CurrentLevel_ID AND Level_ID != @PriorLevel_ID  
                            ORDER BY Level_ID ASC;  
  
                            SELECT @TempTotalCounter = COUNT(*) FROM @TempSubTable;  
  
                            WHILE EXISTS(SELECT 1 FROM @TempSubTable) BEGIN  
                                SET @TempSubCounter = @TempSubCounter + 1;  
  
                                SELECT TOP 1     
                                    @TempSubItem_ID = Item_ID,    
                                    @TempSubItemType_ID = ItemType_ID     
                                FROM @TempSubTable    
                                ORDER BY Level_ID ASC;    
    
                                SET @TempLookupEntity_ID = CASE    
                                    WHEN @TempSubItemType_ID = 1 THEN (SELECT DomainEntity_ID FROM mdm.tblAttribute WHERE ID = @TempSubItem_ID)    
                                    WHEN @TempSubItemType_ID = 0 THEN @TempSubItem_ID    
                                END; --case    
    
                                --Get View Name of hidden level    
                                SET @TempLookupSubViewName = mdm.udfViewNameGetByID(@TempLookupEntity_ID,1,0);    
                            
                                --Figure out Attribtue DBA Column Name			    
                                SELECT @TempLookupSubAttributeName = [Name] FROM mdm.tblAttribute WHERE ID = @TempSubItem_ID;    
                                        
                                --Build Join Table List    
                                IF @TempSubCounter = 1 SET @From = @From + N'    
                                        INNER JOIN mdm.' + quotename(@TempLookupSubViewName) + N' AS ' + quotename(@TempLookupSubViewName) + N'     
                                            ON ' + quotename(@TempLookupSubViewName) + N'.Code = T.' + quotename(@TempLookupSubAttributeName) + N'     
                                            AND ' + quotename(@TempLookupSubViewName) + N'.Version_ID = T.Version_ID ';    
                                ELSE SET @From = @From + N'     
                                        INNER JOIN mdm.' + quotename(@TempLookupSubViewName) + N' AS ' + quotename(@TempLookupSubViewName) + N'     
                                            ON ' + quotename(@TempLookupSubViewName) + N'.Code = ' + quotename(@TempLookupPriorSubViewName) + N'.' + quotename(@TempLookupSubAttributeName) + N'      
                                            AND ' + quotename(@TempLookupSubViewName) + N'.Version_ID = ' + quotename(@TempLookupPriorSubViewName) + N'.Version_ID ';    
    
                                SET @From = @From + N' AND ' + quotename(@TempLookupSubViewName) + N'.Version_ID = T.Version_ID'     
    
                                --If Last Table to Join then and the final table to join back to base    
                                IF @TempSubCounter =@TempTotalCounter SET @From = @From + N'    
                                        INNER JOIN mdm.' + quotename(@TempLookupPriorVisibleViewName) + N' AS P     
                                            ON P.' + quotename(CASE WHEN @TempLookupPriorItemType_ID = 2 THEN N'Child_Code' ELSE N'Code' END) + N' = ' + quotename(@TempLookupSubViewName) + N'.' + quotename(@TempLookupPriorAttributeName) + N'      
                                            AND P.Version_ID = ' + quotename(@TempLookupSubViewName) + N'.Version_ID ';    
    
                                SET @TempLookupPriorSubViewName = @TempLookupSubViewName;    
    
                                DELETE FROM @TempSubTable WHERE Item_ID = @TempSubItem_ID;    
                                DELETE FROM @TempTable WHERE Level_ID BETWEEN @CurrentLevel_ID AND @PriorLevel_ID;    
  
                            END; --while  
                            --End of Sub Loop of NonVisible Levels  
                              
                            SELECT @Select = @Select + @From;  
  
                        END	ELSE BEGIN  
                        --Visible Levels  
                          
                            IF @TempLookupIsVisible = 1 BEGIN  
                                IF @TempItemType_ID = 2	BEGIN  
                                    --Figure out if there is another level on top of hierarchy  
                                    --If so find the parent ID's and codes  
                                    SET @Select = @Select + N'  
                                        UNION ALL								  
                                        SELECT  
                                            T.Parent_ID AS Parent_ID,  
                                            CASE T.ChildType_ID WHEN 1 THEN T.Child_EN_ID WHEN 2 THEN T.Child_HP_ID END AS Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            ' + @TempAttributeEntity_ID + N' as AttributeEntity_ID,  
                                            ' + CASE WHEN @TempItemType_ID = 2 THEN N'CASE T.ChildType_ID WHEN 1 THEN T.Child_EN_ID WHEN 2 THEN T.Child_HP_ID END' ELSE N'T.ID' END + N' AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            ' + CONVERT(NVARCHAR(25),@TempLookupEntity_ID) + N' as Entity_ID,  
                                            ''' + CAST(@TempLookupEntity_MUID  as NVARCHAR(36))+ ''' as Entity_MUID,  
                                            ' + @TempNextEntity_ID_Clause + N' as NextEntity_ID,  
                                            ''' + @TempNextEntity_MUID_Clause + N''' as NextEntity_MUID,  
                                            ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N' as Item_ID,  
                                            ''' + CAST(@TempItem_MUID AS NVARCHAR(36))  + N''' as Item_MUID,  
                                            ' + CONVERT(NVARCHAR(30), @TempItemType_ID) + N' as ItemType_ID,  
                                            CASE   
                                                WHEN T.Parent_ID=0 OR T.Child_LevelNumber=1 THEN ' + CONVERT(NVARCHAR(30), @TempLookupPriorItem_ID) + N'  
                                                ELSE ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N'   
                                            END as ParentItem_ID, --case  
                                            CASE   
                                                WHEN T.Parent_ID=0 OR T.Child_LevelNumber=1 THEN ' + CONVERT(NVARCHAR(30), @TempLookupPriorItemType_ID) + N'   
                                                ELSE ' + CONVERT(NVARCHAR(30), @TempItemType_ID) + N'   
                                            END as ParentItemType_ID, --case  
                                            ''' + CAST(@TempLookupPriorEntity_ID  as NVARCHAR(30)) + N''' as ParentEntity_ID,  
                                            ''' + CAST(@TempLookupPriorEntity_MUID  as NVARCHAR(36)) + N''' as ParentEntity_MUID,  
                                            ' + @TempNextItem_ID_Clause + N' as NextItem_ID,  
                                            ' + @TempNextItemType_ID_Clause + N' as NextItemType_ID,  
                                            T.' + CASE WHEN @TempItemType_ID = 2 THEN N'Child_Code' ELSE N'Code' END + N' as ChildCode,   
                                            T.' + CASE WHEN @TempItemType_ID = 2 THEN N'Child_Name' ELSE N'Name' END + N' as ChildName,   
                                            Parent_Code as ParentCode,  
                                            Parent_Name as ParentName,  
                                            ' + @ChildTypeID_Clause + N' as ChildType_ID,  
                                            ' + CONVERT(NVARCHAR(1000),@ParentType_ID) + N' as ParentType_ID,  
                                            ' + CONVERT(NVARCHAR(30), @CurrentLevel_ID) + N' as Level,  
                                            ' + @TempSortColumn + N' as SortItem  
                                        FROM  
                                            mdm.' + quotename(@TempLookupViewName) + N' AS T ';  
  
                                END ELSE BEGIN  
                                    SET @Select = @Select + N'  
                                        UNION ALL								  
                                        SELECT  
                                            ' + CASE WHEN @TempLookupPriorItemType_ID = 2 THEN N'CASE ' + quotename(@TempLookupPriorVisibleViewName) + N'.ChildType_ID WHEN 1 THEN ' + quotename(@TempLookupPriorVisibleViewName) + N'.Child_EN_ID WHEN 2 THEN ' + quotename(@TempLookupPriorVisibleViewName) + N'.Child_HP_ID END' ELSE quotename(@TempLookupPriorVisibleViewName) + N'.ID' END + N' AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            ' + CASE WHEN @PriorIsRecursive = 1 THEN + CONVERT(NVARCHAR(30), @TempLookupPriorItem_ID) ELSE @TempAttributeEntity_ID END + N' as AttributeEntity_ID,    
                                            ' + CASE WHEN @TempItemType_ID = 2 THEN N'CASE T.ChildType_ID WHEN 1 THEN T.Child_EN_ID WHEN 2 THEN T.Child_HP_ID END' ELSE N'T.ID' END + N' AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            ' + CONVERT(NVARCHAR(25),@TempLookupEntity_ID) + N' as Entity_ID,  
                                            ''' + CAST(@TempLookupEntity_MUID  as NVARCHAR(36)) + N''' as Entity_MUID,  
                                            ' + @TempNextEntity_ID_Clause + N' as NextEntity_ID,  
                                            ' + @TempNextEntity_MUID_Clause + N' as NextEntity_MUID,  
                                            ' + CONVERT(NVARCHAR(30), @TempItem_ID) + N' as Item_ID,  
                                            ''' + CAST(@TempItem_MUID AS NVARCHAR(36)) + N''' as Item_MUID,  
                                            ' + CONVERT(NVARCHAR(30), @TempItemType_ID) + N' as ItemType_ID,  
                                            ' + CONVERT(NVARCHAR(30), @TempLookupPriorItem_ID) + N' as ParentItem_ID,  
                                            ' + CONVERT(NVARCHAR(30), @TempLookupPriorItemType_ID) + N' as ParentItemType_ID,  
                                            ''' + CAST(@TempLookupPriorEntity_ID  as NVARCHAR(30)) + N''' as ParentEntity_ID,  
                                            ''' + CAST(@TempLookupPriorEntity_MUID  as NVARCHAR(36)) + N''' as ParentEntity_MUID,  
                                            ' + @TempNextItem_ID_Clause + N' as NextItem_ID,  
                                            ' + @TempNextItemType_ID_Clause + N' as NextItemType_ID,  
                                            T.' + quotename(CASE WHEN @TempItemType_ID = 2 THEN N'Child_Code' ELSE N'Code' END) + N' as ChildCode,   
                                            T.' + quotename(CASE WHEN @TempItemType_ID = 2 THEN N'Child_Name' ELSE N'Name' END) + N' as ChildName,   
                                            ' + quotename(@TempLookupPriorVisibleViewName) + N'.' + quotename(CASE WHEN @TempLookupPriorItemType_ID = 2 THEN N'Child_Code' ELSE N'Code' END) + N' as ParentCode,  
                                            ' + quotename(@TempLookupPriorVisibleViewName) + N'.' + quotename(CASE WHEN @TempLookupPriorItemType_ID = 2 THEN N'Child_Name' ELSE N'Name' END) + N' as ParentName,  
                                            ' + @ChildTypeID_Clause + N' as ChildType_ID,  
                                            ' + CONVERT(NVARCHAR(1000),@ParentType_ID) + N' as ParentType_ID,  
                                            ' + CONVERT(NVARCHAR(30), @CurrentLevel_ID) + N' as Level,  
                                            ' + @TempSortColumn + N' as SortItem  
                                        FROM  
                                            mdm.' + quotename(@TempLookupViewName) + N' AS T  
                                        INNER JOIN mdm.' + quotename(@TempLookupPriorVisibleViewName) + N' AS ' + quotename(@TempLookupPriorVisibleViewName) + N'   
                                            ON ' + quotename(@TempLookupPriorVisibleViewName) + N'.' + quotename(CASE WHEN @TempLookupPriorItemType_ID = 2 THEN N'Child_Code' ELSE N'Code' END) + N' = T.' + quotename(@TempLookupPriorAttributeName) + N'   
                                            AND ' + quotename(@TempLookupPriorVisibleViewName) + N'.Version_ID = T.Version_ID ';  
                                      
                                    IF @TempLookupPriorItemType_ID = 2 BEGIN  
                                        SET @Select = @Select + N'  
                                            WHERE ' + quotename(@TempLookupPriorVisibleViewName) + N'.Hierarchy_ID = ' + CONVERT(NVARCHAR(30), @TempLookupPriorItem_ID);  
                                    END; --if													  
                                END; --if								  
                            END; --if				  
                        END; --if  
                    END; --if  
  
                    SELECT  
                        @TempLookupPriorItem_ID = @TempItem_ID,  
                        @TempLookupPriorItemType_ID = @TempItemType_ID,  
                        @TempLookupPriorViewName = @TempLookupViewName,  
                        @TempLookupPriorVisibleViewName = @TempLookupViewName,  
                        @TempLookupPriorAttributeName = @TempLookupAttributeName,  
                        @TempLookupPriorEntity_ID = @TempLookupEntity_ID,  
                        @TempLookupPriorEntity_MUID = @TempLookupEntity_MUID,  
                        @PriorIsRecursive = @IsRecursive;  
                          
                    IF @TempLookupIsVisible = 1 BEGIN  
                        DELETE FROM @TempTable   
                        WHERE Item_ID = @TempItem_ID AND ItemType_ID = @TempItemType_ID AND Level_ID = @CurrentLevel_ID;  
                    END; --if  
  
                    IF @TempItemType_ID = 2 BEGIN --Skip next Level after Hierarchy  
                        -- Always use an ORDER BY when selecting TOP  
                        SELECT TOP 1 @TempItem_ID = Item_ID   
                        FROM @TempTable  
                        ORDER BY Level_ID DESC;  
                          
                        SELECT @TempLookupPriorAttributeName = [Name]   
                        FROM mdm.tblAttribute where ID = @TempItem_ID;  
                          
                        DELETE FROM @TempTable   
                        WHERE Item_ID = @TempItem_ID;  
                    END; --if  
                END; --while  
  
                SET @Select = CASE   
                    WHEN EXISTS(SELECT 1 FROM sys.views WHERE [name] = @ViewName AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER'  
                    ELSE N'CREATE' END   
                + N' VIEW mdm.' + quotename(@ViewName) + N'  
                    AS ' + @Select + N';';  
  
                --PRINT @Select;  
                EXEC sp_executesql @Select;  
  
            END; --if  
  
        END; --if  
  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
