SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpCreateAttributeViews 1, 1, 1, 1, NULL, 'TEST';  
    EXEC mdm.udpCreateAttributeViews 1, 2, 1, 1, NULL, 'TEST';  
    EXEC mdm.udpCreateAttributeViews 1, 3, 1, NULL, 9, 'TEST';  
    EXEC mdm.udpCreateAttributeViews 111111, 1; --invalid  
*/  
CREATE PROCEDURE [mdm].[udpCreateAttributeViews]   
(  
   @Entity_ID           INT,  
   @MemberType_ID       TINYINT,  
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
  
        DECLARE @ViewName               sysname,  
                @EntityTable            sysname,  
                @HierarchyTable         sysname,  
                @HierarchyParentTable   sysname,  
                @CollectionTable        sysname,  
                @Select                 NVARCHAR(MAX),  
                @From                   NVARCHAR(MAX),  
                @ViewColumn             nvarchar(120), --specifically made to be less than 128 for truncation reasons  
                @TableColumn            sysname,  
                @DomainTable            sysname,  
                @DomainEntity_ID        INT,  
                @AttributeType_ID       INT;  
              
            --Test for invalid parameters  
            IF (@Model_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModel WHERE ID = @Model_ID)) --Invalid Model_ID  
                  OR (@Entity_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblEntity WHERE ID = @Entity_ID)) --Invalid @Entity_ID  
                  OR (@Version_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModelVersion WHERE ID = @Version_ID)) -- Invalid @Version_ID  
                  OR (@SubscriptionViewName IS NULL)  
  
            BEGIN  
                  RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
                  RETURN(1);  
            END; --if  
  
        -- Lookup the Version ID from mdm.tblModelVersion based on the version flag  
        IF (@VersionFlag_ID IS NOT NULL) AND (@Version_ID IS NULL)  
        BEGIN  
            SELECT @Version_ID = ID   
            FROM mdm.tblModelVersion  V  
            WHERE V.VersionFlag_ID = @VersionFlag_ID  
        END  
          
        SELECT  
            @EntityTable = E.EntityTable,  
            @CollectionTable = E.CollectionTable,  
            @HierarchyTable = E.HierarchyTable,  
            @HierarchyParentTable = E.HierarchyParentTable,  
            @ViewName = @SubscriptionViewName,  
            @From = N''  
        FROM mdm.tblEntity E   
        INNER JOIN mdm.tblModel M ON E.Model_ID = M.ID  
        WHERE E.ID = @Entity_ID  
            AND M.ID = @Model_ID;  
  
        IF @ViewName IS NOT NULL BEGIN --Ensure row actually exists  
  
            SET @Select = N'  
                V.Name AS VersionName,V.Display_ID AS VersionNumber,DV.Name AS VersionFlag'  
                + CASE @MemberType_ID  
                    WHEN 1 THEN N'' --Leaf  
                    WHEN 3 THEN N'' --Collection  
                    ELSE N',H.Name as Hierarchy'  
                END; --case  
  
            --Get the Attributes for the Entity and then find the corresponding lookup table  
            DECLARE @TempTable TABLE(  
                    ViewColumn          sysname COLLATE database_default  
                    ,TableColumn        sysname COLLATE database_default  
                    ,AttributeType_ID   INT  
                    ,DomainEntity_ID    INT NULL  
                    ,DomainTable        sysname COLLATE database_default NULL  
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
  
            WHILE EXISTS(SELECT 1 FROM @TempTable) BEGIN  
          
                SELECT TOP 1   
                    @ViewColumn = ViewColumn,  
                    @TableColumn = TableColumn,  
                    @AttributeType_ID = AttributeType_ID,  
                    @DomainEntity_ID = DomainEntity_ID,  
                    @DomainTable = DomainTable  
                FROM @TempTable  
                ORDER BY   
                    SortOrder ASC;  
  
                IF @DomainEntity_ID IS NULL BEGIN  
  
                    IF @ViewColumn = N'Owner_ID' AND @MemberType_ID = 3 BEGIN --Collection  
                        SET @Select = @Select + N'  
                            ,' + quotename(@ViewColumn) + N'.UserName AS [Owner_ID]';  
                        SET @From = @From + N'  
                            LEFT JOIN mdm.tblUser AS Owner_ID ON Owner_ID.ID = T.Owner_ID';  
                    END ELSE BEGIN  
                        SET @Select = @Select + N'  
                            ,T.' + quotename(@TableColumn) + N' AS ' + quotename(@ViewColumn);  
                    END; --if  
  
                END ELSE BEGIN  
  
                    SET @Select = @Select + N'  
                        ,' + quotename(@ViewColumn) + N'.Code AS ' + quotename(@ViewColumn + N'_Code') + N'  
                        ,' + quotename(@ViewColumn) + N'.Name AS ' + quotename(@ViewColumn + N'_Name') + N'  
                        ,' + quotename(@ViewColumn) + N'.ID AS ' + quotename(@ViewColumn + N'_ID');  
                    SET @From = @From + N'  
                        LEFT JOIN mdm.' + quotename(@DomainTable) + N' AS ' + quotename(@ViewColumn) + N' ON ' + quotename(@ViewColumn) + N'.ID = T.' + quotename(@TableColumn) + N'  
                            AND ' + quotename(@ViewColumn) + N'.Version_ID = T.Version_ID';  
  
                END; --if  
  
                DELETE FROM @TempTable WHERE ViewColumn = @ViewColumn;  
  
            END; --while  
              
            SET @Select = CASE   
                WHEN EXISTS(SELECT 1 FROM sys.views WHERE [name] = @ViewName AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER'  
                ELSE N'CREATE' END + N' VIEW mdm.' + quotename(@ViewName) + N'  
                /*WITH ENCRYPTION*/  
                AS SELECT   
                     T.ID AS ID  
                    ,T.MUID AS MUID   
                    ,' + @Select + N'  
                    ,T.EnterDTM AS EnterDateTime  
                    ,(SELECT UserName FROM mdm.tblUser WHERE ID = T.EnterUserID) AS EnterUserName  
                    ,(SELECT Display_ID FROM mdm.tblModelVersion WHERE ID = T.EnterVersionID) AS EnterVersionNumber  
                    ,T.LastChgDTM AS LastChgDateTime  
                    ,(SELECT UserName FROM mdm.tblUser WHERE ID = T.LastChgUserID) AS LastChgUserName  
                    ,(SELECT Display_ID FROM mdm.tblModelVersion WHERE ID = T.LastChgVersionID) AS LastChgVersionNumber  
                    ,(SELECT ListOption FROM mdm.tblList WHERE ListCode = ''lstValidationStatus'' AND OptionID = T.ValidationStatus_ID) AS ValidationStatus';  
  
            IF @MemberType_ID = 1 BEGIN --Leaf (EN)  
                  
                    SET @Select = @Select + N'  
                        FROM mdm.' + quotename(@EntityTable) + N' AS T   
                            INNER JOIN mdm.tblModelVersion AS V ON V.ID = T.Version_ID '  
                                          
                    SET @Select = @Select + N'   
                            AND V.ID = '  
                              
                    IF (@VersionFlag_ID IS NOT NULL) BEGIN  
                        SET @Select = @Select + N'   
                             [mdm].[udfModelVersionIDGetbyFlagID](' + CAST(@VersionFlag_ID AS NVARCHAR(50)) + N')'   
                    END  
                    ELSE IF (@Version_ID IS NOT NULL)  
                    BEGIN   
                        SET @Select = @Select + CAST(@Version_ID AS NVARCHAR(50))   
                    END  
                    SET @Select = @Select + @From;  
                      
            END ELSE IF @MemberType_ID = 3 BEGIN --Collection (CN)  
  
                SET @Select = @Select + N'  
                    FROM mdm.' + quotename(@CollectionTable) + N' AS T  
                    INNER JOIN mdm.tblModelVersion V ON V.ID = T.Version_ID AND V.Status_ID <> 0' + @From;  
  
            END ELSE BEGIN --Consolidated (HP)  
  
                SET @Select = @Select + N'  
                    FROM mdm.' + quotename(@HierarchyParentTable) + N' AS T  
                    INNER JOIN mdm.tblModelVersion V ON V.ID = T.Version_ID  
                    INNER JOIN mdm.tblHierarchy H ON H.ID = T.Hierarchy_ID' + @From;  
  
            END; --if  
  
            SET @Select = @Select + N'  
                LEFT JOIN mdm.tblModelVersionFlag AS DV ON DV.ID =  V.VersionFlag_ID  
                WHERE T.Status_ID = 1 AND   
                      T.Version_ID = ';  
                         
            IF (@VersionFlag_ID IS NOT NULL) BEGIN  
                SET @Select = @Select + N'   
                     [mdm].[udfModelVersionIDGetbyFlagID](' + CAST(@VersionFlag_ID AS NVARCHAR(50)) + N')';   
            END  
            ELSE IF (@Version_ID IS NOT NULL)  
            BEGIN   
                SET @Select = @Select + CAST(@Version_ID AS NVARCHAR(50));  
            END  
            SET @Select = @Select +N';';  
  
            --PRINT(@Select);  
            EXEC sp_executesql @Select;  
  
        END; --if  
  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
