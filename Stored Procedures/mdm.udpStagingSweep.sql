SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
--This procedure takes all the non-batched records in the staging tables   
--that are for that user OR NO user and the requested version/model and associates them with a batch.  
  
--Example call and it DOES processes the Staging Queue  
EXEC mdm.udpStagingSweep 1,4,1  
  
--Example call and it DOES NOT processes the Staging Queue  
EXEC mdm.udpStagingSweep 1,4,0  
  
--Example call TO ONLY PROCESS the Staging Queue  
EXEC mdm.udpStagingSweep 1,0,0  
  
UPDATE mdm.tblStgMember SET Batch_ID=null  
UPDATE mdm.tblStgMemberAttribute SET Batch_ID=null  
UPDATE mdm.tblStgRelationship SET Batch_ID=null  
  
select * from mdm.tblStgBatch  
select top 1000 * from mdm.tblStgMember  
select top 1000 * from mdm.tblStgMemberAttribute  
select top 1000 * from mdm.tblStgRelationship  
*/  
  
CREATE PROCEDURE [mdm].[udpStagingSweep]  
(  
    @UserID        INT,   
    @VersionID    INT,  
    @Process    TINYINT=0 --If 1 then run staging   
)  
/*WITH*/  
AS BEGIN  
  
    SET NOCOUNT ON  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
      
    BEGIN TRY  
  
        --If a version is provided, create a new batch for the version's unbatched records.  
        IF (COALESCE(@VersionID, 0) > 0) BEGIN  
            DECLARE @BatchName                  NVARCHAR(500),    
                    @UserName                   NVARCHAR(100),    
                    @ModelID                    NVARCHAR(250),    
                    @ModelName                  NVARCHAR(250),    
                    @BatchID                    INT,    
                    @TotalRecordCount           INT,    
                    @MemberCount                INT,    
                    @MemberAttributeCount       INT,    
                    @MemberRelationshipCount    INT,  
                    @VersionStatus_ID           INT,  
                    @VersionStatus_Committed    INT = 3;      
  
            --Get the model associated with the version    
            SELECT @ModelID = Model_ID, @VersionStatus_ID = Status_ID FROM mdm.tblModelVersion WHERE ID = @VersionID;    
  
            --Ensure the user is an administrator of the model.  
            IF NOT EXISTS(SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MODEL WHERE [User_ID] = @UserID AND ID = @ModelID AND IsAdministrator = 1) BEGIN    
                RAISERROR('MDSERR120002|The user does not have permission to perform this operation.', 16, 1);  
                RETURN 1;    
            END;   
   
            --Ensure that Version is not committed  
            IF (@VersionStatus_ID = @VersionStatus_Committed) BEGIN  
                RAISERROR('MDSERR310040|Data cannot be loaded into a committed version.', 16, 1);  
                RETURN 1;      
            END;  
              
            --Get the UserId    
            SET @UserName = mdm.udfUserNameGetByUserID(@UserID);    
            SET @ModelName = UPPER(LTRIM(RTRIM((SELECT Name FROM mdm.tblModel WHERE ID = @ModelID))));    
            SET @BatchName = @ModelName + N'_Unbatched';    
            SET @TotalRecordCount = 0;    
  
            --Get the amount of unbatched records that meet the criteria.  
            --This check is here because if there are no records there is no need to create a batch or do anything..  
            SELECT  
                @TotalRecordCount = @TotalRecordCount + COUNT(*)   
            FROM  
                mdm.tblStgMember  
            WHERE  
                Batch_ID IS NULL  
                AND UPPER(LTRIM(RTRIM(ModelName))) = @ModelName  
                AND @UserName = COALESCE(NULLIF(LTRIM(RTRIM(UserName)), N''), @UserName)  
  
            SELECT  
                @TotalRecordCount = @TotalRecordCount + COUNT(*)   
            FROM  
                mdm.tblStgMemberAttribute  
            WHERE  
                Batch_ID IS NULL  
                AND UPPER(LTRIM(RTRIM(ModelName))) = @ModelName  
                AND @UserName = COALESCE(NULLIF(LTRIM(RTRIM(UserName)), N''), @UserName)  
  
            SELECT  
                @TotalRecordCount = @TotalRecordCount + COUNT(*)   
            FROM  
                mdm.tblStgRelationship  
            WHERE  
                Batch_ID IS NULL  
                AND UPPER(LTRIM(RTRIM(ModelName))) = @ModelName  
                AND @UserName = COALESCE(NULLIF(LTRIM(RTRIM(UserName)), N''), @UserName)  
  
            --If there are any records then do the work  
            IF @TotalRecordCount <> 0  
            BEGIN  
                --Create the batch          
                EXEC mdm.udpStagingBatchSave @UserID, @VersionID, NULL, NULL, @BatchName,   
                    NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, @BatchID output  
  
                --Associate the member records with the new batch  
                UPDATE      
                    mdm.tblStgMember  
                SET  
                    Batch_ID = @BatchID  
                WHERE  
                    Batch_ID IS NULL  
                    AND UPPER(LTRIM(RTRIM(ModelName))) = @ModelName  
                    AND @UserName = COALESCE(NULLIF(LTRIM(RTRIM(UserName)), N''), @UserName)  
                SET @MemberCount = @@ROWCOUNT  
  
                --Associate the attribute records with the new batch  
                UPDATE      
                    mdm.tblStgMemberAttribute  
                SET  
                    Batch_ID = @BatchID  
                WHERE  
                    Batch_ID IS NULL  
                    AND UPPER(LTRIM(RTRIM(ModelName))) = @ModelName  
                    AND @UserName = COALESCE(NULLIF(LTRIM(RTRIM(UserName)), N''), @UserName)  
                SET @MemberAttributeCount = @@ROWCOUNT  
  
                --Associate the relationship records with the new batch  
                UPDATE      
                    mdm.tblStgRelationship  
                SET  
                    Batch_ID = @BatchID  
                WHERE  
                    Batch_ID IS NULL  
                    AND UPPER(LTRIM(RTRIM(ModelName))) = @ModelName  
                    AND @UserName = COALESCE(NULLIF(LTRIM(RTRIM(UserName)), N''), @UserName)  
                SET @MemberRelationshipCount = @@ROWCOUNT  
  
                --Update the batch with the counts      
                UPDATE mdm.tblStgBatch SET               
                    TotalMemberCount = @MemberCount,  
                    TotalMemberAttributeCount = @MemberAttributeCount,  
                    TotalMemberRelationshipCount = @MemberRelationshipCount  
                WHERE   
                    ID = @BatchID;                  
            END  
        END  
  
        If @Process <> 0 BEGIN  
    
            DECLARE  @handle      UNIQUEIDENTIFIER  ;  
  
            --get the existing conversation handle if possible  
            SET @handle = mdm.udfServiceGetConversationHandle(N'microsoft/mdm/service/stagingbatch',  
                N'microsoft/mdm/service/system');  
  
            IF @handle IS NULL BEGIN DIALOG CONVERSATION @handle   
                FROM SERVICE [microsoft/mdm/service/stagingbatch]   
            TO SERVICE N'microsoft/mdm/service/system'   
            WITH ENCRYPTION=OFF;  
  
            BEGIN CONVERSATION TIMER (@handle) TIMEOUT = 1; --will tell the existing timer for staging to fire in 1 sec   
        END;  
  
  
        --Commit only if we are not nested  
        IF @TranCounter = 0 COMMIT TRANSACTION;  
        RETURN(0);  
    END TRY  
    --Compensate as necessary  
    BEGIN CATCH  
        --Get error info.  
        DECLARE @ErrorMessage   NVARCHAR(4000),   
                @ErrorNumber    INT;  
        SELECT @ErrorNumber = ERROR_NUMBER(), @ErrorMessage = ERROR_MESSAGE();  
  
        --Rollback the transaction.  
        IF @TranCounter = 0 ROLLBACK TRANSACTION;  
  
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
        --Re-throw the error.  
        RAISERROR(@ErrorMessage, 16, 1);  
        RETURN(1);  
    END CATCH;  
  
    SET NOCOUNT OFF;  
  
END; --proc
GO
