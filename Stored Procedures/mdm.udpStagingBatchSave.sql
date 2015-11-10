SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
--Status's   
All = 0,  
QueuedToRun = 1,  
NotRunning =2,  
Running=3,  
QueuedToClear=4,  
Cleared=5  
  
--truncate table mdm.tblStgBatch  
--create  
declare @return_id int  
exec mdm.udpStagingBatchSave 1, 1,null, 'Batch1', NULL, 1,null,null,null, @return_id output  
SELECT * FROM mdm.tblStgBatch  
  
--update the name  
exec mdm.udpStagingBatchSave 1, @return_id,null, 'Batch1-1', null,1,null,null,null, @return_id output  
SELECT * FROM mdm.tblStgBatch  
  
--update the status and set to running  
exec mdm.udpStagingBatchSave 1, @return_id,null, 'Batch1-1', null,2,null,null,null, @return_id output  
SELECT * FROM mdm.tblStgBatch  
  
--update the status and set to finished and update counts  
exec mdm.udpStagingBatchSave 1, @return_id,null, 'Batch1-1', null,3,100,1000,200, @return_id output  
SELECT * FROM mdm.tblStgBatch  
  
--Create new one and link to other batch  
exec mdm.udpStagingBatchSave 1, NULL,@return_id, 'Batch1-1-part2', '1', 1, @return_id output  
SELECT * FROM mdm.tblStgBatch  
*/  
  
CREATE PROCEDURE [mdm].[udpStagingBatchSave]  
(  
    @UserID							INT,   
    @VersionID						INT = NULL, -- BatchID or VersionID are required (but both are never required),   
    @BatchID						INT = NULL,   
    @OriginalBatchID				INT = NULL,  
    @Name							NVARCHAR(50) = NULL,   
    @ExternalSystemID				INT = NULL, 	  
    @StatusID						INT,  
    @BatchTag						NVARCHAR(60) = NULL,   
    @EntityID						INT = NULL,  
    @MemberTypeID					INT = NULL,  
    @TotalMemberCount				INT = NULL,  
    @TotalMemberAttributeCount		INT = NULL,  
    @TotalMemberRelationshipCount	INT = NULL,  
    @ErrorMemberCount				INT = NULL,  
    @ErrorMemberAttributeCount		INT = NULL,  
    @ErrorMemberRelationshipCount	INT = NULL,  
    @ReturnID						INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
  
    SET NOCOUNT ON  
      
    --Batch or Version are required	  
    IF @VersionID IS NULL AND @BatchID IS NULL BEGIN  
        RAISERROR('MDSERR310050|Specify either a batch ID or a version ID.', 16, 1);  
        RETURN;  
    END;  
      
    IF @BatchID IS NOT NULL BEGIN  
        UPDATE	  
            mdm.tblStgBatch  
        SET		  
            [Name] = ISNULL(@Name,[Name]),  
            ExternalSystem_ID = ISNULL(@ExternalSystemID,ExternalSystem_ID),  
            OriginalBatch_ID = ISNULL(@OriginalBatchID,OriginalBatch_ID),  
            Status_ID = ISNULL(@StatusID,Status_ID),  
            BatchTag = ISNULL(@BatchTag,BatchTag),  
            Entity_ID = ISNULL(@EntityID,Entity_ID),  
            MemberType_ID = ISNULL(@MemberTypeID,MemberType_ID),  
            LastRunStartUserID = CASE WHEN @StatusID = 2 THEN @UserID ELSE LastRunStartUserID end,  
            LastRunStartDTM = CASE WHEN @StatusID = 2 THEN GETUTCDATE() ELSE LastRunStartDTM end,  
            LastRunEndUserID = CASE WHEN @StatusID IN (3,4) THEN @UserID ELSE LastRunEndUserID end,  
            LastRunEndDTM = CASE WHEN @StatusID IN (3,4) THEN GETUTCDATE() ELSE LastRunEndDTM end,  
            TotalMemberCount = ISNULL(@TotalMemberCount,TotalMemberCount),  
            TotalMemberAttributeCount = ISNULL(@TotalMemberAttributeCount,TotalMemberAttributeCount),  
            TotalMemberRelationshipCount = ISNULL(@TotalMemberRelationshipCount,TotalMemberRelationshipCount),  
            ErrorMemberCount = ISNULL(@ErrorMemberCount,ErrorMemberCount),  
            ErrorMemberAttributeCount = ISNULL(@ErrorMemberAttributeCount,ErrorMemberAttributeCount),  
            ErrorMemberRelationshipCount = ISNULL(@ErrorMemberRelationshipCount,ErrorMemberRelationshipCount)  
        WHERE	  
            ID = @BatchID  
  
        SELECT @ReturnID = @BatchID  
          
        IF @StatusID = 4 BEGIN -- In case when the status is set to "QueuedToClear"  
            -- Clear error detail table records.  
            DELETE FROM mdm.tblStgErrorDetail WHERE Batch_ID = @BatchID;  
        END; -- IF	  
          
    END  
  
    ELSE BEGIN  
        INSERT INTO mdm.tblStgBatch   
        (OriginalBatch_ID  
        ,MUID  
        ,Version_ID  
        ,ExternalSystem_ID  
        ,[Name]  
        ,Status_ID  
        ,BatchTag  
        ,Entity_ID  
        ,MemberType_ID  
        ,TotalMemberCount  
        ,ErrorMemberCount  
        ,TotalMemberAttributeCount  
        ,ErrorMemberAttributeCount  
        ,TotalMemberRelationshipCount  
        ,ErrorMemberRelationshipCount  
        ,LastRunStartDTM  
        ,LastRunStartUserID  
        ,LastRunEndDTM  
        ,LastRunEndUserID  
        ,LastClearedDTM  
        ,LastClearedUserID  
        ,EnterDTM  
        ,EnterUserID)  
        SELECT	  
            @OriginalBatchID,  
            NEWID(),  
            @VersionID,  
            @ExternalSystemID, 			  
            @Name, 		  
            @StatusID,  
            @BatchTag,  
            @EntityID,  
            @MemberTypeID,  
            NULL,  
            NULL,  
            NULL,  
            NULL,  
            NULL,   
            NULL,  
            NULL,  
            NULL,  
            NULL,  
            NULL,   
            NULL,  
            NULL,  
            GETUTCDATE(),   
            @UserID  
  
        SELECT @ReturnID = SCOPE_IDENTITY()  
          
    END -- IF	  
END; --proc
GO
