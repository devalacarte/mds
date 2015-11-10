SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
-- Returns all the staging batches that are in the tblStgBatch table  
-- (and thus have at least started being processed by the system)  
-- AND that have not been marked as "cleared"  
CREATE VIEW [mdm].[viw_EntityStagingBatchesAllProcessedExceptCleared]  
AS	  
    SELECT  
        *  
    FROM  
        mdm.viw_EntityStagingBatchesAllProcessed  
    WHERE  
        [Status] != 5 -- Cleared
GO
