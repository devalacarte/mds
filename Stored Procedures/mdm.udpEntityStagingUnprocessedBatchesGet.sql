SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
-- Returns information about batches found in the staging tables of all entities  
-- in the given model  
CREATE PROCEDURE [mdm].[udpEntityStagingUnprocessedBatchesGet]  
(  
    @Model_ID                    INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
  
    DECLARE @BatchStatusQueuedToRun INT = 1,  
            @BatchStatusNotRunning  INT = 2,  
            @BatchStatusRunning     INT = 3,  
            @StatusDefault          INT = 0,  
            @LeafMemberType         INT = 1,  
            @ConsolidatedMemberType INT = 2,  
            @HierarchyMemberType    INT = 4;  
              
    DECLARE @entities TABLE  
    (  
        RowNumber               INT IDENTITY(1,1)   NOT NULL,  
        Entity_MUID             UNIQUEIDENTIFIER    NOT NULL,  
        StagingLeafTable        NVARCHAR(128),  
        StagingConsolidatedTable    NVARCHAR(128),  
        StagingRelationshipTable    NVARCHAR(128)  
    )  
  
    CREATE TABLE #batchTagResults  
    (  
        BatchTag                NVARCHAR(50)        COLLATE DATABASE_DEFAULT NOT NULL,  
        [Status]                TINYINT             NOT NULL,  
        MemberTypeID            INT                 NOT NULL,  
        Entity_MUID             UNIQUEIDENTIFIER    NOT NULL,  
        MemberCount             INT                 NOT NULL  
    )  
      
    -- Get a list of all entities that belong to the model  
    INSERT INTO @entities (Entity_MUID, StagingLeafTable, StagingConsolidatedTable, StagingRelationshipTable)  
    SELECT  
        MUID                    AS Entity_MUID,  
        StagingLeafTable,  
        StagingConsolidatedTable,  
        StagingRelationshipTable  
    FROM  
        mdm.viw_SYSTEM_SCHEMA_ENTITY  
    WHERE  
        Model_ID = @Model_ID  
  
    DECLARE     
        @Entity_MUID            UNIQUEIDENTIFIER,  
        @StagingLeafTable       SYSNAME,  
        @StagingConsolidatedTable   SYSNAME,  
        @StagingRelationshipTable    SYSNAME,    
        @SQLPrefix              NVARCHAR(MAX),  
        @SQLSuffix              NVARCHAR(MAX),  
        @SQL                    NVARCHAR(MAX)  
      
    -- Query that for a given staging table returns all the distinct batch tags found. In case the same batch  
    -- tag has multiple statuses return the MAX of them, as we don't care about the exact status, just to know  
    -- if it is in progress or not.  
        SET @SQLPrefix = N'  
        INSERT INTO #batchTagResults  
        SELECT  
            DISTINCT(BatchTag)      AS BatchTag,  
            MAX(ImportStatus_ID)    AS Status,  
            @MemberTypeID           AS MemberTypeID,  
            @Entity_MUID            AS Entity_MUID,  
            COUNT(BatchTag)         AS MemberCount  
        FROM  
        ';  
    SET @SQLSuffix = N'  
        WHERE      
            BatchTag IS NOT NULL AND  
            Batch_ID IS NULL  
        GROUP BY  
            BatchTag  
        ';  
  
    -- Loop through all the entities that belong to this model and store in the temp table all the  
    -- batch tags found in the staging tables (both leaf and consolidated)  
    DECLARE @Counter    INT     = 1,    
            @MaxCounter INT     = (SELECT MAX(RowNumber) FROM @entities);    
      
    WHILE @Counter <= @MaxCounter    
        BEGIN    
            SELECT TOP 1    
                @Entity_MUID            = Entity_MUID,  
                @StagingLeafTable       = StagingLeafTable,  
                @StagingConsolidatedTable = StagingConsolidatedTable,  
                @StagingRelationshipTable = StagingRelationshipTable    
            FROM @entities    
            WHERE RowNumber = @Counter;    
          
            -- Get batches from the leaf table (always exists)  
            SET @SQL = @SQLPrefix + N'stg.' + QUOTENAME(@StagingLeafTable) + @SQLSuffix  
            EXEC sp_executesql @SQL, N'@Entity_MUID UNIQUEIDENTIFIER, @MemberTypeID INT', @Entity_MUID, @LeafMemberType  
  
            -- If the consolidated table exists (i.e. a consolidated member), get the batch tags in it  
            IF @StagingConsolidatedTable IS NOT NULL  
            BEGIN  
                SET @SQL = @SQLPrefix + N'stg.' + QUOTENAME(@StagingConsolidatedTable) + @SQLSuffix  
                EXEC sp_executesql @SQL, N'@Entity_MUID UNIQUEIDENTIFIER, @MemberTypeID INT', @Entity_MUID, @ConsolidatedMemberType  
            END -- IF  
              
            -- If the relationship table exists (a hierarchy member), get the batch tags in it    
            IF @StagingRelationshipTable IS NOT NULL    
            BEGIN    
                SET @SQL = @SQLPrefix + N'stg.' + QUOTENAME(@StagingRelationshipTable) + @SQLSuffix    
                EXEC sp_executesql @SQL, N'@Entity_MUID UNIQUEIDENTIFIER, @MemberTypeID INT', @Entity_MUID, @HierarchyMemberType    
            END -- IF  
              
            SET @Counter += 1;    
        END  -- WHILE  
    
  -- Use "group by" clause to return the distinct batch tags for each member type and entity ID.  
  -- To avoid showing duplicated lines for the same batch process, don't include batch processes   
  -- if the status in tblStgBatch is QueuedToRun or Running and import status is 0.  
    
    SELECT   
        BatchTag                AS BatchTag,  
        @BatchStatusNotRunning  AS [Status],  
        MemberTypeID            AS MemberTypeID,  
        Entity_MUID             AS Entity_MUID,  
        MemberCount             AS MemberCount  
    FROM   
        #batchTagResults   
    WHERE   
        NOT (BatchTag IN (SELECT BatchTag FROM mdm.tblStgBatch WHERE Status_ID IN (@BatchStatusQueuedToRun, @BatchStatusRunning))   
        AND [Status] = @StatusDefault)  
    GROUP BY  
        BatchTag,  
        [Status],  
        MemberTypeID,  
        Entity_MUID,  
        MemberCount  
          
    -- Remove the temporary table  
    DROP TABLE #batchTagResults;    
END; -- PROC
GO
