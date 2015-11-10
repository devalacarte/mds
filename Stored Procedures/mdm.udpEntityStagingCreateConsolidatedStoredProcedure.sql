SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpEntityStagingCreateConsolidatedStoredProcedure]   
(  
    @Entity_ID    INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
      
    DECLARE @SQL                        NVARCHAR(MAX) = N'',  
            @SQLNonDBAColumns           NVARCHAR(MAX) = N'',  
            @SQLDBAColumns              NVARCHAR(MAX) = N'',  
            @SQLNonDBA                  NVARCHAR(MAX) = N'',  
            @SQLDBA                     NVARCHAR(MAX) = N'',  
            @SQLDBAJoin                 NVARCHAR(MAX) = N'',  
            @SQLDBACheck                NVARCHAR(MAX) = N'',  
            @EntityTable                SYSNAME = N'',  
            @CollectionTable            SYSNAME = N'',  
            @HierarchyTable             SYSNAME = N'',  
            @HierarchyParentTable       SYSNAME = N'',  
            @HierarchyRelationshipTable SYSNAME = N'',  
            @CurrentTableColumn         SYSNAME = N'',  
            @CurrentTableColumnNoQuote  SYSNAME = N'',      
            @CurrentViewColumn          NVARCHAR(120) = N'', --specifically made to be less than 128 for truncation reasons    
            @CurrentAttributeName       NVARCHAR(50) = N'',  
            @CurrentDomainTable         SYSNAME = N'',  
            @CurrentDomainEntity_ID     INT,  
            @CurrentAttributeType_ID    TINYINT,  
            @CurrentDataType_ID         TINYINT,  
            @SQLMergeOptimisticNonDBA   NVARCHAR(MAX) = N'',  
            @SQLMergeOptimisticDBA      NVARCHAR(MAX) = N'',  
            @SQLMergeOverwriteNonDBA    NVARCHAR(MAX) = N'',  
            @SQLMergeOverwriteDBA       NVARCHAR(MAX) = N'',  
            @SQLAttributeTypeErrorCheck NVARCHAR(MAX) = N'',  
            @StagingBase                NVARCHAR(60),  
            @StagingConsolidatedTable   SYSNAME,  
            @SQLAttributeValueSetMergeOverwrite     NVARCHAR(MAX) = N'',  
            @SQLAttributeValueSetMergeOptimistic    NVARCHAR(MAX) = N'',   
  
            -- This pseudo-constant is for use in string concatenation operations to prevent string truncation. When concatenating two or more strings,  
            -- if none of the strings is an NVARCHAR(MAX) or an NVARCHAR constant that is longer than 4,000 characters, then the resulting string   
            -- will be silently truncated to 4,000 characters. Concatenating with this empty NVARCHAR(MAX), is sufficient to prevent truncation.  
            -- See http://connect.microsoft.com/SQLServer/feedback/details/283368/nvarchar-max-concatenation-yields-silent-truncation.  
            @TruncationGuard            NVARCHAR(MAX) = N'',  
                                      
            -- attribute type constant          
            @AttributeType_File         INT = 4,  
              
            @Model_ID                   INT,  
            @TranOldColumn              NVARCHAR(MAX) = N'',  
            @TranNewColumn              NVARCHAR(MAX) = N'',  
            @TranDeletedColumn          NVARCHAR(MAX) = N'',  
            @TranBlankColumn            NVARCHAR(MAX) = N'',  
            @TranInsertedColumn         NVARCHAR(MAX) = N'';        
              
            DECLARE @TempTable TABLE(  
            ViewColumn                  NVARCHAR(120) COLLATE database_default,  
            TableColumn                 NVARCHAR(128) NOT NULL,  
            AttributeType_ID            TINYINT NOT NULL,  
            DataType_ID                 TINYINT NOT NULL,  
            DomainEntity_ID             INT NULL,  
            DomainTable                 NVARCHAR(128) NULL,  
            SortOrder                   INT);  
              
    --Initialize the variables  
      
    SELECT  @EntityTable = QUOTENAME(EntityTable),  
            @CollectionTable = QUOTENAME(CollectionTable),  
            @HierarchyTable = QUOTENAME(HierarchyTable),  
            @HierarchyParentTable = QUOTENAME(HierarchyParentTable),  
            @HierarchyRelationshipTable = QUOTENAME(HierarchyTable),  
            @Model_ID = Model_ID,  
            @StagingBase = StagingBase,  
            @StagingConsolidatedTable = QUOTENAME(IsNULL(StagingConsolidatedTable, N''))  
    FROM mdm.viw_SYSTEM_SCHEMA_ENTITY   
    WHERE ID = @Entity_ID;   
  
    -- In case when the entity is a system entity (StagingBase is not specified) simply don't create the staging SProc (don't raise an error).   
    IF COALESCE(@StagingBase, N'') = N'' BEGIN   
        RETURN;  
    END;  
      
    --If the consolidated staging SProc exists drop it.      
    EXEC udpEntityStagingDeleteStoredProcedures @Entity_ID, 2  
  
    SET @SQL = @TruncationGuard + N'CREATE PROCEDURE [stg].[udp_' + @StagingBase + N'_Consolidated]    
