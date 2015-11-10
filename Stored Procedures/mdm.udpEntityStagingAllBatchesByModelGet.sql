SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
-- This SProc returns two tables:  
-- 1. The amount of batches that would have returned if there was no paging  
-- 2. Returns all the processed and unprocessed batches and their summary information  
-- in a specific model  
-- It does this using the view on all batches in the system with an ID  
-- and the SProc that gets all the batch tags in the staging tables.  
-- The results are sorted first by uncompleted batches, and then by the ProcessEnd date  
--  
-- This SPRoc allows for filtering based on model and should/should not include  
-- batches that have been marked as cleared, as well as paging support.  
-- Example run:  
-- EXEC mdm.udpEntityStagingAllBatchesByModelGet @Model_ID=2  
-- Example output:  
/*  
--Table[0]  
3  
--Table[1]  
1    4    ThirdTag_DifferentEntity    21    Function    2    3    Version 2    2    2010-11-02 01:26:34.870    2010-11-02 01:26:36.727    1    0  
2    3    SecondTag                    20    Department    2    4    Version 3    2    2010-11-02 01:26:29.340    2010-11-02 01:26:33.483    0    0  
3    2    MyBatchTag                    20    Department    2    4    Version 3    2    2010-11-02 01:04:28.510    2010-11-02 01:04:33.317    0    0  
*/   
CREATE PROCEDURE [mdm].[udpEntityStagingAllBatchesByModelGet]  
(  
    @Model_ID               INT,  
    @IncludeClearedBatches  BIT = 0,  
    @PageNumber             INT = 1,  
    @PageSize               INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    -- Stage temporary results received from the different data inputs into this table  
    DECLARE @results TABLE  
    (  
        RowNumber           INT IDENTITY(1,1)       NOT NULL,  
        Batch_ID            INT                     NULL,  
        BatchTag            NVARCHAR(50)            NOT NULL,  
        Entity_MUID         UNIQUEIDENTIFIER        NOT NULL,  
        MemberTypeID        INT                     NULL,  
        Version_MUID        UNIQUEIDENTIFIER        NULL,  
        VersionName         NVARCHAR(250)           NULL,  
        [Status]            TINYINT                 NOT NULL,  
        ProcessStart        DATETIME                NULL,  
        ProcessEnd          DATETIME                NULL,  
        -- HasCompletedDate column will help sort the results first by those  
        -- that are not yet completed (NULL ProcessEnd field) and then those that are  
        HasCompletedDate    BIT                        NOT NULL,  
        MemberCount         INT                     DEFAULT 0,  
        RowsInError         INT                     DEFAULT 0,  
        ErrorView           NVARCHAR(MAX)           NULL,  
        StagingTable        sysname                 NULL  
    )  
  
    DECLARE @unprocessedBatches TABLE  
    (  
        BatchTag        NVARCHAR(50)        NOT NULL,  
        [Status]        TINYINT             NOT NULL,  
        MemberTypeID    INT                 NOT NULL,  
        Entity_MUID     UNIQUEIDENTIFIER    NOT NULL,  
        MemberCount     INT                 NOT NULL  
    )  
  
    DECLARE  
        --Member Types (Constant)  
        @MemberType_Leaf                INT = 1,  
        @MemberType_Consolidated        INT = 2,  
        @MemberType_Hierarchy           INT = 4,  
  
        -- Counters for loop  
        @Counter                INT = 1,    
        @MaxCounter             INT,  
        -- Used in the loop to store temporary batch information  
        @CountedBatch_ID        INT,  
        @CountedStagingTable    sysname,  
        @SQL                    NVARCHAR(MAX),  
        @MemberCount            INT,  
      
        -- Paging Information  
        @StartRow   INT,  
        @LastRow    INT  
  
    -- Get the "processed" batches and insert into temporary results table  
    INSERT INTO @results  
    (  
        Batch_ID,  
        BatchTag,  
        Entity_MUID,  
        MemberTypeID,  
        Version_MUID,  
        VersionName,  
        [Status],  
        ProcessStart,  
        ProcessEnd,  
        HasCompletedDate,  
        MemberCount,  
        RowsInError,  
        ErrorView,  
        StagingTable  
    )  
    SELECT  
        Batch_ID,  
        BatchTag,  
        MUID AS Entity_MUID,  
        MemberTypeID,  
        Version_MUID,  
        VersionName,  
        [Status],  
        ProcessStart,  
        ProcessEnd,  
        CASE   
                WHEN ProcessEnd IS NULL THEN    0  
                ELSE                            1  
        END,  
        TotalRows,  
        RowsInError,  
        CASE     
                WHEN (MemberTypeID = @MemberType_Hierarchy) THEN N'SELECT * from [stg].' + QUOTENAME(N'viw_' + Entity.StagingBase  + N'_RelationshipErrorDetails') + ' WHERE Batch_ID = ' + CAST(Batch.Batch_ID AS NVARCHAR(MAX))  
                ELSE                                             N'SELECT * from [stg].' + QUOTENAME(N'viw_' + Entity.StagingBase  + N'_MemberErrorDetails') + ' WHERE Batch_ID = ' + CAST(Batch.Batch_ID AS NVARCHAR(MAX))  
        END,  
        CASE  
                WHEN (MemberTypeID = @MemberType_Consolidated)  THEN    N'stg.' + QUOTENAME(Entity.StagingConsolidatedTable)  
                WHEN (MemberTypeID = @MemberType_Hierarchy)     THEN    N'stg.' + QUOTENAME(Entity.StagingRelationshipTable)  
                ELSE                                                    N'stg.' + QUOTENAME(Entity.StagingLeafTable)  
        END  
    FROM  
        mdm.viw_EntityStagingBatchesAllProcessed    AS Batch  
    JOIN mdm.viw_SYSTEM_SCHEMA_ENTITY               AS Entity  
        ON (Batch.Entity_ID = Entity.ID)  
    WHERE   
        Batch.Model_ID = @Model_ID AND  
        -- Filter out "cleared" batches if the IncludeClearedBatches is false  
        ((@IncludeClearedBatches = 1) OR ([Status] != 5))   
  
    -- If the member count is not set (the timing between inserting a record to tblStgBatch and setting   
    -- the member count), count the members of the batch tag and update the count into the @results table.  
    SET @MaxCounter = (SELECT MAX(RowNumber) FROM @results)  
  
    WHILE @Counter <= @MaxCounter    
        BEGIN    
            SELECT TOP 1    
                @CountedBatch_ID = Batch_ID,  
                @CountedStagingTable = StagingTable,  
                @MemberCount = MemberCount  
            FROM @results    
            WHERE RowNumber = @Counter  
  
            IF ISNULL(@MemberCount, 0) = 0 -- The member count has not been set.   
            BEGIN  
                SET @SQL = N'  
                    SELECT  
                        @MemberCount = COUNT(*)  
                    FROM  
                        ' + @CountedStagingTable + '  
                    WHERE  
                        Batch_ID = ' + CAST(@CountedBatch_ID AS NVARCHAR(MAX)) + '  
                '  
  
                exec sp_executesql @SQL,  N'@MemberCount INT OUTPUT', @MemberCount OUTPUT;  
  
                UPDATE  
                    @results  
                SET  
                    MemberCount = @MemberCount  
                WHERE  
                    Batch_ID = @CountedBatch_ID  
  
            END; --IF  
  
            SET @Counter = @Counter + 1  
  
        END -- WHILE  
      
    -- Get all the unprocessed batches and put into this variable table.  
    -- An unprocessed batch, meaning one we only found in the staging tables  
    -- but not in the tblStgBatch table, will only have basic information  
    INSERT INTO @unprocessedBatches EXEC mdm.udpEntityStagingUnprocessedBatchesGet @Model_ID  
  
    -- Take the results from both queries and combine them into the @results table  
    -- To allow users to reuse batch tags don't merge the results based on the batch tag.   
    INSERT   
        INTO @results   
        (BatchTag,   
        [Status],   
        Entity_MUID,   
        MemberTypeID,   
        HasCompletedDate,   
        MemberCount)  
        SELECT BatchTag,   
            [Status],   
            Entity_MUID,   
            MemberTypeID,   
            0,   
            MemberCount  
        FROM @unprocessedBatches;  
      
    ---- All "unprocessed" batches by definition don't have a complete date, as they haven't even started.  
    
    -- In first datatable, return the amount of batches that would have returned if there was no paging  
    SELECT  
        COUNT(*)    AS  BatchCount  
    FROM  
        @results  
  
    -- Set paging variables  
    -- Set defaults for invalid arguments for paging. (Which gets all records)  
    IF @PageSize < 1 SET @PageSize = NULL  
    IF @PageNumber < 1 SET @PageNumber = 1  
    -- The first and last row (inclusive) to return  
    IF (@PageSize IS NOT NULL)  
    BEGIN  
        SET @StartRow = (@PageNumber - 1) * (@PageSize);    
        SET @LastRow = @StartRow + @PageSize - 1  
    END  
  
    -- In the second datatable return the batches' information  
    -- Use an inner select query to order the rows, give them a unique row_number, and then page  
    -- the results using this number  
    SELECT *  
    FROM  
    (  
        SELECT  
            -- Give each row a unique number. First the ones that don't have a completed date, then the last ones to finish  
            Row_Number() OVER(ORDER BY HasCompletedDate ASC, ProcessEnd DESC) AS RowIndex,  
            Batch_ID,  
            BatchTag,  
            Entity_MUID,  
            Entity.Name AS EntityName,  
            MemberTypeID,  
            Version_MUID,  
            VersionName,  
            [Status],  
            ProcessStart,  
            ProcessEnd,  
            RowsInError,  
            MemberCount,  
            ErrorView  
        FROM  
            @results AS Batch  
        INNER JOIN  mdm.tblEntity AS Entity  
            ON Batch.Entity_MUID = Entity.MUID  
    ) AS ResultSet  
    WHERE  
        (@PageSize IS NULL) OR  
        (ResultSet.RowIndex BETWEEN @StartRow AND @LastRow)  
END -- PROC
GO
