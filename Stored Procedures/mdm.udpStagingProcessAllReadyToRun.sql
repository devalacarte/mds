SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
  
-- =============================================  
-- Author:        <John M. Hall (johnhall)>  
-- Create date: <10-21-09>  
-- Description:    <Process All Ready To Run Batches>  
-- =============================================  
CREATE PROCEDURE [mdm].[udpStagingProcessAllReadyToRun]  
AS  
BEGIN  
    SET NOCOUNT ON;  
    /* WARNING --- YOU CANNOT INTRODUCE A TRY .. CATCH HERE WITHOUT   
     * SIGNIFICANTLY CHANGING THE BEHAVIOR OF UNDERLYING SPROCS. Contact [johnhall] with questions. */  
       
    DECLARE                
     @User_ID               INT    
    ,@Batch_ID              INT    
    ,@LogFlag               INT = NULL  
    ,@Version_ID            INT  
    ,@BatchTag              NVARCHAR(50)  
    ,@MemberType_ID         TINYINT  
    ,@Entity_ID             INT  
    ,@LeafSproc             SYSNAME  
    ,@ConsolidatedSproc     SYSNAME  
    ,@RelationshipSproc     SYSNAME  
    ,@LeafTable             SYSNAME  
    ,@ConsolidatedTable     SYSNAME  
    ,@RelationshipTable     SYSNAME  
    ,@SQL                   NVARCHAR(MAX)  
    ,@ExecResult            INT  
    ,@VersionName           NVARCHAR(50)  
    ,@IsEBS                 BIT = 0;  
  
    DECLARE  
        @QueuedToRun                INT = 1,  
        @NotRunning                 INT = 2,             
        @Running                    INT = 3,  
        @QueueToClear               INT = 4,  
        @Cleared                    INT = 5,  
        @AllExceptCleared           INT = 6,  
        @Completed                  INT = 7  
  
    IF EXISTS(SELECT 1 FROM mdm.tblStgBatch WHERE Status_ID = 1)   
    BEGIN    
        -- Retrieve the logging system setting for transactions.  
        SELECT  @LogFlag = SettingValue FROM mdm.tblSystemSetting WHERE SettingName = 'StagingTransactionLogging';  
          
        WHILE EXISTS(SELECT 1 FROM mdm.tblStgBatch WHERE Status_ID = @QueuedToRun)   
        BEGIN    
   
            SELECT TOP 1    
                @User_ID = EnterUserID,    
                @Batch_ID = ID,    
                @Version_ID = Version_ID,  
                @BatchTag = BatchTag,  
                @MemberType_ID = MemberType_ID,  
                @Entity_ID = Entity_ID     
            FROM mdm.tblStgBatch WHERE Status_ID = @QueuedToRun;  
                
            SELECT            
                @LeafSproc = N'[stg].' + QUOTENAME(N'udp_' + StagingBase + N'_Leaf'),  
                @ConsolidatedSproc = N'[stg].' + QUOTENAME(N'udp_' + StagingBase + N'_Consolidated'),  
                @RelationshipSproc = N'[stg].' + QUOTENAME(N'udp_' + StagingBase + N'_Relationship'),    
                @LeafTable = N'[stg].' + QUOTENAME(StagingBase + N'_Leaf'),     
                @ConsolidatedTable = N'[stg].' + QUOTENAME(StagingBase + N'_Consolidated'),                        
                @RelationshipTable = N'[stg].' + QUOTENAME(StagingBase + N'_Relationship')     
            FROM mdm.tblEntity WHERE ID = @Entity_ID;  
                    
            SELECT   
                @VersionName = [Name]  
            FROM mdm.tblModelVersion WHERE ID = @Version_ID  
                                                          
            --Process Staging  
  
            --If the batch tag is specified process entity staging.  
            IF COALESCE(@BatchTag, N'') <> N''   
            BEGIN  
              SET @IsEBS = 1  
            END  
            ELSE   
            BEGIN  
              SET @IsEBS = 0  
            END; -- IF  
                                  
            IF @IsEBS = 1   
            BEGIN  
                --Update last run DTM and last run start user ID for the batch      
                UPDATE mdm.tblStgBatch SET LastRunStartDTM=GETUTCDATE(),LastRunStartUserID=@User_ID WHERE ID = @Batch_ID;      
  
                IF @MemberType_ID = 1 -- Leaf  
                BEGIN   
                    SET @SQL = N'EXEC @result = ' + @LeafSproc + N' N''' + @VersionName + N''', 0, N''' + @BatchTag + '''';  
                    EXEC sp_executesql @SQL, N'@result int output', @ExecResult OUTPUT;  
                    
                END; --IF  
                
                IF @MemberType_ID = 2 -- Consolidated  
                BEGIN   
                    SET @SQL = N'EXEC @result = ' + @ConsolidatedSproc + N' N''' + @VersionName + N''', 0, N''' + @BatchTag + '''';  
                    EXEC sp_executesql @SQL, N'@result int output', @ExecResult OUTPUT;  
  
                END; --IF  
                
                IF @MemberType_ID = 4 -- Relationship  
                BEGIN   
                
                    SET @SQL = N'EXEC @result = ' + @RelationshipSproc + N' N''' + @VersionName + N''', 0, N''' + @BatchTag + '''';  
                    EXEC sp_executesql @SQL, N'@result int output', @ExecResult OUTPUT;  
                    
                END; --IF                  
            END  
            ELSE   
            BEGIN  
              --Update the Status for the batch    
              UPDATE mdm.tblStgBatch SET Status_ID = @Running, LastRunStartDTM=GETUTCDATE(),LastRunStartUserID=@User_ID WHERE ID = @Batch_ID;    
  
              EXEC mdm.udpStagingProcess @User_ID, @Version_ID, 4, @LogFlag, 0, @Batch_ID;    
          
            END; --IF  
                              
            --Update the Status for the batch    
            UPDATE mdm.tblStgBatch SET     
                Status_ID = @Completed,    
                LastRunEndDTM=GETUTCDATE(),    
                LastRunEndUserID=@User_ID,  
                ErrorMemberCount = CASE   
                                    WHEN @IsEBS = 1 THEN ErrorMemberCount  
                                    ELSE (SELECT COUNT(ID) FROM mdm.tblStgMember WHERE Batch_ID = @Batch_ID AND Status_ID = 2) -- Status_ID = 2 means staging error.  
                                 END,    
                ErrorMemberAttributeCount = (SELECT COUNT(ID) FROM mdm.tblStgMemberAttribute WHERE Batch_ID = @Batch_ID AND Status_ID = 2),    
                ErrorMemberRelationshipCount = (SELECT COUNT(ID) FROM mdm.tblStgRelationship WHERE Batch_ID = @Batch_ID AND Status_ID = 2)    
            WHERE     
                ID = @Batch_ID;    
        END; --while           
    END; --if    
        
    --Checked for Batches that need to be cleared            
    IF EXISTS(SELECT 1 FROM mdm.tblStgBatch WHERE Status_ID = @QueueToClear)   
    BEGIN                      
        WHILE EXISTS(SELECT 1 FROM mdm.tblStgBatch WHERE Status_ID = @QueueToClear)   
        BEGIN    
            SELECT TOP 1    
                @User_ID = EnterUserID,    
                @Batch_ID = ID,  
                @BatchTag = BatchTag,  
                @MemberType_ID = MemberType_ID,  
                @Entity_ID = Entity_ID     
            FROM mdm.tblStgBatch WHERE Status_ID = @QueueToClear;  
                  
            --If the batch tag is specified process entity staging.  
            IF COALESCE(@BatchTag, N'') <> N''   
            BEGIN  
                SET @IsEBS = 1  
            END  
            ELSE   
            BEGIN  
                SET @IsEBS = 0  
            END; -- IF  
            
            IF @IsEBS = 1   
            BEGIN  
                SELECT            
                    @LeafTable = N'[stg].' + QUOTENAME(StagingBase + N'_Leaf'),     
                    @ConsolidatedTable = N'[stg].' + QUOTENAME(StagingBase + N'_Consolidated'),                        
                    @RelationshipTable = N'[stg].' + QUOTENAME(StagingBase + N'_Relationship')     
                FROM       
                    mdm.tblEntity WHERE ID = @Entity_ID;    
                                                                        
                --Clear the batch records from the EBS staging tables.    
                  
                IF @MemberType_ID = 1 -- Leaf  
                BEGIN   
                    -- Delete records for the batch ID from leaf staging table.  
                    SET @SQL = N'DELETE FROM ' + @LeafTable + N' WHERE Batch_ID = @Batch_ID';  
                    EXEC sp_executesql @SQL, N'@Batch_ID int', @Batch_ID;                                                                        
                END; --IF  
                
                IF @MemberType_ID = 2 -- Consolidated  
                BEGIN   
                    -- Delete records for the batch ID from Consolidated staging table.  
                    SET @SQL = N'DELETE FROM ' + @ConsolidatedTable + N' WHERE Batch_ID = @Batch_ID';  
                    EXEC sp_executesql @SQL, N'@Batch_ID int', @Batch_ID;                                    
                END; --IF  
                
                IF @MemberType_ID = 4 -- Relationship  
                BEGIN   
                    -- Delete records for the batch ID from Relationship staging table.  
                    SET @SQL = N'DELETE FROM ' + @RelationshipTable + N' WHERE Batch_ID = @Batch_ID';  
                    EXEC sp_executesql @SQL, N'@Batch_ID int', @Batch_ID;  
                END; --IF        
            END  
            ELSE   
            BEGIN  
                --Clear the batch from staging                    
                DELETE FROM mdm.tblStgMember WHERE Batch_ID=@Batch_ID;    
                DELETE FROM mdm.tblStgMemberAttribute WHERE Batch_ID=@Batch_ID;    
                DELETE FROM mdm.tblStgRelationship WHERE Batch_ID=@Batch_ID;  
            END;--IF  
              
            --Update the Status for the batch    
            UPDATE mdm.tblStgBatch SET     
                Status_ID = @Cleared,    
                LastClearedDTM=GETUTCDATE(),    
                LastClearedUserID=@User_ID    
            WHERE     
                ID = @Batch_ID;          
        END; --while          
    END; --if    
  
END -- Proc
GO
