SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpCreateAllViews  
    EXEC mdm.udpCreateSystemAttributeViews 1,1,0;  
    EXEC mdm.udpCreateSystemAttributeViews 1,1,1;  
    EXEC mdm.udpCreateSystemAttributeViews 1,1,2;  
    EXEC mdm.udpCreateSystemAttributeViews 1,1,3;  
    EXEC mdm.udpCreateSystemAttributeViews 1,3,3;  
    EXEC mdm.udpCreateSystemAttributeViews 41,1,1;  
    EXEC mdm.udpCreateSystemAttributeViews 111111,3,3; --invalid  
    EXEC mdm.udpCreateSystemAttributeViews 1,3,12; --invalid  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpCreateSystemAttributeViews]   
(  
    @Entity_ID			INT,  
    @MemberType_ID		TINYINT,  
    @DisplayType_ID		TINYINT  
)   
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Defer view generation if we are in the middle of an upgrade or demo-rebuild  
    IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
        DECLARE @ViewName					sysname,  
                @EntityTable  				sysname,  
                @CollectionTable  			sysname,  
                @HierarchyParentTable  		sysname,  
                @DomainTable				sysname,  
                @Select						NVARCHAR(MAX),  
                @From						NVARCHAR(MAX),  
                @TableColumn				sysname,  
                @ViewColumn					nvarchar(120), --specifically made to be less than 128 for truncation reasons  
                @ViewColumnQuoted			nvarchar(300),  
                @DomainEntity_ID			INT,  
                @AttributeType_ID			INT;	  
  
        --Initialize the variables  
        SELECT  
            @EntityTable = E.EntityTable,  
            @CollectionTable = E.CollectionTable,  
            @HierarchyParentTable = E.HierarchyParentTable,  
            @ViewName = mdm.udfViewNameGetByID(E.ID, @MemberType_ID, @DisplayType_ID),  
            @From = N''  
        FROM mdm.tblEntity E  
        WHERE E.ID = @Entity_ID;  
  
        IF @ViewName IS NOT NULL BEGIN --Ensure row actually exists  
  
            --Get the Attributes for the Entity and then find the corresponding lookup table  
            DECLARE @TempTable TABLE(  
                 ViewColumn			nvarchar(120) COLLATE database_default  
                ,TableColumn		sysname COLLATE database_default  
                ,AttributeType_ID	INT  
                ,DomainEntity_ID	INT NULL  
                ,DomainTable		sysname COLLATE database_default NULL  
                ,SortOrder          INT);  
            INSERT INTO @TempTable  
            SELECT  
                ViewColumn,  
                TableColumn,  
                AttributeType_ID,  
                DomainEntity_ID,  
                DomainTable,  
                SortOrder  
            FROM 	  
                mdm.udfEntityAttributesGetList(@Entity_ID, @MemberType_ID)   
            ORDER BY   
                SortOrder ASC;  
  
            SET @Select = N'  
                 T.ID  
                ,T.Version_ID  
                ,T.ValidationStatus_ID';  
                  
            IF @MemberType_ID NOT IN (1, 3) SET @Select = @Select + N'  
                ,H.ID AS Hierarchy_ID';  
                   
            IF @MemberType_ID <> 3 SET @Select = @Select + N'  
                --Change Tracking  
                ,T.ChangeTrackingMask';  
  
            SET @Select = @Select + N'  
                 --Auditing columns (Creation)  
                ,T.EnterDTM  
                ,T.EnterUserID  
                ,eu.[UserName] AS EnterUserName  
                ,eu.MUID AS EnterUserMuid  
                  
                ,T.EnterVersionID AS EnterVersionId  
                ,ev.[Name] AS EnterVersionName  
                ,ev.MUID AS EnterVersionMuid  
  
                --Auditing columns (Updates)  
                ,T.LastChgDTM  
                ,T.LastChgUserID  
                ,lcu.[UserName] AS LastChgUserName  
                ,lcu.MUID AS LastChgUserMuid  
  
                ,T.LastChgVersionID AS LastChgVersionId  
                ,lcv.[Name] AS LastChgVersionName  
                ,lcv.MUID AS LastChgVersionMuid  
                --Custom attributes';  
              
            SET @From += N'  
            LEFT JOIN mdm.tblUser eu ON T.EnterUserID = eu.ID  
            LEFT JOIN mdm.tblUser lcu ON T.LastChgUserID = lcu.ID  
            LEFT JOIN mdm.tblModelVersion ev ON T.EnterVersionID = ev.ID  
            LEFT JOIN mdm.tblModelVersion lcv ON T.LastChgVersionID = lcv.ID  
