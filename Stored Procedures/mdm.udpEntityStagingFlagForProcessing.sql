SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
-- Creates a new entry in the tblStgBatch table with "QueueToRun" and returns a unique  
-- ID for this batch  
*/  
CREATE PROCEDURE [mdm].[udpEntityStagingFlagForProcessing]  
    @BatchTag           NVARCHAR(50),  
    @UserID             INT,  
    @Entity_ID          INT,  
    @Version_ID         INT,  
    @MemberTypeID       INT  
WITH EXECUTE AS 'mds_schema_user'  
AS  
BEGIN  
  
   DECLARE  
        @ReturnID           INT,  
        @StagingTable       SYSNAME,  
        @SQL                NVARCHAR(MAX),  
        @QueuedToRun        INT = 1,  
        @Running            INT = 3,  
        @IsInvalidState     BIT = 0 -- Default to valid. If the batchtag doesn't exist, it is a perfectly good condition to start one.  
  
    SELECT   
        @IsInvalidState =  
        CASE  
            WHEN (Status_ID IN (@Running, @QueuedToRun)) THEN   1  
            ELSE                                                0  
        END  
    FROM  
        mdm.tblStgBatch  
    WHERE  
        (BatchTag = @BatchTag) AND  
        (Entity_ID = @Entity_ID) AND  
        (Version_ID = @Version_ID) AND  
        (MemberType_ID = @MemberTypeID)  
  
    -- No need to update batch information if it is currently queued to run or running  
    IF (@IsInvalidState = 1)  
    BEGIN  
        RAISERROR('MDSERR310029|The status of the specified batch is not valid.', 16, 1);  
        RETURN;                  
    END -- IF  
  
    EXEC    [mdm].[udpStagingBatchSave]  
                @UserID = @UserID,  
                @VersionID = @Version_ID,  
                @StatusID = @QueuedToRun,  
                @BatchTag = @BatchTag,  
                @EntityID = @Entity_ID,  
                @MemberTypeID = @MemberTypeID,  
                @ReturnID = @ReturnID OUTPUT;  
                  
    -- Update the new batchID in the staging table.  
    SELECT    
        @StagingTable =   
            CASE   
                WHEN @MemberTypeID = 1 THEN -- Leaf member   
                    N'[stg].' + QUOTENAME(StagingBase + N'_Leaf')  
                WHEN @MemberTypeID = 2 THEN -- Consolidated member   
                    N'[stg].' + QUOTENAME(StagingBase + N'_Consolidated')  
                WHEN @MemberTypeID = 4 THEN -- Relationship member   
                    N'[stg].' + QUOTENAME(StagingBase + N'_Relationship')      
            END  
    FROM       
        mdm.tblEntity WHERE ID = @Entity_ID;  
                      
    SET @SQL = N'UPDATE ' + @StagingTable + N'  
                SET Batch_ID = @Batch_ID  
                WHERE IsNULL(BatchTag, N'''') = @BatchTag AND ImportStatus_ID = 0';  
                              
    EXEC sp_executesql @SQL, N'@Batch_ID INT, @BatchTag NVARCHAR(50)', @ReturnID, @BatchTag;  
              
    SELECT    @ReturnID  
END -- Proc
GO
