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
CREATE VIEW [mdm].[viw_EntityStagingBatchesAllProcessed]  
AS  
    SELECT  
        Batch.ID                AS Batch_ID,  
        Batch.BatchTag          AS BatchTag,  
        Batch.Entity_ID         AS Entity_ID,  
        Batch.MemberType_ID     AS MemberTypeID,  
        V.MUID                  AS Version_MUID,  
        V.Name                  AS VersionName,  
        Batch.Status_ID         AS [Status],  
        Batch.LastRunStartDTM   AS ProcessStart,  
        Batch.LastRunEndDTM     AS ProcessEnd,  
        Batch.LastRunStartUserID AS ProcessUserID,  
        Batch.TotalMemberCount  AS TotalRows,  
        Batch.ErrorMemberCount  AS RowsInError,  
        M.ID AS Model_ID  
    FROM  
        mdm.tblStgBatch                 AS Batch  
        INNER JOIN mdm.tblModelVersion  AS V   
            ON V.ID=Batch.Version_ID    
        INNER JOIN mdm.tblModel         AS M  
            ON M.ID=V.Model_ID    
    WHERE  
    -- Return only records that are from the new entity staging process  
        (Entity_ID IS NOT NULL) AND  
        (MemberType_ID IS NOT NULL)
GO
