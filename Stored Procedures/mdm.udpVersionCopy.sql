SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
--TEST SCRIPT  
    EXEC mdm.udpSystemSettingSave 1,'CopyOnlyCommittedVersion', '0'  --don't require committed versions to copy  
    DECLARE @P1 int, @P2 UNIQUEIDENTIFIER;  
    DECLARE @x NVARCHAR(50) = NEWID();  
      
  
    --Recursively copy versions N times. If you want to copy the same version  
    -- each time just replace the second @v OUTPUT param below with null.  
    DECLARE @v INT = 23;  
    DECLARE @i INT = 0;  
    WHILE (@i < 1) BEGIN      
        SELECT @x = NEWID();  
        EXEC mdm.udpVersionCopy 1, @v, @x, @x, @v OUTPUT,null,1;  
        PRINT @v;  
        SET @i += 1;  
    END; --while  
      
    SELECT * FROM mdm.tblModelVersion  
      
    EXEC mdm.udpSystemSettingSave 1,'CopyOnlyCommittedVersion', '1'  --reset required committed versions to copy  
*/  
CREATE PROCEDURE [mdm].[udpVersionCopy]  
(  
    @User_ID            INT,  
    @Version_ID         INT,  
    @VersionName        NVARCHAR(50),  
    @VersionDescription NVARCHAR(250),  
    @Return_ID          INT = NULL OUTPUT,  
    @Return_MUID        UNIQUEIDENTIFIER = NULL OUTPUT,  
    @Debug              BIT = 0  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @Model_ID                   INT,  
            @NewVersion_ID              INT,  
            @NewVersion_MUID            UNIQUEIDENTIFIER,  
            @Entity_ID                  INT,  
            @Attribute_ID               INT,  
            @DomainTable                sysname,  
            @IsSystem                   BIT,  
            @MemberType_ID              INT,  
            @TableName                  sysname,  
            @TableNameEN                sysname,  
            @TableNameHP                sysname,  
            @TableNameCN                sysname,  
            @TableNameHR                sysname,  
            @TableNameCM                sysname,  
            @ViewColumn                 sysname,  
            @TableColumn                sysname,  
            @SQL                        NVARCHAR(MAX),  
            @From                       NVARCHAR(MAX),  
            @Insert                     NVARCHAR(MAX),  
            @CRLF                       NVARCHAR(MAX),  
            @CopyNbr                    INT,  
            @CopyOnlyCommittedVersion   NVARCHAR(250),  
            @SourceVersionStatusID      NVARCHAR(50),  
            @SourceVersionName          NVARCHAR(50),  
            @SourceVersionDesc          NVARCHAR(500);  
DECLARE     @UpdateScripts              TABLE([ID] INT IDENTITY(1,1), [SQL] NVARCHAR(MAX));  
  
    SELECT  
        @SourceVersionStatusID = Status_ID,  
        @SourceVersionName = [Name],  
        @SourceVersionDesc = [Description]  
    FROM mdm.tblModelVersion   
    WHERE ID = @Version_ID;  
  
    --If CopyOnlyCommittedVersion is turned on then verify that the version is committed.  
    EXEC mdm.udpSystemSettingGet N'CopyOnlyCommittedVersion', @CopyOnlyCommittedVersion OUTPUT;  
    IF CONVERT(INT, @CopyOnlyCommittedVersion) = 1 AND CONVERT(INT, @SourceVersionStatusID) <> 3 BEGIN  
        --On error, return NULL results  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RAISERROR('MDSERR200062|The version cannot be copied. Only committed versions can be copied.', 16, 1);  
        RETURN;       
    END; --if  
  
    IF NULLIF(@VersionName, N'') IS NULL BEGIN  
        SELECT @CopyNbr = ISNULL(Count(AsOfVersion_ID), 0) + 1 FROM mdm.tblModelVersion WHERE AsOfVersion_ID = @Version_ID;  
        SET @VersionName = N'Copy (' + CONVERT(NVARCHAR(50), @CopyNbr) + N') of ' +  @SourceVersionName;  
    END; --if  
  
    SET @VersionDescription = ISNULL(NULLIF(@VersionDescription, N''), @SourceVersionDesc);  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        SELECT @Model_ID = Model_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID;  
  
        --Create new version record and get new Version_ID  
        EXEC mdm.udpVersionSave @User_ID, @Model_ID, NULL, @Version_ID, 1, @VersionName, @VersionDescription, NULL, @NewVersion_ID OUTPUT, @NewVersion_MUID OUTPUT;  
  
        --Initialize the return parameters  
        SELECT @Return_ID = @NewVersion_ID, @Return_MUID = @NewVersion_MUID;  
  
        --Temporary table to hold all the entity table names  
        DECLARE @EntityTable TABLE(Entity_ID INT, MemberType_ID INT, TableName sysname, [Level] INT);  
        --Temporary table to hold all the attribute names  
        DECLARE @AttributeTable TABLE(Attribute_ID INT, AttributeName sysname, TableColumn sysname, DomainTable sysname NULL, IsSystem BIT NOT NULL);  
  
        --Need to copy data in the right order so as to not violate FKs  
        INSERT INTO @EntityTable   
        SELECT Entity_ID, MemberType_ID, TableName, [Level]   
        FROM mdm.udfEntityDependencyTree(@Model_ID, NULL);  
  
        --Loop through the member tables  
        WHILE EXISTS(SELECT 1 FROM @EntityTable) BEGIN  
  
            SET @SQL = N'';  
  
            SELECT TOP 1   
                @Entity_ID = Entity_ID,  
                @MemberType_ID = MemberType_ID,  
                @TableName = TableName  
            FROM @EntityTable          
            ORDER BY [Level] ASC; --Copy tables in correct dependency order  
      
            SELECT   
                @TableNameEN = EntityTableName,                --EN (1)  
                @TableNameHP = HierarchyParentTableName,    --HP (2)  
                @TableNameCN = CollectionTableName,            --CN (3)  
                @TableNameHR = HierarchyTableName,            --HR (4)  
                @TableNameCM = CollectionMemberTableName    --CM (5)  
                --No need to copy MS (6) since we regenerate it from scratch  
            FROM   
                [mdm].[viw_SYSTEM_TABLE_NAME]  
            WHERE ID = @Entity_ID;  
  
            --Mapping foreign keys seems faster via (stage + UPDATE + INSERT) than (JOIN + direct INSERT)  
            --This is likely due to the large number of constraints (especially FKs) in the member tables  
            --Note that SELECT INTO also uses the source collations in the destination temporary table      
            IF @MemberType_ID IN (1, 2, 3) BEGIN --EN, HP, CN  
              
                --Get the list of Attributes in the current Entity  
                INSERT INTO @AttributeTable(Attribute_ID, AttributeName, TableColumn, DomainTable, IsSystem)  
                SELECT a.ID, a.[Name], a.TableColumn, d.EntityTable, a.IsSystem  
                FROM mdm.tblAttribute AS a   
                LEFT JOIN mdm.tblEntity AS d ON (a.DomainEntity_ID = d.ID)  
                WHERE Entity_ID = @Entity_ID AND MemberType_ID = @MemberType_ID  
                AND a.ID NOT IN   
                    ( --Cannot insert into system and/or computed columns  
                        SELECT ID FROM mdm.tblAttribute   
                        WHERE IsSystem = 1  
                        AND TableColumn IN (N'ID', N'Status_ID', N'EnterDTM', N'LastChgTS', N'MUID')  
                    );  
  
                --Loop through each Attribute  
                SELECT @Insert = N'', @From = N'', @CRLF = N' ';                  
                WHILE EXISTS(SELECT 1 FROM @AttributeTable) BEGIN  
                  
                    SELECT TOP 1   
                        @Attribute_ID = Attribute_ID,  
                        @ViewColumn = AttributeName,  
                        @TableColumn = TableColumn,  
                        @DomainTable = DomainTable,  
                        @IsSystem = IsSystem  
                    FROM @AttributeTable  
                    ORDER BY Attribute_ID; --Sort is useful for debugging purposes only  
                                          
                    --Copy all columns verbatim except DBAs which we will map later  
                    IF (@IsSystem = 1 OR @DomainTable IS NULL) BEGIN  
                      
                        SET @Insert +=  
                            @CRLF +   
                            quotename(@TableColumn) +  
                            CASE @IsSystem  
                                WHEN 0 THEN N' --' + quotename(@ViewColumn) --Comment makes debugging easier  
                                ELSE N''  
                            END; --case  
                              
                        SET @From +=  
                            @CRLF +  
                            CASE @IsSystem  
                                WHEN 0 THEN quotename(@TableColumn) + N' --' -- + quotename(@ViewColumn) --Comment makes debugging easier  
                                ELSE CASE @TableColumn  
                                    WHEN N'ValidationStatus_ID' THEN N'CASE WHEN ValidationStatus_ID = 2 THEN 4 ELSE ValidationStatus_ID END AS '  
                                    WHEN N'AsOf_ID' THEN N'ID AS ' --Copy old ID value into AsOf_ID column  
                                    WHEN N'Version_ID' THEN N'@NewVersion_ID AS ' --Hard-code new version  
                                    WHEN N'LastChgDTM' THEN N'LastChgDTM AS '  
                                    WHEN N'LastChgUserID' THEN N'@User_ID AS ' --Hard code user  
                                    WHEN N'LastChgVersionID' THEN N'@NewVersion_ID AS ' --Hard code new version  
                                    ELSE N'' --Use old value for all other columns  
                                END + --case  
                                quotename(@TableColumn)  
                            END; --case  
                          
                    --If the current Attribute is a DBA                                                    
                    END ELSE BEGIN  
                                      
                        --If we are copying a domain-based attribute (DBA) then map pointer to new key value using an UPDATE  
                        INSERT INTO @UpdateScripts ([SQL])  
                        SELECT  
                        N'  
                        UPDATE new SET ' + quotename(@TableColumn) + N' = dba.ID  
                        FROM mdm.' + quotename(@TableName) + N' AS old  
                        INNER JOIN mdm.' + quotename(@TableName) + N' AS new ON (old.Version_ID = @Version_ID AND old.ID = new.AsOf_ID)  
                        INNER JOIN mdm.' + quotename(@DomainTable) + N' AS dba ON (new.Version_ID = dba.Version_ID AND old.' + quotename(@TableColumn) + N' = dba.AsOf_ID)  
                        WHERE new.Version_ID = @NewVersion_ID AND old.' + quotename(@TableColumn) + N' IS NOT NULL AND old.Status_ID = 1  
                        ;';  
                          
                    END; --if  
                      
                    --After very first iteration, we need a comma (& newline) to separate clauses                  
                    SET @CRLF = N'  
                        ,';  
                      
                    --Increment loop counter  
                    DELETE FROM @AttributeTable WHERE Attribute_ID = @Attribute_ID;  
  
                END; --while  
              
                SET @SQL += N'  
                    --Copy mapped data into destination  
                    INSERT INTO mdm.' + quotename(@TableName) + N'  
                    (    
                        ' + @Insert + N'    
                    )     
                    SELECT     
                        ' + @From + N'  
                    FROM mdm.' + quotename(@TableName) + N'  
                    WHERE Version_ID = @Version_ID  
                        AND Status_ID = 1  
                    ;';  
                      
                SET @SQL = @SQL + N'  
                    UPDATE STATISTICS mdm.' + quotename(@TableName) + N';';  
              
            --Since the HR table is much simpler, a direct insert still has good performance  
            END ELSE IF @MemberType_ID = 4 BEGIN --HR  
                DECLARE @hrCTE as NVARCHAR(MAX) = N'  
                        WITH hrCTE AS  
                        (  
                            SELECT  
                                 @NewVersion_ID AS Version_ID  
                                ,hr.Hierarchy_ID  
                                ,pr.ID AS Parent_HP_ID  
                                ,hr.ChildType_ID  
                                ,hr.Child_EN_ID  
                                ,hr.Child_HP_ID  
                                ,hr.SortOrder  
                                ,hr.LevelNumber  
                                ,hr.LastChgDTM  
                                ,hr.EnterUserID  
                                ,hr.EnterVersionID  
                                ,@User_ID AS LastChgUserID  
                                ,@NewVersion_ID AS LastChgVersionID  
                                ,hr.ID AS AsOf_ID  
                            FROM mdm.' + quotename(@TableNameHR) + N' AS hr  
                            LEFT JOIN mdm.' + quotename(@TableNameHP) + N' AS pr  
                                ON (pr.Version_ID = @NewVersion_ID  
                                    AND hr.Parent_HP_ID IS NOT NULL AND hr.Parent_HP_ID = pr.AsOf_ID  
                                    AND pr.Status_ID = 1)  
                            WHERE  
                                hr.Version_ID = @Version_ID   
                                AND hr.Status_ID = 1  
                        )';  
                DECLARE @enCTE AS NVARCHAR(MAX) = N'                          
                        , enCTE AS  
                        (  
                            SELECT   
                                hr.Version_ID  
                                ,hr.Hierarchy_ID  
                                ,hr.Parent_HP_ID  
                                ,hr.ChildType_ID  
                                ,fk.ID AS Child_EN_ID          
                                ,hr.Child_HP_ID                  
                                ,hr.SortOrder  
                                ,hr.LevelNumber  
                                ,hr.EnterUserID  
                                ,hr.EnterVersionID  
                                ,hr.LastChgDTM  
                                ,hr.LastChgUserID  
                                ,hr.LastChgVersionID  
                                ,hr.AsOf_ID  
                                FROM hrCTE hr INNER JOIN mdm.' + quotename(@TableNameEN) + N' fk  
                                ON (fk.AsOf_ID = hr.Child_EN_ID   
                                    AND hr.ChildType_ID = 1  
                                    AND fk.Version_ID = hr.Version_ID  
                                    AND fk.Status_ID = 1)  
                        )';  
                DECLARE @hpCTE AS NVARCHAR(MAX) = N'                          
                        , hpCTE AS  
                        (  
                            SELECT   
                                hr.Version_ID  
                                ,hr.Hierarchy_ID  
                                ,hr.Parent_HP_ID  
                                ,hr.ChildType_ID  
                                ,hr.Child_EN_ID  
                                ,hp.ID AS Child_HP_ID                  
                                ,hr.SortOrder  
                                ,hr.LevelNumber  
                                ,hr.EnterUserID  
                                ,hr.EnterVersionID  
                                ,hr.LastChgDTM  
                                ,hr.LastChgUserID  
                                ,hr.LastChgVersionID  
                                ,hr.AsOf_ID  
                                FROM hrCTE hr INNER JOIN mdm.' + quotename(@TableNameHP) + N' hp  
                                ON (hp.Version_ID = hr.Version_ID  
                                    AND hr.ChildType_ID = 2  
                                    AND hr.Child_HP_ID = hp.AsOf_ID  
                                    AND hp.Status_ID = 1)  
                        )';  
                          
                    SET @SQL = @hrCTE + @enCTE + @hpCTE + N'  
                        INSERT INTO mdm.' + quotename(@TableNameHR) + N'  
                        (  
                             Version_ID  
                            ,Hierarchy_ID  
                            ,Parent_HP_ID  
                            ,ChildType_ID  
                            ,Child_EN_ID  
                            ,Child_HP_ID  
                            ,SortOrder  
                            ,LevelNumber  
                            ,EnterUserID  
                            ,EnterVersionID  
                            ,LastChgDTM  
                            ,LastChgUserID  
                            ,LastChgVersionID  
                            ,AsOf_ID  
                        )   
                        SELECT * FROM enCTE  
                        UNION  
                        SELECT * FROM hpCTE  
                        WHERE --FKs may be NULL if original row was soft-deleted  
                        ISNULL(Child_EN_ID, Child_HP_ID) IS NOT NULL  
                        ;';  
                          
                        --seed HR table with leaf entities on the root for hierarchies that didn't exist in the original version  
                    SET @SQL = @SQL + N'  
                         WITH h AS   
                        (SELECT h.ID from mdm.tblHierarchy AS h  
                            LEFT JOIN ' + @TableNameHR + ' AS hr on h.ID = hr.Hierarchy_ID  
                            AND hr.Version_ID = @NewVersion_ID  
                            WHERE hr.ID IS NULL  
                            AND h.Entity_ID = @Entity_ID  
                            AND h.IsMandatory = 1  
                        )  
                        INSERT INTO mdm.' + quotename(@TableNameHR) + N'  
                        (  
                             Version_ID  
                            ,Hierarchy_ID  
                            ,Parent_HP_ID  
                            ,ChildType_ID  
                            ,Child_EN_ID  
                            ,Child_HP_ID  
                            ,SortOrder  
                            ,LevelNumber  
                            ,EnterUserID  
                            ,EnterVersionID  
                            ,LastChgDTM  
                            ,LastChgUserID  
                            ,LastChgVersionID  
                            ,AsOf_ID  
                        )  
                           
                        SELECT   
                             @NewVersion_ID AS Version_ID  
                            ,h.ID  
                            ,NULL  
                            ,1  
                            ,e.ID  
                            ,NULL  
                            ,e.ID  
                            ,-1  
                            ,e.EnterUserID  
                            ,e.EnterVersionID  
                            ,e.LastChgDTM  
                            ,e.LastChgUserID  
                            ,e.LastChgVersionID  
                            ,NULL  
                         FROM ' + @TableNameEN + N' AS e CROSS JOIN h  
                          WHERE e.Version_ID = @NewVersion_ID  
                          '  
  
                                                  
                              
                    SET @SQL = @SQL + N'  
                        UPDATE STATISTICS mdm.' + quotename(@TableNameHR) + N';';  
  
            --Since the CM table is much simpler, a direct insert still has good performance  
            END ELSE IF @MemberType_ID = 5 BEGIN --CM  
  
                SET @SQL = N'  
                    WITH cte AS  
                    (  
                        SELECT  
                             @NewVersion_ID AS Version_ID                          
                            ,pr.ID AS Parent_CN_ID  
                            ,cm.ChildType_ID  
                            ,en.ID AS Child_EN_ID                          
                            ,hp.ID AS Child_HP_ID  
                            ,cn.ID AS Child_CN_ID  
                            ,cm.SortOrder  
                            ,cm.Weight  
                            ,cm.EnterUserID  
                            ,cm.EnterVersionID  
                            ,cm.LastChgDTM  
                            ,@User_ID AS LastChgUserID  
                            ,@NewVersion_ID AS LastChgVersionID  
                            ,cm.ID AS AsOf_ID  
                        FROM mdm.' + quotename(@TableNameCM) + N' AS cm  
                        INNER JOIN mdm.' + quotename(@TableNameCN) + N' AS pr  
                            ON (pr.Version_ID = @NewVersion_ID  
                                AND cm.Parent_CN_ID = pr.AsOf_ID  
                                AND pr.Status_ID = 1)  
                        LEFT JOIN mdm.' + quotename(@TableNameEN) + N' AS en  
                            ON (en.Version_ID = pr.Version_ID  
                                AND cm.ChildType_ID = 1  
                                AND cm.Child_EN_ID = en.AsOf_ID  
                                AND en.Status_ID = 1)  
                        LEFT JOIN mdm.' + quotename(@TableNameHP) + N' AS hp  
                            ON (hp.Version_ID = pr.Version_ID  
                                AND cm.ChildType_ID = 2  
                                AND cm.Child_HP_ID = hp.AsOf_ID  
                                AND hp.Status_ID = 1)  
                        LEFT JOIN mdm.' + quotename(@TableNameCN) + N' AS cn  
                            ON (cn.Version_ID = pr.Version_ID  
                                AND cm.ChildType_ID = 3  
                                AND cm.Child_CN_ID = cn.AsOf_ID  
                                AND cn.Status_ID = 1)  
                        WHERE  
                            cm.Version_ID = @Version_ID   
                            AND cm.Status_ID = 1  
                    )  
                    INSERT INTO mdm.' + quotename(@TableNameCM) + N'  
                    (  
                         Version_ID  
                        ,Parent_CN_ID  
                        ,ChildType_ID  
                        ,Child_EN_ID  
                        ,Child_HP_ID  
                        ,Child_CN_ID  
                        ,SortOrder  
                        ,Weight  
                        ,EnterUserID  
                        ,EnterVersionID  
                        ,LastChgDTM  
                        ,LastChgUserID  
                        ,LastChgVersionID  
                        ,AsOf_ID  
                    )   
                    SELECT * FROM cte  
                    WHERE --FKs may be NULL if original row was soft-deleted  
                        Parent_CN_ID IS NOT NULL  
                        AND COALESCE(Child_EN_ID, Child_HP_ID, Child_CN_ID) IS NOT NULL  
                    ;';  
                    SET @SQL = @SQL + N'  
                        UPDATE STATISTICS mdm.' + quotename(@TableNameCM) + N';';  
                                          
            END; --if  
            IF @Debug = 1 BEGIN  
                PRINT @TableName + N':Start ' + CONVERT(NVARCHAR(30), GETDATE());  
                PRINT @SQL;  
            END --if debug  
              
            EXEC sp_executesql @SQL,  
                N'@User_ID INT, @Version_ID INT, @NewVersion_ID INT, @Entity_ID INT',  
                @User_ID, @Version_ID, @NewVersion_ID, @Entity_ID;              
              
            IF @Debug = 1 BEGIN  
                PRINT @TableName + N':End ' + CONVERT(NVARCHAR(30), GETDATE());  
            END --if debug  
  
                      
            DELETE FROM @EntityTable WHERE Entity_ID = @Entity_ID AND MemberType_ID = @MemberType_ID;  
              
        END; --while  
          
        --Finally, map all the DBAs only after all new PK values are populated  
        --We need to do this at the very end to cater for recursive derived hierarchies (self-referencing DBAs)  
        DECLARE   
            @ScriptID INT,  
            @StartTime DATETIME;  
  
        WHILE EXISTS(SELECT 1 FROM @UpdateScripts) BEGIN  
            SELECT TOP 1  
                @ScriptID = ID,  
                @SQL = [SQL]  
            FROM @UpdateScripts;  
            DELETE FROM @UpdateScripts WHERE [ID] = @ScriptID;  
            If @Debug = 1 BEGIN  
                PRINT N'Copy DBA #' + CONVERT(NVARCHAR, @ScriptID) + N':Start ' + CONVERT(NVARCHAR(30), GETDATE());  
                PRINT @SQL;  
                SET @StartTime = GETDATE();  
            END  
            EXEC sp_executesql @SQL,   
                N'@User_ID INT, @Version_ID INT, @NewVersion_ID INT, @Entity_ID INT',  
                @User_ID, @Version_ID, @NewVersion_ID, @Entity_ID;  
            If @Debug = 1 BEGIN  
                PRINT N'Copy DBA #' + CONVERT(NVARCHAR, @ScriptID) + N':End in ' + CONVERT(NVARCHAR, DATEDIFF(MS, @StartTime, GETDATE())) + N' ms at ' + CONVERT(NVARCHAR(30), GETDATE());  
            END  
        END   
        --Copy the security records across   
        EXEC mdm.udpSecurityRoleAccessMemberCopy @User_ID = @User_ID, @SourceVersion_ID = @Version_ID, @TargetVersion_ID = @NewVersion_ID, @MapMembersByID = 1;  
                
        --(Re)build the member security (MS) records for the new versions via the queue  
        EXEC mdm.udpSecurityMemberProcessRebuildModelVersion @Version_ID = @NewVersion_ID, @ProcessNow = 1;  
          
        --Commit only if we are not nested  
        IF @TranCounter = 0 COMMIT TRANSACTION;  
        RETURN(0);  
  
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
  
        --On error, return NULL results  
        --SELECT @Return_ID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