@VersionName NVARCHAR(50), @LogFlag INT=NULL, @BatchTag NVARCHAR(50)=N'''', @Batch_ID INT=NULL    
WITH EXECUTE AS ''mds_schema_user''    
AS    
BEGIN    
    SET NOCOUNT ON;  
      
    DECLARE @UserName                   NVARCHAR(100),  
            @Model_ID                   INT,  
            @Version_ID                 INT,  
            @Hierarchy_ID               INT,  
            @HierarchyParent_ID         INT,  
            @IsMandatory                BIT,     
            @VersionStatus_ID           INT,    
            @VersionStatus_Committed    INT = 3,  
            @Entity_ID                  INT,  
            @MemberCount                INT = 0,  
            @ErrorCount                 INT = 0,  
            @NewBatch_ID                INT = 0,  
            @GetNewBatch_ID             INT = 0,  
            @Member_ID                  INT,  
            @CurrentHierarchy_ID        INT,  
            @CurrentHierarchy_Name      NVARCHAR(50),  
            @User_ID                    INT = 0, -- The user ID used for logging is 0.  
              
            -- member type constant  
            @ConsolidatedMemberTypeID   INT = 2,  
              
            -- attribute type constants     
            @FreeformTypeId             INT = 1,    
            @DomainTypeId               INT = 2,    
            @SystemTypeId               INT = 3,    
                
            -- transaction type constants    
            @StatusChangedId            INT = 2,    
            @AttributeChangedId         INT = 3,      
                                
            -- staging datastatus constants    
            @StatusDefault              INT = 0,    
            @StatusOK                   INT = 1,    
            @StatusError                INT = 2,  
            @StatusProcessing           INT = 3,  
              
            -- error return code constants  
            @UserIDError                INT = 1,  
            @VersionNameError           INT = 3,  
            @UserPermissionError        INT = 4,  
            @VersionStatusError         INT = 5,  
            @NoRecordToProcessError     INT = 6,  
            @BatchIDAndBatchTagSpecifiedError   INT = 7,  
            @BatchStatusError           INT = 8,  
            @OtherRuntimeError          INT = 9,  
                         
            -- bacth status constants  
            @QueuedToRun                INT = 1,  
            @NotRunning                 INT = 2,             
            @Running                    INT = 3,  
            @QueueToClear               INT = 4,  
            @Cleared                    INT = 5,  
            @AllExceptCleared           INT = 6,  
            @Completed                  INT = 7,  
  
             -- GetNewBatch_ID constants  
            @BatchIDFound               INT = 0,  
            @BatchIDNotFound            INT = 1,  
            @BatchIDForBatchTagNotFound INT = 2,    
              
            --Import Type Constans  
            @IT_MergeOptimistic         INT = 0,  
            @IT_Insert                  INT = 1,  
            @IT_MergeOverwrite          INT = 2,  
            @IT_Delete                  INT = 3,  
            @IT_Purge                   INT = 4,  
            @IT_Max                     INT = 4,  
              
            --FK Constraint Removal  
            @FKEntity_ID                INT,  
            @FKMemberType_ID            INT,  
            @FKMemberCode               NVARCHAR(250),  
            @FKMember_ID                INT,  
            @EntityName                 NVARCHAR(100),  
            @EntityTable                SYSNAME,  
            @AttributeName              NVARCHAR(100),  
            @AttributeColumn            SYSNAME,  
            @MemberType_ID              INT,  
            @MemberCode                 NVARCHAR(250),  
            @ImportType                 TINYINT,  
            @TableColumn                NVARCHAR(128),  
            @TableName                  SYSNAME,  
            @FKSQL                      NVARCHAR(MAX) = N'''',  
              
            --Special attribute values  
            @NULLNumber                 DECIMAL(38,0) = -98765432101234567890,  
            @NULLText                   NVARCHAR(10) = N''~NULL~'',  
            @NULLDateTime               NVARCHAR(30) = N''5555-11-22T12:34:56'',  
      
            --Entity member status  
            @MemberStatusOK             INT = 1,  
            @MemberStatusInactive       INT = 2,  
              
            --Change Tracking Group  
            @ChangedAttributeName       NVARCHAR(50),  
            @ConsolidatedAttributeName	NVARCHAR(50),  
            @ChangeTrackingGroup        INT,     
            @SQLCTG                     NVARCHAR(MAX),  
            @ChangedAttributeType_ID    TINYINT,  
            @ChangedAttributeDomainEntityTableName sysname,  
            @AttributeType_Domain       TINYINT = 2,  
              
            --Transaction Log Types  
            @MemberCreateTransaction        INT = 1,  
            @MemberStatusSetTransaction     INT = 2,  
            @MemberAttributeSetTransaction  INT = 3,  
            @HierarchyParentSetTransaction  INT = 4,  
              
            --Validation status  
            @NewAwaitingValidation      INT = 0,  
            @AwaitingRevalidation       INT = 4,     
                          
            --Code generation  
            @AllowCodeGen               BIT = 0,         
              
            --XACT_STATE() constancts    
            @UncommittableTransaction    INT = -1;  
              
            DECLARE @TABLECTG TABLE  
            (  
                ID                  INT IDENTITY (1, 1) NOT NULL,  
                AttributeName       NVARCHAR(50),  
				AttributeColumnName sysname,  
                AttributeID			INT,  
                ChangeTrackingID    INT,  
				AttributeType_ID    TINYINT,  
				DomainEntityTableName sysname NULL  
            );  
              
            DECLARE @TableHP TABLE  
            (  
                HierarchyParent_ID      INT,  
                IsMandatory             BIT  
            );  
              
            DECLARE @TableHierarchy TABLE  
            (  
                Hierarchy_ID        INT,  
                Hierarchy_Name      NVARCHAR(50)  
            );  
              
    SET @Model_ID = ' + CONVERT(NVARCHAR(25),@Model_ID) + N'  
    SET @Entity_ID = ' + CONVERT(NVARCHAR(25),@Entity_ID)   
    + N'  
          
    -- Check for invalid Version Name.      
    IF @VersionName IS NULL RETURN @VersionNameError;  
      
    -- Set @AllowCodeGen (1: Code generation is allowed for the entity. 0: Code generation is not allowed for the entity)  
    EXEC @AllowCodeGen = mdm.udpIsCodeGenEnabled @Entity_ID;   
  
    -- Trim batch tag  
    SET @BatchTag = LTRIM(RTRIM(@BatchTag));  
      
    IF LEN(@BatchTag) > 0 AND @Batch_ID IS NOT NULL BEGIN  
        RAISERROR(''MDSERR310043|The Batch Tag and the Batch ID cannot be specified at the same time.'', 16, 1);  
        RETURN @BatchIDAndBatchTagSpecifiedError;    
    END; --IF    
                  
    IF NOT EXISTS(SELECT 1 FROM mdm.tblModelVersion WHERE Model_ID = @Model_ID AND [Name] = @VersionName) BEGIN  
        RAISERROR(''MDSERR100036|The version name is not valid.'', 16, 1);  
        RETURN @VersionNameError;    
    END; --IF  
      
    SELECT @Version_ID = ID, @VersionStatus_ID = Status_ID FROM mdm.tblModelVersion WHERE Model_ID = @Model_ID AND [Name] = @VersionName       
            
     --Ensure that Version is not committed    
    IF (@VersionStatus_ID = @VersionStatus_Committed) BEGIN    
        RAISERROR(''MDSERR310040|Data cannot be loaded into a committed version.'', 16, 1);  
        RETURN @VersionStatusError;           
    END;  
      
    --Check if there is any record to process.  
    IF LEN(@BatchTag) > 0 BEGIN  
        SELECT @MemberCount = COUNT(ID) FROM [stg].' + @StagingConsolidatedTable + N'   
            WHERE LTRIM(RTRIM(BatchTag)) = @BatchTag AND ImportStatus_ID = @StatusDefault;  
        IF @MemberCount = 0    BEGIN   
            RETURN @NoRecordToProcessError;                 
        END; -- IF              
    END; -- IF  
    ELSE BEGIN  
        IF @Batch_ID IS NOT NULL BEGIN  
            SELECT @MemberCount = COUNT(ID) FROM [stg].' + @StagingConsolidatedTable + N'   
                WHERE Batch_ID = @Batch_ID AND ImportStatus_ID = @StatusDefault;   
            IF @MemberCount = 0    BEGIN   
                RETURN @NoRecordToProcessError;                
            END; -- IF              
        END; -- IF  
    END; -- IF  
      
    -- If neither @BatchTag nor @Batch_ID is specified assume that a blank @BatchTag is specified.  
      
    IF @Batch_ID IS NULL AND LEN(@BatchTag) = 0 BEGIN  
        SELECT @MemberCount = COUNT(ID) FROM [stg].' + @StagingConsolidatedTable + N'   
            WHERE (BatchTag IS NULL OR LTRIM(RTRIM(BatchTag)) = N'''') AND ImportStatus_ID = @StatusDefault;   
        IF @MemberCount = 0    BEGIN   
            RETURN @NoRecordToProcessError;                
        END; -- IF              
    END; -- IF  
      
    --Check if there is any record with an invalid status.  
    IF LEN(@BatchTag) > 0 BEGIN  
        IF EXISTS (SELECT stgp.ID FROM [stg].' + @StagingConsolidatedTable + N' stgp  
            INNER JOIN mdm.tblStgBatch stgb  
            ON LTRIM(RTRIM(stgp.BatchTag)) = LTRIM(RTRIM(stgb.BatchTag)) AND stgb.Status_ID = @Running   
            WHERE LTRIM(RTRIM(stgp.BatchTag)) = @BatchTag AND stgp.ImportStatus_ID = @StatusDefault) BEGIN   
              
            RAISERROR(''MDSERR310029|The status of the specified batch is not valid.'', 16, 1);  
            RETURN @BatchStatusError;                  
        END; -- IF              
    END; -- IF   
      
    IF @Batch_ID IS NOT NULL  BEGIN  
        IF EXISTS (SELECT stgp.ID FROM [stg].' + @StagingConsolidatedTable + N' stgp  
            INNER JOIN mdm.tblStgBatch stgb  
            ON stgp.Batch_ID = stgb.ID AND stgb.Status_ID IN (@Running, @QueueToClear, @Cleared)  
            WHERE stgp.Batch_ID = @Batch_ID AND stgp.ImportStatus_ID = @StatusDefault) BEGIN   
              
            RAISERROR(''MDSERR310029|The status of the specified batch is not valid.'', 16, 1);  
            RETURN @BatchStatusError;                  
        END; -- IF              
    END; -- IF   
      
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY    
      
    IF @Batch_ID IS NOT NULL  BEGIN  
        IF NOT EXISTS (SELECT ID FROM mdm.tblStgBatch WHERE ID = @Batch_ID AND Status_ID NOT IN (@Running, @QueueToClear, @Cleared)  
                        AND Version_ID = @Version_ID AND Entity_ID = @Entity_ID AND MemberType_ID = 2) BEGIN  
            SET @GetNewBatch_ID = @BatchIDNotFound                  
        END; --IF  
    END; --IF                          
    ELSE BEGIN  
        -- Check if udpEntityStagingFlagForProcessing already assigned a new batch ID (in this case the status is QueuedToRun).  
        SELECT TOP 1 @Batch_ID = ID FROM mdm.tblStgBatch   
            WHERE LTRIM(RTRIM(BatchTag)) = @BatchTag AND Status_ID = @QueuedToRun   
            AND Version_ID = @Version_ID AND Entity_ID = @Entity_ID AND MemberType_ID = @ConsolidatedMemberTypeID   
            ORDER BY ID DESC  
           
        IF @Batch_ID IS NULL BEGIN  
            SET @GetNewBatch_ID = @BatchIDForBatchTagNotFound      
        END; --IF  
        ELSE BEGIN  
        -- Set the member count      
            UPDATE mdm.tblStgBatch  
            SET TotalMemberCount = @MemberCount  
            WHERE LTRIM(RTRIM(BatchTag)) = @BatchTag AND Status_ID = @QueuedToRun   
                        AND Version_ID = @Version_ID AND Entity_ID = @Entity_ID AND MemberType_ID = @ConsolidatedMemberTypeID        
        END; --IF       
    END; --IF  
      
      
    IF @GetNewBatch_ID IN (@BatchIDNotFound, @BatchIDForBatchTagNotFound) BEGIN      
    -- Create a new batch ID.  
        INSERT INTO mdm.tblStgBatch   
        (MUID  
        ,Version_ID  
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
            NEWID(),  
            @Version_ID,      
            @Running,  
            @BatchTag,  
            @Entity_ID,  
            2,  
            @MemberCount,  
            NULL,  
            NULL,  
            NULL,  
            NULL,   
            NULL,  
            GETUTCDATE(),  
            @User_ID,  
            NULL,  
            NULL,   
            NULL,  
            NULL,  
            GETUTCDATE(),   
            @User_ID  
  
        SELECT @NewBatch_ID = SCOPE_IDENTITY();  
          
        -- Update batch ID.  
              
        IF @GetNewBatch_ID = @BatchIDNotFound BEGIN  
            UPDATE [stg].' + @StagingConsolidatedTable + N'  
                SET Batch_ID = @NewBatch_ID  
                WHERE Batch_ID = @Batch_ID AND ImportStatus_ID = @StatusDefault  
        END; --IF  
        ELSE BEGIN  
            UPDATE [stg].' + @StagingConsolidatedTable + N'  
                SET Batch_ID = @NewBatch_ID  
                WHERE IsNULL(BatchTag, N'''') = @BatchTag AND ImportStatus_ID = @StatusDefault      
        END; --IF  
          
        SET @Batch_ID = @NewBatch_ID;  
    END --IF  
    ELSE BEGIN  
        -- Set the status of the batch as Running.  
        UPDATE mdm.tblStgBatch   
            SET Status_ID = @Running,  
                TotalMemberCount = @MemberCount,  
                LastRunStartDTM = GETUTCDATE(),  
                LastRunStartUserID = @User_ID  
            WHERE ID = @Batch_ID   
    END; --IF      
    '  
      
    INSERT INTO @TempTable    
    SELECT  
        ViewColumn,      
        TableColumn,  
        AttributeType_ID,  
        DataType_ID,  
        DomainEntity_ID,  
        DomainTable,     
        SortOrder    
    FROM         
        mdm.udfEntityAttributesGetList(@Entity_ID, 2)  
    WHERE IsSystem <> 1 -- Exclude system attributes.     
    ORDER BY     
        SortOrder ASC;    
  
    WHILE EXISTS(SELECT 1 FROM @TempTable) BEGIN    
  
        SELECT TOP 1     
            @CurrentViewColumn = QUOTENAME(ViewColumn),  
            @CurrentAttributeName = ViewColumn,      
            @CurrentTableColumn = QUOTENAME(TableColumn),  
            @CurrentTableColumnNoQuote = TableColumn,   
            @CurrentAttributeType_ID = AttributeType_ID,  
            @CurrentDataType_ID =  DataType_ID,  
            @CurrentDomainEntity_ID = DomainEntity_ID,  
            @CurrentDomainTable = DomainTable    
        FROM @TempTable    
        ORDER BY SortOrder;  
          
        IF @CurrentDomainEntity_ID IS NULL BEGIN -- Non DBA  
            SET @SQLNonDBAColumns += N'   
            ,' + @CurrentTableColumn + N' --' + @CurrentViewColumn  
                            
            -- When the data type is text and the value is @NULLText (~NULL~) set NULL.  
            -- When the data type is number and the value is @NULLNumber (-98765432101234567890) set NULL.  
            -- When the data type is DateTime and the value is @NULLDateTime (5555-11-22T12:34:56) set NULL.  
              
            SET @SQLAttributeValueSetMergeOverwrite = CASE     
                                    WHEN @CurrentDataType_ID IN (1 /*Text*/, 6 /*Link*/) THEN     
                                        N'NULLIF(stgp.' + @CurrentViewColumn + N',@NULLText)'    
                                    WHEN @CurrentDataType_ID = 2 THEN -- Data type is Number    
                                        N'NULLIF(stgp.' + @CurrentViewColumn + N',@NULLNumber)'    
                                    WHEN @CurrentDataType_ID = 3 THEN -- Data type is DateTime    
                                        N'NULLIF(stgp.' + @CurrentViewColumn + N',@NULLDateTime)'                                            
                                    ELSE    
                                        N'stgp.' + @CurrentViewColumn    
                                    END;  
  
            IF LEN(COALESCE(@SQLNonDBA, N'')) > 0  
            BEGIN -- Not at the beginning.  
                SET @SQLNonDBA += N',  
';  
            END;  
            SET @SQLNonDBA += @SQLAttributeValueSetMergeOverwrite;  
  
            -- Even in case of merge optimistic set NULL when the value is @NULLText, @NULLNumber, or @NULLDateTime depending on the data type.                                                  
            SET @SQLAttributeValueSetMergeOptimistic = CASE     
                                    WHEN @CurrentDataType_ID IN (1 /*Text*/, 6 /*Link*/) THEN     
                                        N'CASE WHEN stgp.' + @CurrentViewColumn + N' = @NULLText THEN NULL  
                                               WHEN stgp.' + @CurrentViewColumn + N' IS NULL THEN hp.'  + @CurrentTableColumn + N'  
                                               ELSE stgp.' + @CurrentViewColumn + N'  
                                          END '        
                                    WHEN @CurrentDataType_ID = 2 THEN -- Data type is Number   
                                        N'CASE WHEN stgp.' + @CurrentViewColumn + N' = @NULLNumber THEN NULL  
                                               WHEN stgp.' + @CurrentViewColumn + N' IS NULL THEN hp.'  + @CurrentTableColumn + N'  
                                               ELSE stgp.' + @CurrentViewColumn + N'  
                                          END '     
                                    WHEN @CurrentDataType_ID = 3 THEN -- Data type is DateTime    
                                        N'CASE WHEN stgp.' + @CurrentViewColumn + N' = @NULLDateTime THEN NULL  
                                               WHEN stgp.' + @CurrentViewColumn + N' IS NULL THEN hp.'  + @CurrentTableColumn + N'  
                                               ELSE stgp.' + @CurrentViewColumn + N'  
                                          END '                                      
                                    ELSE    
                                        N'stgp.' + @CurrentViewColumn    
                                    END;  
                                                              
            SET @SQLMergeOptimisticNonDBA += N',' + @CurrentTableColumn + N' = ' + @SQLAttributeValueSetMergeOptimistic;                                      
            SET @SQLMergeOverwriteNonDBA += N',' + @CurrentTableColumn + N' = ' + @SQLAttributeValueSetMergeOverwrite;  
                    
            SET @TranOldColumn += N'  
            ,' + @CurrentTableColumnNoQuote + N' NVARCHAR(MAX) NULL ';  
              
            SET @TranDeletedColumn += N', CONVERT(NVARCHAR(MAX), deleted.' + @CurrentTableColumn + N') ';  
            SET @TranBlankColumn += N', NULL ';  
              
            SET @TranNewColumn += N'  
            ,New_' + @CurrentTableColumnNoQuote + N' NVARCHAR(MAX) NULL ';  
              
            SET @TranInsertedColumn += N', CONVERT(NVARCHAR(MAX), inserted.' + @CurrentTableColumn + N') ';  
                                                
        END   
        ELSE BEGIN -- DBA  
            SET @SQLDBAColumns = @SQLDBAColumns + N'   
            ,' + @CurrentTableColumn + N' --' + @CurrentViewColumn     
                                                              
            IF LEN(COALESCE(@SQLDBA, N'')) > 0   
            BEGIN -- Not at the beginning.    
                SET @SQLDBA += N',  
'  
            END;  
            SET @SQLDBA += N'CASE WHEN stgp.' + @CurrentViewColumn + N' = @NULLText THEN NULL ELSE ' + @CurrentViewColumn + N'.ID END';  
  
            -- Even in case of merge optimistic set NULL when the value is @NULLText.                                                  
            SET @SQLMergeOptimisticDBA += N',' + @CurrentTableColumn + N' = CASE WHEN stgp.' + @CurrentViewColumn + N' = @NULLText THEN NULL   
            ELSE ISNULL(' + @CurrentViewColumn + N'.ID, hp.' + @CurrentTableColumn + N') END  
            ';  
               
            SET @SQLMergeOverwriteDBA += N',' + @CurrentTableColumn + N' = CASE WHEN stgp.' + @CurrentViewColumn + N' = @NULLText THEN NULL   
            ELSE ' + @CurrentViewColumn + N'.ID END  
            ';  
                          
            SET @TranOldColumn += N'  
            ,' + @CurrentTableColumnNoQuote + N' NVARCHAR(MAX) NULL ';      
              
            SET @TranDeletedColumn += N', CONVERT(NVARCHAR(MAX), deleted.' + @CurrentTableColumn + N') ';  
  
            SET @TranBlankColumn += N', NULL ';  
              
            SET @TranNewColumn += N'  
            ,New_' + @CurrentTableColumnNoQuote + N' NVARCHAR(MAX) NULL ';      
              
            SET @TranInsertedColumn += N', CONVERT(NVARCHAR(MAX), inserted.' + @CurrentTableColumn + N') ';  
              
            -- In case when there are multiple DBAs using the same entity table use @CurrentViewColumn as   
            -- an alias to each entity table to avoid SQL error.  
            SET @SQLDBAJoin = @SQLDBAJoin + N'   
            left outer join mdm.' + @CurrentDomainTable + N' ' + @CurrentViewColumn + N' ON stgp.' + @CurrentViewColumn + N' = ' + @CurrentViewColumn + N'.Code AND ' + N' ' + @CurrentViewColumn + N'.Version_ID = @Version_ID   
            '  
              
            SET @SQLDBACheck += @TruncationGuard + N'  
            -- Error 210003 The attribute value references a member that does not exist or is inactive. Binary Location 2^2:        
            UPDATE stgp  
            SET ErrorCode = IsNull(ErrorCode,0) | 4  
                OUTPUT inserted.Batch_ID, inserted.Code, N''' + @CurrentViewColumn + N''', inserted.' + @CurrentViewColumn + N', 210003  
                INTO [mdm].[tblStgErrorDetail] (Batch_ID, Code, AttributeName, AttributeValue, UniqueErrorCode)  
            FROM [stg].' + @StagingConsolidatedTable + N' stgp  
                LEFT OUTER JOIN mdm.' + @CurrentDomainTable + N' dm   
                ON stgp.' + @CurrentViewColumn + N' = dm.Code  
                AND dm.Version_ID = @Version_ID   
                AND dm.Status_ID = @MemberStatusOK  
            WHERE stgp.ImportType NOT IN (@IT_Delete,@IT_Purge)   
            AND LEN(COALESCE(NULLIF(stgp.' + @CurrentViewColumn + N',  @NULLText), N'''')) > 0   
            AND stgp.Batch_ID = @Batch_ID   
            AND stgp.ImportStatus_ID = @StatusDefault   
            AND dm.Code IS NULL;  
            ';  
        END; -- IF  
          
        IF @CurrentAttributeType_ID = @AttributeType_File  
        BEGIN  
            SET @SQLAttributeTypeErrorCheck += @TruncationGuard + N'  
            --Error 200066 Binary Location 2^18: The file attribute cannot be saved  
            --If the user tries to set any value in a file attribute when the Import type is   
            --Merge Optimistic, Merge Overwrite or Insert, set the error code.  
            UPDATE [stg].' + @StagingConsolidatedTable + N'  
            SET ErrorCode = IsNull(ErrorCode,0) | 262144   
            WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID   
            AND ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite, @IT_Insert)   
            AND ' + @CurrentViewColumn + N' IS NOT NULL  
              
            ';  
        END; -- IF  
          
        DELETE FROM @TempTable WHERE QUOTENAME(ViewColumn) = @CurrentViewColumn;    
                            
    END; --WHILE  
               
    SET @SQL += @TruncationGuard + N'  
    -- Set ErrorCode = 0   
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = 0  
        WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
       
    --Error Check all staged members  
    --Error 210001 Binary Location 2^1: Multiple Records for the same member record  
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 2  
        WHERE Code in (SELECT Code FROM [stg].' + @StagingConsolidatedTable + N' WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID group by Code having COUNT(*) > 1);  
      
    --Error 210006 Binary Location 2^3: Member Code is inactive.  
    -- The rule is not applicable when purging the member.              
    UPDATE stgp  
    SET ErrorCode = IsNull(ErrorCode,0) | 8  
    FROM [stg].' + @StagingConsolidatedTable + N' stgp  
    INNER JOIN mdm.' + @HierarchyParentTable + N' hp   
    ON stgp.Code = hp.Code AND hp.Version_ID = @Version_ID AND hp.Status_ID = @MemberStatusInactive  
    WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID AND ImportType <> @IT_Purge;  
    ' + @SQLDBACheck + N'  
                  
    --Error 210032 Binary Location 2^4: HierarchyName is missing or is not valid.  
    --Check if the HierarchyName is missing.   
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        Set ErrorCode = IsNull(ErrorCode,0) | 16   
        Where LEN(COALESCE(HierarchyName, N'''')) = 0 AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
          
    --Check if the HierarchyName is valid.    
    UPDATE stgp  
    SET ErrorCode = IsNull(ErrorCode,0) | 16  
    FROM [stg].' + @StagingConsolidatedTable + N' stgp  
        LEFT OUTER JOIN mdm.tblHierarchy hr   
        ON stgp.HierarchyName = hr.Name AND hr.Entity_ID = @Entity_ID    
    WHERE hr.ID IS NULL   
        AND stgp.ImportStatus_ID = @StatusDefault AND stgp.Batch_ID = @Batch_ID;  
  
    --Error 210035 Binary Location 2^5: Code is Mandatory  
    -- Code generation is not available for Consolidated members (it is available for leaf members only).   
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 32   
        WHERE IsNull(Code, N'''') = N'''' AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
      
    --Error 210041 Binary Location 2^6: ROOT is not a valid MemberCode  
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 64   
        WHERE UPPER(Code) = N''ROOT'' AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;      
  
    --Error 210042 Binary Location 2^7: MDMUnused is not a valid MemberCode  
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 128   
        WHERE UPPER(Code) = N''MDMUNUSED'' AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;'      
+ @SQLAttributeTypeErrorCheck + N'  
  
    --Error 300002 Binary Location 2^8: The member code is not valid  
    UPDATE stgp  
    SET ErrorCode = IsNull(ErrorCode,0) | 256  
    FROM [stg].' + @StagingConsolidatedTable + N' stgp  
        LEFT OUTER JOIN mdm.' + @HierarchyParentTable + N' hp   
        ON stgp.Code = hp.Code AND hp.Version_ID = @Version_ID    
    WHERE ImportType IN (@IT_Delete, @IT_Purge) AND ImportStatus_ID = @StatusDefault  
        AND Batch_ID = @Batch_ID AND hp.Code IS NULL;  
  
    --Error 300003 Binary Location 2^9: The Member code already exists  
    --Verify uniqueness of the code against the entity table  
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 512  
        FROM [stg].' + @StagingConsolidatedTable + N' sc  
            INNER JOIN mdm.' + @EntityTable + N' AS tSource ON sc.Code = tSource.Code     
        WHERE tSource.Version_ID = @Version_ID AND sc.ImportType IN (@IT_Insert, @IT_MergeOptimistic, @IT_MergeOverwrite)  
            AND sc.ImportStatus_ID = @StatusDefault AND sc.Batch_ID = @Batch_ID;  
              
    --Error 300003 Binary Location 2^9: The Member code already exists              
    --Verify uniqueness of the new code against the entity table  
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 512  
        FROM [stg].' + @StagingConsolidatedTable + N' sc  
            INNER JOIN mdm.' + @EntityTable + N' AS tSource ON sc.NewCode = tSource.Code     
        WHERE tSource.Version_ID = @Version_ID AND sc.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite)   
            AND sc.ImportStatus_ID = @StatusDefault AND sc.Batch_ID = @Batch_ID;  
  
    --Error 300003 Binary Location 2^9: The Member code already exists                      
    --Verify uniqueness of Code against the Hierarchy Parent table  
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 512  
        FROM [stg].' + @StagingConsolidatedTable + N' sc  
            INNER JOIN mdm.' + @HierarchyParentTable + N' AS tSource ON sc.Code = tSource.Code     
        WHERE tSource.Version_ID = @Version_ID AND sc.ImportType = @IT_Insert   
            AND sc.ImportStatus_ID = @StatusDefault AND sc.Batch_ID = @Batch_ID;  
  
    --Error 300003 Binary Location 2^9: The Member code already exists      
    --Verify uniqueness of the new code against the Hierarchy Parent table     
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 512  
        FROM [stg].' + @StagingConsolidatedTable + N' sc  
            INNER JOIN mdm.' + @HierarchyParentTable + N' AS tSource ON sc.NewCode = tSource.Code     
        WHERE tSource.Version_ID = @Version_ID AND sc.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite)    
            AND sc.ImportStatus_ID = @StatusDefault AND sc.Batch_ID = @Batch_ID;  
      
     --Error 210058 Binary Location 2^10: Invalid ImportType  
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 1024   
        WHERE ImportType > @IT_Max AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;'  
          
IF LEN(COALESCE(@CollectionTable, N'')) > 0 BEGIN       
    SET @SQL += @TruncationGuard + N'  
    --Error 300003 Binary Location 2^9: The Member code already exists    
    --Verify uniqueness of code against the collection table  
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 512  
        FROM [stg].' + @StagingConsolidatedTable + N' sc  
            INNER JOIN mdm.' + @CollectionTable + N' AS tSource ON sc.Code = tSource.Code     
        WHERE tSource.Version_ID = @Version_ID AND sc.ImportType IN (@IT_Insert, @IT_MergeOptimistic, @IT_MergeOverwrite)  
            AND sc.ImportStatus_ID = @StatusDefault AND sc.Batch_ID = @Batch_ID;  
          
    --Error 300003 Binary Location 2^9: The Member code already exists            
    --Verify uniqueness of the new code against the collection table     
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ErrorCode = IsNull(ErrorCode,0) | 512  
        FROM [stg].' + @StagingConsolidatedTable + N' sc  
            INNER JOIN mdm.' + @CollectionTable + N' AS tSource ON sc.NewCode = tSource.Code     
        WHERE tSource.Version_ID = @Version_ID AND sc.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite)    
            AND sc.ImportStatus_ID = @StatusDefault AND sc.Batch_ID = @Batch_ID;  
    '  
 END; -- IF   
   
 --Get the Attributes for the Entity.          
SET @SQL += @TruncationGuard + N'  
    IF @AllowCodeGen = 1   
    BEGIN  
        --Gather up the valid user provided codes.    
        DECLARE @CodesToProcess mdm.MemberCodes;  
          
        INSERT @CodesToProcess (MemberCode)                     
        SELECT Code FROM [stg].' + @StagingConsolidatedTable + N'  
        WHERE ErrorCode = 0 AND ImportStatus_ID = @StatusDefault   
            AND Batch_ID = @Batch_ID AND Code IS NOT NULL;    
        
        INSERT @CodesToProcess (MemberCode)                     
        SELECT NewCode FROM [stg].' + @StagingConsolidatedTable + N'  
        WHERE ErrorCode = 0 AND ImportStatus_ID = @StatusDefault   
            AND Batch_ID = @Batch_ID AND NewCode IS NOT NULL;  
              
        --Process the user-provided codes to update the code gen info table with the largest one.    
        EXEC mdm.udpProcessCodes @Entity_ID, @CodesToProcess;        
  
    END; --IF   
  
    --Table for transaction log  
    CREATE TABLE #TRANLOG  
    (  
                MemberID    INT  
                ,Code       NVARCHAR(250)  
                ,New_Code    NVARCHAR(250)  
                ,Name       NVARCHAR(250) NULL  
                ,New_Name    NVARCHAR(250) NULL  
    ' + @TranOldColumn + @TranNewColumn + N'  
    );  
  
    --Set ImportStatus on all records with at least one error  
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ImportStatus_ID = @StatusError  
        WHERE ErrorCode > 0 AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
          
    --Process Insert all new error free records into MDS internal table              
    UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ImportStatus_ID = @StatusProcessing  
        FROM [stg].' + @StagingConsolidatedTable + N' stgp  
            LEFT OUTER JOIN  mdm.' + @HierarchyParentTable + N' hp  
            ON  stgp.Code = hp.Code AND hp.Version_ID = @Version_ID   
        WHERE stgp.Batch_ID = @Batch_ID   
            AND stgp.ImportType in (@IT_MergeOptimistic,@IT_Insert,@IT_MergeOverwrite)   
            AND stgp.ImportStatus_ID = @StatusDefault   
            AND hp.Code IS NULL;  
  
    IF @LogFlag = 0  
    BEGIN              
        INSERT INTO mdm.' + @HierarchyParentTable + N'  
        (   
            Version_ID,  
            Status_ID,  
            ValidationStatus_ID,  
            Name,  
            Code,  
            Hierarchy_ID,  
            EnterDTM,  
            EnterUserID,  
            EnterVersionID,  
            LastChgDTM,  
            LastChgUserID,  
            LastChgVersionID'  
        + COALESCE(@SQLNonDBAColumns, N'') + COALESCE(@SQLDBAColumns, N'') + N'   
        )  
        SELECT  
            @Version_ID,  
            1,  
            @NewAwaitingValidation,  
            stgp.Name,  
            stgp.Code,  
            hr.ID,  
            GETUTCDATE(),  
            @User_ID,  
            @Version_ID,  
            GETUTCDATE(),  
            @User_ID,  
            @Version_ID' +   
            CASE  
                WHEN LEN(COALESCE(@SQLNonDBA, N'') + COALESCE(@SQLDBA, N'')) = 0 THEN N''  
                WHEN LEN(COALESCE(@SQLNonDBA, N'')) > 0 AND LEN(COALESCE(@SQLDBA, N'')) > 0 THEN N',' + COALESCE(@SQLNonDBA, N'') + N',' + COALESCE(@SQLDBA, N'')  
                ELSE N',' + COALESCE(@SQLNonDBA, N'') + COALESCE(@SQLDBA, N'')  
            END  
            + N'  
            FROM [stg].' + @StagingConsolidatedTable + N' stgp   
            JOIN mdm.tblHierarchy hr  
            ON stgp.HierarchyName = hr.Name AND hr.Entity_ID = ' + CONVERT(NVARCHAR(30), @Entity_ID) + N' ' + COALESCE(@SQLDBAJoin, N'') + N'  
            WHERE stgp.ImportStatus_ID = @StatusProcessing AND stgp.Batch_ID = @Batch_ID;  
    END  
    ELSE  
    BEGIN  
        INSERT INTO mdm.' + @HierarchyParentTable + N'  
        (   
            Version_ID,  
            Status_ID,  
            ValidationStatus_ID,  
            Name,  
            Code,  
            Hierarchy_ID,  
            EnterDTM,  
            EnterUserID,  
            EnterVersionID,  
            LastChgDTM,  
            LastChgUserID,  
            LastChgVersionID'  
        + COALESCE(@SQLNonDBAColumns, N'') + COALESCE(@SQLDBAColumns, N'') + N'   
        )  
        OUTPUT inserted.ID, inserted.Code, inserted.Code, inserted.Name, inserted.Name ' + @TranBlankColumn + @TranInsertedColumn + N'  
            INTO #TRANLOG  
        SELECT  
            @Version_ID,  
            1,  
            @NewAwaitingValidation,  
            stgp.Name,  
            stgp.Code,  
            hr.ID,  
            GETUTCDATE(),  
            @User_ID,  
            @Version_ID,  
            GETUTCDATE(),  
            @User_ID,  
            @Version_ID' +   
            CASE  
                WHEN LEN(COALESCE(@SQLNonDBA, N'') + COALESCE(@SQLDBA, N'')) = 0 THEN N''  
                WHEN LEN(COALESCE(@SQLNonDBA, N'')) > 0 AND LEN(COALESCE(@SQLDBA, N'')) > 0 THEN N',' + COALESCE(@SQLNonDBA, N'') + N',' + COALESCE(@SQLDBA, N'')  
                ELSE N',' + COALESCE(@SQLNonDBA, N'') + COALESCE(@SQLDBA, N'')  
            END  
            + N'  
            FROM [stg].' + @StagingConsolidatedTable + N' stgp   
            JOIN mdm.tblHierarchy hr  
            ON stgp.HierarchyName = hr.Name AND hr.Entity_ID = ' + CONVERT(NVARCHAR(30), @Entity_ID) + N' ' + COALESCE(@SQLDBAJoin, N'') + N'  
            WHERE stgp.ImportStatus_ID = @StatusProcessing AND stgp.Batch_ID = @Batch_ID;  
    END; -- IF  
              
    -- After the insertion add HR records for each mandatory hierarchies  
          
    INSERT INTO @TableHierarchy  
    SELECT DISTINCT ID AS Hierarchy_ID, [Name] AS Hierarchy_Name FROM mdm.tblHierarchy WHERE Entity_ID = ' + CONVERT(NVARCHAR(30), @Entity_ID) + N'   
          
        WHILE EXISTS(SELECT 1 FROM @TableHierarchy) BEGIN    
  
            SELECT TOP 1     
                @CurrentHierarchy_ID = Hierarchy_ID,  
                @CurrentHierarchy_Name = Hierarchy_Name    
            FROM @TableHierarchy;  
              
        -- Add the member to the root of the hierarchy.   
          
            INSERT INTO mdm.' + @HierarchyRelationshipTable + N'  
            (   
                [Version_ID]  
                ,[Status_ID]  
                ,[ValidationStatus_ID]  
                ,[Hierarchy_ID]  
                ,[Parent_HP_ID]  
                ,[ChildType_ID]  
                ,[Child_EN_ID]  
                ,[Child_HP_ID]  
                ,[SortOrder]  
                ,[LevelNumber]  
                ,[EnterDTM]  
                ,[EnterUserID]  
                ,[EnterVersionID]  
                ,[LastChgDTM]  
                ,[LastChgUserID]  
                ,[LastChgVersionID]  
            )  
            SELECT  
            @Version_ID,  
            1,  
            @NewAwaitingValidation,  
            @CurrentHierarchy_ID,  
            NULL,  
            2,  
            NULL,  
            hp.ID,  
            0,  
            0,  
            GETUTCDATE(),  
            @User_ID,  
            @Version_ID,  
            GETUTCDATE(),  
            @User_ID,  
            @Version_ID              
            FROM [stg].' + @StagingConsolidatedTable + N' stgp   
            INNER JOIN mdm.' + @HierarchyParentTable + N' hp   
            ON stgp.Code = hp.Code AND hp.Version_ID = @Version_ID  
            AND stgp.HierarchyName = @CurrentHierarchy_Name  
            WHERE stgp.ImportStatus_ID = @StatusProcessing AND stgp.Batch_ID = @Batch_ID;  
              
            IF @LogFlag = 1  
            BEGIN  
                -- Record addition of the members to the ROOT node of the hierarchy.  
                -- OldCode and NewCode are set to ROOT (this is the same as the existing transaction log).   
                INSERT INTO mdm.tblTransaction     
                (    
                    Version_ID,    
                    TransactionType_ID,    
                    OriginalTransaction_ID,    
                    Hierarchy_ID,    
                    Entity_ID,    
                    Member_ID,    
                    MemberType_ID,    
                    MemberCode,    
                    OldValue,    
                    OldCode,    
                    NewValue,    
                    NewCode,  
                    Batch_ID,    
                    EnterDTM,    
                    EnterUserID,    
                    LastChgDTM,    
                    LastChgUserID    
                )    
                SELECT     
                    @Version_ID, --Version_ID    
                    @HierarchyParentSetTransaction, --TransactionType_ID    
                    0, --OriginalTransaction_ID    
                    @CurrentHierarchy_ID, --Hierarchy_ID    
                    @Entity_ID, --Entity_ID    
                    hp.ID, --Member_ID    
                    @ConsolidatedMemberTypeID, --MemberType_ID    
                    stgp.Code,    
                    N''0'', --OldValue    
                    N''ROOT'', --OldCode    
                    N''0'', --NewValue    
                    N''ROOT'', --NewCode  
                    @Batch_ID,    
                    GETUTCDATE(),     
                    @User_ID,     
                    GETUTCDATE(),     
                    @User_ID    
                FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp   
                    ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
                    AND stgp.HierarchyName = @CurrentHierarchy_Name  
                    AND stgp.ImportStatus_ID = @StatusProcessing AND stgp.Batch_ID = @Batch_ID  
            END;  
                  
            DELETE FROM @TableHierarchy WHERE Hierarchy_ID = @CurrentHierarchy_ID  
          
        END; -- WHILE  
          
        --Update Change Tracking Groups when the attribute value is not NULL.   
        INSERT INTO @TABLECTG (  
			AttributeID,   
			AttributeName,   
			AttributeColumnName,  
			ChangeTrackingID,  
			AttributeType_ID,  
			DomainEntityTableName  
			)   
		SELECT DISTINCT   
			attr.ID,   
			attr.Name,   
			attr.TableColumn,  
			attr.ChangeTrackingGroup,  
			attr.AttributeType_ID,  
			ent.EntityTable  
		FROM mdm.tblAttribute attr  
		LEFT JOIN mdm.tblEntity ent ON ent.ID = attr.DomainEntity_ID  
		WHERE   
			attr.Entity_ID = ' + CONVERT(NVARCHAR(30), @Entity_ID) + N' AND   
			attr.ChangeTrackingGroup > 0 AND   
			attr.MemberType_ID = 2;  
  
        DECLARE @TrackGroupMax   INT,  
                @TrackGroupCount INT;  
                  
        SELECT @TrackGroupMax = COUNT(ID) FROM @TABLECTG;       
  
        SET @TrackGroupCount = 1;  
  
        WHILE @TrackGroupCount <= @TrackGroupMax BEGIN  
            SELECT   
                @ChangeTrackingGroup = ChangeTrackingID,  
                @ChangedAttributeName = AttributeName  
            FROM @TABLECTG  
            WHERE ID = @TrackGroupCount;  
  
            SET @SQLCTG = N''  
            UPDATE mdm.' + @HierarchyParentTable + N'  
            SET ChangeTrackingMask = ISNULL(ChangeTrackingMask, 0) | ISNULL(POWER(2,@ChangeTrackingGroup -1), 0)  
            FROM mdm.' + @HierarchyParentTable + N' hp  
                INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
                AND stgp.ImportStatus_ID = @ImportStatus_ID  
                AND stgp.Batch_ID = @Batch_ID  
                AND stgp.'' + quotename(@ChangedAttributeName) + N'' IS NOT NULL; '';  
                  
            EXEC sp_executesql @SQLCTG, N''@ChangeTrackingGroup INT, @Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT'', @ChangeTrackingGroup, @Version_ID, @StatusProcessing, @Batch_ID;  
  
            SET @TrackGroupCount += 1;  
  
        END; -- WHILE  
          
        IF @LogFlag = 1  
        BEGIN  
            --Log member creation transactions.  
            --In this case OldValue, OldCode, NewValue, and NewCode are blank.     
            INSERT INTO mdm.tblTransaction     
            (    
                Version_ID,    
                TransactionType_ID,    
                OriginalTransaction_ID,    
                Hierarchy_ID,    
                Entity_ID,    
                Member_ID,    
                MemberType_ID,    
                MemberCode,    
                OldValue,    
                OldCode,    
                NewValue,    
                NewCode,  
                Batch_ID,    
                EnterDTM,    
                EnterUserID,    
                LastChgDTM,    
                LastChgUserID    
            )    
            SELECT     
                @Version_ID, --Version_ID    
                @MemberCreateTransaction, --TransactionType_ID    
                0, --OriginalTransaction_ID    
                NULL, --Hierarchy_ID    
                @Entity_ID, --Entity_ID    
                hp.ID, --Member_ID    
                @ConsolidatedMemberTypeID, --MemberType_ID    
                stgp.Code,    
                N'''', --OldValue    
                N'''', --OldCode    
                N'''', --NewValue    
                N'''', --NewCode  
                @Batch_ID,    
                GETUTCDATE(),     
                @User_ID,     
                GETUTCDATE(),     
                @User_ID  		          
            FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp   
                ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
                AND stgp.ImportStatus_ID = @StatusProcessing AND stgp.Batch_ID = @Batch_ID;      
        END;  
          
        -- Inserting records is done. Updated the status.  
                           
        UPDATE [stg].' + @StagingConsolidatedTable + '   
            SET ImportStatus_ID = @StatusOK   
            WHERE ImportType in (@IT_MergeOptimistic,@IT_Insert,@IT_MergeOverwrite) AND ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID;  
  
        -- Set status to process updates.  
        UPDATE [stg].' + @StagingConsolidatedTable + N'   
            SET ImportStatus_ID = @StatusProcessing  
            WHERE ImportType in (@IT_MergeOptimistic, @IT_MergeOverwrite) AND Code in (SELECT Code FROM mdm.' + @HierarchyParentTable + N' WHERE Version_ID = @Version_ID)   
                AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
'                  
                  
SET @SQL += @TruncationGuard + N'  
        -- Update change tracking mask.  
        SET @TrackGroupCount = 1;  
  
        WHILE @TrackGroupCount <= @TrackGroupMax BEGIN  
            SELECT   
                @ChangeTrackingGroup = ChangeTrackingID,  
                @ChangedAttributeName = AttributeName,  
                @ConsolidatedAttributeName = AttributeColumnName,  
				@ChangedAttributeType_ID = AttributeType_ID,  
				@ChangedAttributeDomainEntityTableName = DomainEntityTableName  
            FROM @TABLECTG  
            WHERE ID = @TrackGroupCount;  
  
			IF @ChangedAttributeType_ID = @AttributeType_Domain  
        BEGIN  
            -- Update change tracking mask for merge optimistic.  
            SET @SQLCTG = N''  
            UPDATE hp  
            SET hp.ChangeTrackingMask = ISNULL(hp.ChangeTrackingMask, 0) | ISNULL(POWER(2, @ChangeTrackingGroup -1), 0)  
            FROM mdm.' + @HierarchyParentTable + N' hp  
			INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
            ON      hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
                AND stgp.ImportStatus_ID = @ImportStatus_ID  
                AND stgp.Batch_ID = @Batch_ID  
                AND stgp.ImportType = @ImportType  
                AND stgp.'' + quotename(@ChangedAttributeName) + N'' IS NOT NULL  
            LEFT JOIN [mdm].'' + quotename(@ChangedAttributeDomainEntityTableName) + N'' domain ON domain.Code = stgp.'' + quotename(@ChangedAttributeName) + N''  
            WHERE  
                COALESCE(NULLIF(domain.ID, hp.'' + quotename(@ConsolidatedAttributeName) + N''), NULLIF(hp.'' + quotename(@ConsolidatedAttributeName) + N'', domain.ID)) IS NOT NULL;   
                '';   
  
            EXEC sp_executesql @SQLCTG, N''@ChangeTrackingGroup INT, @Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT'', @ChangeTrackingGroup, @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOptimistic;  
  
            -- Update change tracking mask for merge overwrite.  
            SET @SQLCTG = N''  
            UPDATE hp  
            SET hp.ChangeTrackingMask = ISNULL(hp.ChangeTrackingMask, 0) | ISNULL(POWER(2,@ChangeTrackingGroup -1), 0)  
            FROM mdm.' + @HierarchyParentTable + N' hp  
            INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
            ON      hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
                AND stgp.ImportStatus_ID = @ImportStatus_ID  
                AND stgp.Batch_ID = @Batch_ID  
                AND stgp.ImportType = @ImportType  
            LEFT JOIN [mdm].'' + quotename(@ChangedAttributeDomainEntityTableName) + N'' domain ON domain.Code = stgp.'' + quotename(@ChangedAttributeName) + N''  
            WHERE  
                COALESCE(NULLIF(domain.ID, hp.'' + quotename(@ConsolidatedAttributeName) + N''), NULLIF(hp.'' + quotename(@ConsolidatedAttributeName) + N'', domain.ID)) IS NOT NULL;   
                '';   
  
            EXEC sp_executesql @SQLCTG, N''@ChangeTrackingGroup INT, @Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT'', @ChangeTrackingGroup, @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOverwrite;  
        END  
        ELSE  
        BEGIN  
            -- Update change tracking mask for merge optimistic.  
            SET @SQLCTG = N''  
            UPDATE mdm.' + @HierarchyParentTable + N'  
            SET ChangeTrackingMask = ISNULL(ChangeTrackingMask, 0) | ISNULL(POWER(2,@ChangeTrackingGroup -1), 0)  
            FROM mdm.' + @HierarchyParentTable + N' hp  
                INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
                AND stgp.ImportStatus_ID = @ImportStatus_ID  
                AND stgp.Batch_ID = @Batch_ID  
                AND stgp.ImportType = @ImportType  
                AND stgp.'' + quotename(@ChangedAttributeName) + N'' IS NOT NULL  
                AND COALESCE(NULLIF(stgp.'' + quotename(@ChangedAttributeName) + N'', hp.'' + quotename(@ConsolidatedAttributeName) + N''), NULLIF(hp.'' + quotename(@ConsolidatedAttributeName) + N'', stgp.'' + quotename(@ChangedAttributeName) + N'')) IS NOT NULL;   
                '';   
            
            EXEC sp_executesql @SQLCTG, N''@ChangeTrackingGroup INT, @Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT'', @ChangeTrackingGroup, @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOptimistic;  
  
            -- Update change tracking mask for merge overwrite.  
            SET @SQLCTG = N''  
            UPDATE mdm.' + @HierarchyParentTable + N'  
            SET ChangeTrackingMask = ISNULL(ChangeTrackingMask, 0) | ISNULL(POWER(2,@ChangeTrackingGroup -1), 0)  
            FROM mdm.' + @HierarchyParentTable + N' hp  
                INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
                AND stgp.ImportStatus_ID = @ImportStatus_ID  
                AND stgp.Batch_ID = @Batch_ID  
                AND stgp.ImportType = @ImportType  
                AND COALESCE(NULLIF(stgp.'' + quotename(@ChangedAttributeName) + N'', hp.'' + quotename(@ConsolidatedAttributeName) + N''), NULLIF(hp.'' + quotename(@ConsolidatedAttributeName) + N'', stgp.'' + quotename(@ChangedAttributeName) + N'')) IS NOT NULL;   
                '';   
                  
            EXEC sp_executesql @SQLCTG, N''@ChangeTrackingGroup INT, @Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT'', @ChangeTrackingGroup, @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOverwrite;  
		END  
  
            SET @TrackGroupCount += 1;  
  
        END; -- WHILE  
  
        --Process Updates  
        --Process update (Merge Optimistic)  
        IF @LogFlag = 0  
        BEGIN          
            UPDATE hp  
            SET ValidationStatus_ID = @AwaitingRevalidation  
                ,LastChgDTM = GETUTCDATE()  
                ,LastChgUserID = @User_ID  
                ,LastChgVersionID = @Version_ID  
                ' + COALESCE(@SQLMergeOptimisticDBA, N'') + N'  
                ' + COALESCE(@SQLMergeOptimisticNonDBA, N'') + N'  
            FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp   
            ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
            ' + COALESCE(@SQLDBAJoin, N'') + N'  
            WHERE stgp.ImportType =  @IT_MergeOptimistic   
                AND stgp.ImportStatus_ID = @StatusProcessing   
                AND stgp.Batch_ID = @Batch_ID;  
        END  
        ELSE  
        BEGIN  
            -- Insert update information into #TRANLOG table.    
            UPDATE hp  
            SET ValidationStatus_ID = @AwaitingRevalidation  
                ,LastChgDTM = GETUTCDATE()  
                ,LastChgUserID = @User_ID  
                ,LastChgVersionID = @Version_ID  
                ' + COALESCE(@SQLMergeOptimisticDBA, N'') + N'  
                ' + COALESCE(@SQLMergeOptimisticNonDBA, N'') + N'  
                OUTPUT inserted.ID, deleted.Code, inserted.Code, deleted.Name, inserted.Name ' + @TranDeletedColumn + @TranInsertedColumn + N'  
                INTO #TRANLOG      
            FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp   
            ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
            ' + COALESCE(@SQLDBAJoin, N'') + N'  
            WHERE stgp.ImportType =  @IT_MergeOptimistic   
                AND stgp.ImportStatus_ID = @StatusProcessing   
                AND stgp.Batch_ID = @Batch_ID;  
        END; -- IF      
              
        --Process update (Merge Overwrite)  
        IF @LogFlag = 0  
        BEGIN              
            UPDATE hp  
            SET ValidationStatus_ID = @AwaitingRevalidation  
                ,LastChgDTM = GETUTCDATE()  
                ,LastChgUserID = @User_ID  
                ,LastChgVersionID = @Version_ID  
                ' + COALESCE(@SQLMergeOverwriteDBA, N'') + N'  
                ' + COALESCE(@SQLMergeOverwriteNonDBA, N'') + N'  
            FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
            ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
            ' + COALESCE(@SQLDBAJoin, N'') + N'  
            WHERE stgp.ImportType =  @IT_MergeOverwrite   
                AND stgp.ImportStatus_ID = @StatusProcessing   
                AND stgp.Batch_ID = @Batch_ID;  
        END  
        ELSE  
        BEGIN  
            -- Insert update information into #TRANLOG table.    
            UPDATE hp  
            SET ValidationStatus_ID = @AwaitingRevalidation  
                ,LastChgDTM = GETUTCDATE()  
                ,LastChgUserID = @User_ID  
                ,LastChgVersionID = @Version_ID  
                ' + COALESCE(@SQLMergeOverwriteDBA, N'') + N'  
                ' + COALESCE(@SQLMergeOverwriteNonDBA, N'') + N'  
                OUTPUT inserted.ID, deleted.Code, inserted.Code, deleted.Name, inserted.Name ' + @TranDeletedColumn + @TranInsertedColumn + N'  
                INTO #TRANLOG  
            FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
            ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
            ' + COALESCE(@SQLDBAJoin, N'') + N'  
            WHERE stgp.ImportType =  @IT_MergeOverwrite   
                AND stgp.ImportStatus_ID = @StatusProcessing   
                AND stgp.Batch_ID = @Batch_ID;  
        END; --IF  
'  
                                   
SET @SQL += @TruncationGuard + N'  
        --Process name updates  
        IF @LogFlag = 0  
        BEGIN   
            UPDATE mdm.' + @HierarchyParentTable + N'  
            SET Name = stgp.Name,  
                ValidationStatus_ID = @AwaitingRevalidation,     
                LastChgDTM = GETUTCDATE(),  
                LastChgUserID = @User_ID,  
                LastChgVersionID = @Version_ID  
            FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID    
                AND LEN(COALESCE(stgp.Name, N'''')) > 0 AND COALESCE(hp.Name, N'''') <> stgp.Name  
                AND stgp.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite) AND stgp.ImportStatus_ID = @StatusProcessing  
                AND stgp.Batch_ID = @Batch_ID;  
        END  
        ELSE  
        BEGIN  
            -- Insert update information into #TRANLOG table.   
            UPDATE mdm.' + @HierarchyParentTable + N'  
            SET Name = stgp.Name,  
                ValidationStatus_ID = @AwaitingRevalidation,     
                LastChgDTM = GETUTCDATE(),  
                LastChgUserID = @User_ID,  
                LastChgVersionID = @Version_ID  
                OUTPUT inserted.ID, deleted.Code, inserted.Code, deleted.Name, inserted.Name ' + @TranDeletedColumn + @TranInsertedColumn + N'  
                INTO #TRANLOG  
            FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID    
                AND LEN(COALESCE(stgp.Name, N'''')) > 0 AND COALESCE(hp.Name, N'''') <> stgp.Name  
                AND stgp.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite) AND stgp.ImportStatus_ID = @StatusProcessing  
                AND stgp.Batch_ID = @Batch_ID;  
        END; --IF                  
                                                  
        --Process code updates  
        IF @LogFlag = 0  
        BEGIN   
            UPDATE mdm.' + @HierarchyParentTable + N'  
            SET Code = stgp.NewCode,  
                ValidationStatus_ID = @AwaitingRevalidation,     
                LastChgDTM = GETUTCDATE(),  
                LastChgUserID = @User_ID,  
                LastChgVersionID = @Version_ID  
            FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID    
                AND LEN(COALESCE(stgp.NewCode, N'''')) > 0   
                AND stgp.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite) AND stgp.ImportStatus_ID = @StatusProcessing  
                AND stgp.Batch_ID = @Batch_ID;  
        END  
        ELSE  
        BEGIN  
            -- Insert update information into #TRANLOG table.    
            UPDATE mdm.' + @HierarchyParentTable + N'  
            SET Code = stgp.NewCode,  
                ValidationStatus_ID = @AwaitingRevalidation,     
                LastChgDTM = GETUTCDATE(),  
                LastChgUserID = @User_ID,  
                LastChgVersionID = @Version_ID  
                OUTPUT inserted.ID, deleted.Code, inserted.Code, deleted.Name, inserted.Name ' + @TranDeletedColumn + @TranInsertedColumn + N'  
                INTO #TRANLOG  
            FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID    
                AND LEN(COALESCE(stgp.NewCode, N'''')) > 0   
                AND stgp.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite) AND stgp.ImportStatus_ID = @StatusProcessing  
                AND stgp.Batch_ID = @Batch_ID;  
        END; --IF  
                  
        IF @LogFlag = 1  
        BEGIN  
            DECLARE @TempTable TABLE(      
                ID			    INT,  
                TableColumn     NVARCHAR(128) NOT NULL,     
                DomainEntity_ID INT NULL,    
                SortOrder       INT,  
                DomainTable     SYSNAME NULL);  
                  
            DECLARE     @CurrentID              INT,  
                        @CurrentTableColumn     NVARCHAR(128),  
                        @CurrentDomainEntity_ID INT,  
                        @CurrentSortOrder       INT,  
                        @CurrentDomainTable     SYSNAME,  
                        @TranSQL                NVARCHAR(MAX) = N'''';  
  
            INSERT INTO @TempTable      
            SELECT    
                A.ID,  
                A.TableColumn,     
                A.DomainEntity_ID,      
                A.SortOrder,  
                E.EntityTable AS DomainTable      
            FROM   
            mdm.tblAttribute A    
            LEFT OUTER JOIN mdm.tblEntity E   
            ON A.DomainEntity_ID = E.ID         
            WHERE A.Entity_ID = @Entity_ID AND A.MemberType_ID = @ConsolidatedMemberTypeID  
            AND (A.IsSystem = 0 OR A.IsCode = 1 OR A.IsName = 1) -- Exclude system attributes other than Code and Name.     
            ORDER BY       
                SortOrder ASC;      
            
            -- For each attribute, set the attribute update information to the Transaction table.  
            WHILE EXISTS(SELECT 1 FROM @TempTable) BEGIN      
                SELECT TOP 1       
                    @CurrentID = ID,    
                    @CurrentTableColumn = TableColumn,      
                    @CurrentDomainEntity_ID = DomainEntity_ID,  
                    @CurrentSortOrder = SortOrder,  
                    @CurrentDomainTable = DomainTable  
                FROM @TempTable      
                ORDER BY SortOrder;  
                -- Get Old and New values from #TRANLOG table and insert into tblTransaction.  
                  
                IF @CurrentDomainEntity_ID IS NULL -- Handle non DBA    
                BEGIN  
              
                    SET @TranSQL = N''    
            INSERT INTO mdm.tblTransaction     
            (    
                Version_ID,    
                TransactionType_ID,    
                OriginalTransaction_ID,    
                Hierarchy_ID,    
                Entity_ID,  
                Attribute_ID,    
                Member_ID,    
                MemberType_ID,    
                MemberCode,    
                OldValue,    
                OldCode,    
                NewValue,    
                NewCode,  
                Batch_ID,    
                EnterDTM,    
                EnterUserID,    
                LastChgDTM,    
                LastChgUserID    
            )    
            SELECT     
                @Version_ID, --Version_ID    
                3, --TransactionType_ID (Member attribute set)    
                0, --OriginalTransaction_ID    
                NULL, --Hierarchy_ID    
                @Entity_ID, --Entity_ID  
                @Attribute_ID, -- Attribute_ID   
                MemberID, --Member_ID    
                2, -- Consolidated Member Type ID      
                CASE WHEN ISNULL(Code, N'''''''') = N'''''''' THEN New_Code ELSE Code END,    
                '' + @CurrentTableColumn + N'',   
                '' + @CurrentTableColumn + N'',   
                New_'' + @CurrentTableColumn + N'',   
                New_'' + @CurrentTableColumn + N'',   
                @Batch_ID,    
                GETUTCDATE(),     
                @User_ID,     
                GETUTCDATE(),     
                @User_ID    
            FROM #TRANLOG  
            WHERE COALESCE(NULLIF('' + @CurrentTableColumn + N'', New_'' + @CurrentTableColumn + N''), NULLIF(New_'' + @CurrentTableColumn + N'', '' + @CurrentTableColumn + N'')) IS NOT NULL   
                '';  
                  
                    EXEC sp_executesql @TranSQL, N''@Version_ID INT, @Attribute_ID INT, @Entity_ID INT, @Batch_ID INT, @User_ID INT '', @Version_ID, @CurrentID, @Entity_ID, @Batch_ID, @User_ID;  
                END  
                ELSE  
                BEGIN  
                -- Handle DBA  
                -- Get the old code value and the new code value by table join.    
                    SET @TranSQL = N''    
            INSERT INTO mdm.tblTransaction     
            (    
                Version_ID,    
                TransactionType_ID,    
                OriginalTransaction_ID,    
                Hierarchy_ID,    
                Entity_ID,  
                Attribute_ID,    
                Member_ID,    
                MemberType_ID,    
                MemberCode,    
                OldValue,    
                OldCode,    
                NewValue,    
                NewCode,  
                Batch_ID,    
                EnterDTM,    
                EnterUserID,    
                LastChgDTM,    
                LastChgUserID    
            )    
            SELECT     
                @Version_ID, --Version_ID    
                3, --TransactionType_ID (Member attribute set)    
                0, --OriginalTransaction_ID    
                NULL, --Hierarchy_ID    
                @Entity_ID, --Entity_ID  
                @Attribute_ID, -- Attribute_ID   
                T.MemberID, --Member_ID    
                2, -- Consolidated Member Type ID        
                CASE WHEN ISNULL(T.Code, N'''''''') = N'''''''' THEN T.New_Code ELSE T.Code END,    
                T.'' + @CurrentTableColumn + N'',   
                DO.Code,   
                New_'' + @CurrentTableColumn + N'',   
                DN.Code,   
                @Batch_ID,    
                GETUTCDATE(),     
                @User_ID,     
                GETUTCDATE(),     
                @User_ID    
            FROM #TRANLOG T  
            LEFT OUTER JOIN mdm.'' + QUOTENAME(@CurrentDomainTable) + N'' DN  
            ON T.New_'' + @CurrentTableColumn + N'' = DN.ID  
            LEFT OUTER JOIN mdm.'' + QUOTENAME(@CurrentDomainTable) + N'' DO  
            ON T.'' + @CurrentTableColumn + N'' = DO.ID  
            WHERE COALESCE(NULLIF(T.'' + @CurrentTableColumn + N'', T.New_'' + @CurrentTableColumn + N''), NULLIF(T.New_'' + @CurrentTableColumn + N'', T.'' + @CurrentTableColumn + N'')) IS NOT NULL    
                '';  
                  
                    EXEC sp_executesql @TranSQL, N''@Version_ID INT, @Attribute_ID INT, @Entity_ID INT, @Batch_ID INT, @User_ID INT '', @Version_ID, @CurrentID, @Entity_ID, @Batch_ID, @User_ID;  
                  
                END; --IF  
                    
                DELETE FROM @TempTable WHERE ID = @CurrentID;      
  
            END; --WHILE  
  
            TRUNCATE TABLE #TRANLOG;  
              
        END; --IF  
          
        -- Updating is done. Update the status.  
                  
        UPDATE [stg].' + @StagingConsolidatedTable + N'   
            SET ImportStatus_ID = @StatusOK  
            FROM [stg].' + @StagingConsolidatedTable + N'  
            WHERE ImportType in (@IT_MergeOptimistic,@IT_MergeOverwrite) AND ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID;  
  
        -- Set status to process Delete (soft delete) and Purge (hard delete)  
        UPDATE [stg].' + @StagingConsolidatedTable + N'  
        SET ImportStatus_ID = @StatusProcessing  
        WHERE ImportType IN (@IT_Delete,@IT_Purge) AND IsNuLL(ErrorCode, 0) = 0   
        AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
        --Determine if any purge or delete records exist  
        IF Exists(SELECT Code FROM [stg].' + @StagingConsolidatedTable + N'   
        WHERE ImportType IN (@IT_Delete,@IT_Purge) AND ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID)  
        BEGIN              
            -- Deactivate members in the hierarchy table.   
            -- The same process as the one that mdm.udpMemberStatusSet does when the status is set to inactive.  
                                                
            UPDATE hr  
                SET Status_ID = @MemberStatusInactive     
                ,LevelNumber = -1      
            FROM mdm.' + @HierarchyRelationshipTable + N' hr  
                INNER JOIN mdm.' + @HierarchyParentTable + N' hp   
                    ON hr.Child_HP_ID = hp.ID   
                    AND hr.Version_ID = @Version_ID   
                    AND hr.ChildType_ID = @ConsolidatedMemberTypeID  
                INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                    ON hp.Code = stgp.Code   
                    AND hp.Version_ID = @Version_ID  
                    AND stgp.ImportStatus_ID = @StatusProcessing   
                    AND stgp.Batch_ID = @Batch_ID  
                    AND stgp.ImportType IN (@IT_Delete, @IT_Purge);             
                      
            UPDATE hr  
                SET Parent_HP_ID = NULL    
                ,LevelNumber = -1      
            FROM mdm.' + @HierarchyRelationshipTable + N' hr  
                INNER JOIN mdm.' + @HierarchyParentTable + N' hp   
                    ON hr.Parent_HP_ID = hp.ID   
                    AND hr.Version_ID = @Version_ID  
                INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                    ON hp.Code = stgp.Code   
                    AND hp.Version_ID = @Version_ID  
                    AND stgp.ImportStatus_ID = @StatusProcessing   
                    AND stgp.Batch_ID = @Batch_ID  
                    AND stgp.ImportType IN (@IT_Delete, @IT_Purge);           
                      
            -- Before deleting the parent member remove it from the HierarchyTable when it remains to be a child node.   
            DELETE FROM mdm.' + @HierarchyRelationshipTable + N'  
            FROM mdm.' + @HierarchyRelationshipTable + N' hr  
                INNER JOIN mdm.' + @HierarchyParentTable + N' hp   
                    ON hr.Child_HP_ID = hp.ID   
                    AND hr.Version_ID = @Version_ID  
                    AND hr.Status_ID = @MemberStatusInactive   
                    AND hr.LevelNumber = -1  
                INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                    ON hp.Code = stgp.Code   
                    AND hp.Version_ID = @Version_ID  
                    AND stgp.ImportStatus_ID = @StatusProcessing   
                    AND stgp.Batch_ID = @Batch_ID  
                    AND stgp.ImportType = @IT_Purge;  
  
            -- Soft delete members when the import type is delete.                  
            UPDATE mdm.' + @HierarchyParentTable + N'  
                SET Status_ID = @MemberStatusInactive  
            FROM mdm.' + @HierarchyParentTable + N' hp   
                INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                    ON hp.Code = stgp.Code   
                    AND hp.Version_ID = @Version_ID  
                    AND stgp.ImportStatus_ID = @StatusProcessing   
                    AND stgp.Batch_ID = @Batch_ID  
                    AND stgp.ImportType = @IT_Delete;       
           
             IF @LogFlag = 1  
            BEGIN  
                --Log delete and purge of members.  
                --Because there is no transaction status for hard delete, record hard delete as de-activation.      
                INSERT INTO mdm.tblTransaction     
                (    
                    Version_ID,    
                    TransactionType_ID,    
                    OriginalTransaction_ID,    
                    Hierarchy_ID,    
                    Entity_ID,    
                    Member_ID,    
                    MemberType_ID,    
                    MemberCode,    
                    OldValue,    
                    OldCode,    
                    NewValue,    
                    NewCode,  
                    Batch_ID,    
                    EnterDTM,    
                    EnterUserID,    
                    LastChgDTM,    
                    LastChgUserID    
                )    
                SELECT     
                    @Version_ID, --Version_ID    
                    @MemberStatusSetTransaction, --TransactionType_ID    
                    0, --OriginalTransaction_ID    
                    NULL, --Hierarchy_ID    
                    @Entity_ID, --Entity_ID    
                    hp.ID, --Member_ID    
                    @ConsolidatedMemberTypeID, --MemberType_ID    
                    stgp.Code,    
                    N''1'', --OldValue    
                    N''Active'', --OldCode    
                    N''2'', --NewValue    
                    N''De-Activated'', --NewCode  
                    @Batch_ID,    
                    GETUTCDATE(),     
                    @User_ID,     
                    GETUTCDATE(),     
                    @User_ID  		      
                FROM mdm.' + @HierarchyParentTable + N' hp INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                    ON hp.Code = stgp.Code AND hp.Version_ID = @Version_ID  
                    AND stgp.ImportStatus_ID = @StatusProcessing AND stgp.Batch_ID = @Batch_ID  
                    AND stgp.ImportType IN (@IT_Delete, @IT_Purge);  
            END;  
                                      
            -- Hard delete members when the import type is Purge.  
            DELETE FROM mdm.' + @HierarchyParentTable + N'  
            FROM mdm.' + @HierarchyParentTable + N' hp   
                INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                    ON hp.Code = stgp.Code   
                    AND hp.Version_ID = @Version_ID  
                    AND stgp.ImportStatus_ID = @StatusProcessing   
                    AND stgp.Batch_ID = @Batch_ID  
                    AND stgp.ImportType = @IT_Purge;   
              
            -- Delete member security              
            DELETE FROM mdm.tblSecurityRoleAccessMember  
            FROM mdm.tblSecurityRoleAccessMember sra  
                INNER JOIN mdm.' + @HierarchyParentTable + N' hp   
                    ON sra.Member_ID = hp.ID   
                    AND sra.Version_ID = @Version_ID  
                    AND sra.Entity_ID = @Entity_ID   
                    AND sra.HierarchyType_ID IN (0, 1) -- Derived and Explicit Hierarchy  
                    AND sra.MemberType_ID = @ConsolidatedMemberTypeID  
                INNER JOIN [stg].' + @StagingConsolidatedTable + N' stgp  
                    ON hp.Code = stgp.Code   
                    AND hp.Version_ID = @Version_ID  
                    AND stgp.ImportStatus_ID = @StatusProcessing   
                    AND stgp.Batch_ID = @Batch_ID  
                    AND stgp.ImportType IN (@IT_Delete, @IT_Purge);  
      
            EXEC mdm.udpSecurityMemberProcessRebuildModelVersion @Version_ID, 1;  
  
        END; --IF              
  
    --Update the status after the delete  
        UPDATE [stg].' + @StagingConsolidatedTable + '   
            SET ImportStatus_ID = @StatusOK   
            WHERE ImportType IN (@IT_Delete, @IT_Purge) AND ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID;  
  
    --Get the number of errors for the batch ID  
        SELECT @ErrorCount = COUNT(ID) FROM [stg].' + @StagingConsolidatedTable + N'  
            WHERE Batch_ID = @Batch_ID AND ImportStatus_ID = @StatusError;  
      
    -- Set the status of the batch as Not Running (Completed).  
    -- Set the error member count.  
        UPDATE mdm.tblStgBatch   
            SET Status_ID = @Completed,  
                LastRunEndDTM = GETUTCDATE(),  
                LastRunEndUserID = @User_ID ,  
                ErrorMemberCount = @ErrorCount   
            WHERE ID = @Batch_ID  
               
    -- Reset member count after the staging.  
        UPDATE mdm.tblUserMemberCount   
            SET LastCount= -1,  
                LastChgDTM = GETUTCDATE()  
            WHERE Entity_ID = @Entity_ID AND Version_ID = @Version_ID AND MemberType_ID = 2  
                  
        IF @TranCounter = 0 COMMIT TRANSACTION; --Commit only if we are not nested    
  
        RETURN 0;  
                          
    END TRY    
    BEGIN CATCH    
        SET NOCOUNT OFF;    
  
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
        RETURN @OtherRuntimeError;    
            
    END CATCH      
        SET NOCOUNT OFF;    
    END;'  
                      
    --PRINT @SQL;  
    EXEC sp_executesql @SQL;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