';  
            WHILE EXISTS(SELECT 1 FROM @TempTable) BEGIN  
  
                SELECT TOP 1   
                    @ViewColumn = ViewColumn,  
                    @TableColumn = TableColumn,  
                    @AttributeType_ID = AttributeType_ID,  
                    @DomainEntity_ID = DomainEntity_ID,  
                    @DomainTable = DomainTable  
                FROM @TempTable  
                ORDER BY SortOrder;  
  
                SET @ViewColumnQuoted = QUOTENAME(@ViewColumn);  
  
                IF @AttributeType_ID = 1 BEGIN --FFA  
  
                    IF @ViewColumn = N'Owner_ID' AND @MemberType_ID = 3 BEGIN  
  
                        IF @DisplayType_ID = 1 OR @DisplayType_ID = 0 BEGIN  
                            SET @Select = @Select + N'  
                                ,ISNULL(' + @ViewColumnQuoted + N'.UserName, '''') AS Owner_ID';  
                        END ELSE IF @DisplayType_ID = 2 BEGIN  
                            SET @Select = @Select + + N'  
                                ,ISNULL(' + @ViewColumnQuoted + N'.UserName,'''') '   
                                + N' + ''{'' + '   
                                + N'ISNULL(' + @ViewColumnQuoted + N'.DisplayName,'''')'  
                                + N' + ''}''' + N'  AS Owner_ID';  
                        END ELSE IF @DisplayType_ID = 3 BEGIN  
                            SET @Select = @Select + N'  
                                ,ISNULL(' + @ViewColumnQuoted + N'.DisplayName,'''')'   
                                + N' + ''{'' + ISNULL(' + @ViewColumnQuoted + N'.UserName,'''') + ''}'' AS Owner_ID';  
                        END; --if  
  
                        SET @From = @From + N'  
                            LEFT JOIN mdm.tblUser AS Owner_ID ON Owner_ID.ID = T.Owner_ID';  
  
                    END ELSE BEGIN  
  
                        SET @Select = @Select + N'  
                            ,T.' + quotename(@TableColumn) + N' AS ' + @ViewColumnQuoted;  
  
                    END; --if  
  
                END ELSE IF @AttributeType_ID = 2 BEGIN --DBA  
  
                    IF @DisplayType_ID = 0 BEGIN  
                        SET @Select = @Select + N'  
                            ,' + @ViewColumnQuoted + N'.Code AS ' + @ViewColumnQuoted + N'  
                            ,' + @ViewColumnQuoted + N'.ID AS ' + quotename(@ViewColumn + N'.ID') + N'  
                            ,' + @ViewColumnQuoted + N'.Code AS ' + quotename(@ViewColumn + N'.Code') + N'  
                            ,' + @ViewColumnQuoted + N'.Name AS ' + quotename(@ViewColumn + N'.Name');  
                    END ELSE IF @DisplayType_ID = 1 BEGIN  
                        SET @Select = @Select + N'  
                            ,' + @ViewColumnQuoted + N'.Code AS ' + @ViewColumnQuoted;  
                    END ELSE IF @DisplayType_ID = 2 BEGIN  
                        SET @Select = @Select + N'  
                            ,' + @ViewColumnQuoted + N'.Code + ''{'' + ISNULL(' + @ViewColumnQuoted + N'.Name,'''') + ''}'' AS ' + @ViewColumnQuoted + N'  
                            ,' + @ViewColumnQuoted + N'.Code AS ' + quotename(@ViewColumn + N'.Code') + N'  
                            ,' + @ViewColumnQuoted + N'.Name AS ' + quotename(@ViewColumn + N'.Name');  
                    END ELSE IF @DisplayType_ID = 3 BEGIN  
                        SET @Select = @Select + N'  
                            ,ISNULL(' + @ViewColumnQuoted + N'.Name,'''') + ''{'' + ' + @ViewColumnQuoted + N'.Code + ''}'' AS ' + @ViewColumnQuoted + N'  
                            ,' + @ViewColumnQuoted + N'.Code AS ' + quotename(@ViewColumn + N'.Code') + N'  
                            ,' + @ViewColumnQuoted + N'.Name AS ' + quotename(@ViewColumn + N'.Name');  
                    END; --if  
  
                    SET @From = @From + N'  
                        LEFT JOIN mdm.' + quotename(@DomainTable) + N' AS ' + @ViewColumnQuoted + N' ON ' + @ViewColumnQuoted + N'.ID = T.' + quotename(@TableColumn) + N'   
                            AND ' + @ViewColumnQuoted + N'.Version_ID = T.Version_ID';  
  
                END ELSE IF @AttributeType_ID = 4 BEGIN --File  
  
                    IF @DisplayType_ID = 0 BEGIN  
                        SET @Select = @Select + N'  
                            ,' + @ViewColumnQuoted + N'.FileDisplayName AS ' + @ViewColumnQuoted + N'  
                            ,' + @ViewColumnQuoted + N'.ID AS ' + quotename(@ViewColumn + N'.ID') + N'  
                            ,' + @ViewColumnQuoted + N'.FileDisplayName AS ' + quotename(@ViewColumn + N'.Code') + N'  
                            ,' + @ViewColumnQuoted + N'.FileDisplayName AS ' + quotename(@ViewColumn + N'.Name');  
                    END ELSE BEGIN  
                        SET @Select = @Select + N'  
                            ,' + @ViewColumnQuoted + N'.FileDisplayName AS ' + @ViewColumnQuoted;  
                    END; --if  
  
  
                    SET @From = @From + N'  
                        LEFT JOIN mdm.tblFile AS ' + @ViewColumnQuoted + N' ON ' + @ViewColumnQuoted + N'.ID = T.' + quotename(@TableColumn);  
  
                END; --if  
                              
                DELETE FROM @TempTable WHERE ViewColumn = @ViewColumn;  
            END; --while  
  
            SET @Select = CASE   
                WHEN EXISTS(SELECT 1 FROM sys.views WHERE [name] = @ViewName AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER '  
                ELSE N'CREATE ' END + N'VIEW mdm.' + quotename(@ViewName) + N'  
                /*WITH ENCRYPTION*/ AS SELECT '  
                + @Select;  
  
            IF @MemberType_ID = 1 BEGIN  
                SET @Select = @Select + N'  
                FROM mdm.' + quotename(@EntityTable) + N' AS T';  
            END ELSE IF @MemberType_ID = 2 BEGIN  
                SET @Select = @Select + N'  
                FROM mdm.' + quotename(@HierarchyParentTable) + N' AS T   
                    INNER JOIN mdm.tblHierarchy AS H ON H.ID = T.Hierarchy_ID';  
            END ELSE IF @MemberType_ID = 3 BEGIN  
                SET @Select = @Select + N'  
                FROM mdm.' + quotename(@CollectionTable) + N' AS T';  
            END; --if  
  
            SET @Select = @Select   
                + @From + N'  
                WHERE T.Status_ID = 1;';  
  
            --PRINT(@Select);  
            EXEC sp_executesql @Select;  
              
        END; --if  
  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
