SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpEntityStagingFlagForClearing]  
	@Batch_ID       INT,  
    @UserID         INT  
WITH EXECUTE AS 'mds_schema_user'  
AS  
BEGIN  
    DECLARE  
		@QueuedToRun				INT = 1,  
 		@Running					INT = 3,  
  		@QueueToClear				INT = 4,  
 		@Cleared					INT = 5,  
        @IsInvalidState             BIT = 1  
  
    SELECT   
        @IsInvalidState =  
        CASE  
            WHEN (Status_ID IN (@Running, @QueuedToRun, @Cleared)) THEN     1  
            ELSE                                                            0  
        END  
    FROM  
        mdm.tblStgBatch  
    WHERE  
        ID = @Batch_ID  
  
    -- No need to update batch information if it is currently queued to run or running or already cleared  
    IF (@IsInvalidState = 1)  
    BEGIN  
        RAISERROR('MDSERR310029|The status of the specified batch is not valid.', 16, 1);  
        RETURN;    			  
    END -- IF  
  
  
    EXEC	[mdm].[udpStagingBatchSave]  
		        @UserID = @UserID,  
		        @StatusID = @QueueToClear,  
                @BatchID = @Batch_ID  
  
END;
GO
