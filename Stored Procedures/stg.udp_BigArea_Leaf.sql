SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [stg].[udp_BigArea_Leaf]  
@VersionName NVARCHAR(50), @LogFlag INT=NULL, @BatchTag NVARCHAR(50)=N'', @Batch_ID INT=NULL  
WITH EXECUTE AS 'mds_schema_user'  
AS  
BEGIN  
  
SET NOCOUNT ON;  
DECLARE @UserName           NVARCHAR(100),  
@Model_ID                   INT,  
@Version_ID                 INT,  
@VersionStatus_ID           INT,  
@VersionStatus_Committed    INT = 3,  
@Entity_ID                  INT,  
@MemberCount                INT = 0,  
@ErrorCount                 INT = 0,  
@NewBatch_ID                INT = 0,  
@GetNewBatch_ID             INT = 0,  
@CurrentHierarchy_ID        INT,  
@User_ID                    INT = 0, -- The user ID used for logging is 0.  
  
-- member type constant  
@LeafMemberTypeID           INT = 1,  
  
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
@IT_DeleteSetNullToRef      INT = 5,  
@IT_PurgeSetNullToRef       INT = 6,  
@IT_Max                     INT = 6,  
  
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
@Member_ID                  INT,  
@TableColumn                NVARCHAR(128),  
@TableName                  SYSNAME,  
@FKSQL                      NVARCHAR(MAX) = N'',  
  
--Special attribute values that are used as aliases for NULL, to allow Merge Optimistic mode to change values to NULL..  
--When changing these values, also change them in the GetPostfixItemSql() method of \Core\BusinessLogic\BusinessRules\SqlGeneration\SqlGenerator.cs  
@NULLNumber                 DECIMAL(38,0) = -98765432101234567890,  
@NULLText                   NVARCHAR(10) = N'~NULL~',  
@NULLDateTime               NVARCHAR(30) = N'5555-11-22T12:34:56',  
  
--Entity member status  
@MemberStatusOK             INT = 1,  
@MemberStatusInactive       INT = 2,  
  
--Validation status  
@NewAwaitingValidation      INT = 0,  
@AwaitingRevalidation       INT = 4,  
@AwaitingDependentMemberRevalidation  INT = 5,  
  
@DependentValidationStatus      INT,  
@DependentEntityTable		    sysname,  
@DependentAttributeColumnName   sysname,  
  
--Code generation  
@AllowCodeGen               BIT = 0,  
@StartCode                  BIGINT,   
@EndCode                    BIGINT,  
@NumberOfCodes              INT,  
              
--Change Tracking Group  
@ChangedAttributeName       NVARCHAR(50),  
@EntityAttributeName		NVARCHAR(50),  
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
  
@MemberAttributes           mdm.MemberAttributes,  
  
--XACT_STATE() constancts  
@UncommittableTransaction   INT = -1;  
              
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
  
DECLARE @MandatoryHierarchy TABLE  
(  
    Hierarchy_ID INT  
);  
  
SET @Model_ID = 2  
SET @Entity_ID = 8  
  
-- Check for invalid Version Name.  
IF @VersionName IS NULL RETURN @VersionNameError;  
  
-- Set @AllowCodeGen (1: Code generation is allowed for the entity. 0: Code generation is not allowed for the entity)  
EXEC @AllowCodeGen = mdm.udpIsCodeGenEnabled @Entity_ID;   
  
-- Trim batch tag  
SET @BatchTag = LTRIM(RTRIM(@BatchTag));  
  
IF LEN(@BatchTag) > 0 AND @Batch_ID IS NOT NULL BEGIN  
    RAISERROR('MDSERR310043|The Batch Tag and the Batch ID cannot be specified at the same time.', 16, 1);  
    RETURN @BatchIDAndBatchTagSpecifiedError;  
END; --IF  
  
IF NOT EXISTS(SELECT 1 FROM mdm.tblModelVersion WHERE Model_ID = @Model_ID AND [Name] = @VersionName) BEGIN  
    RAISERROR('MDSERR100036|The version name is not valid.', 16, 1);  
    RETURN @VersionNameError;  
END; --IF  
  
SELECT @Version_ID = ID, @VersionStatus_ID = Status_ID FROM mdm.tblModelVersion WHERE Model_ID = @Model_ID AND [Name] = @VersionName;  
  
--Ensure that Version is not committed  
IF (@VersionStatus_ID = @VersionStatus_Committed) BEGIN  
    RAISERROR('MDSERR310040|Data cannot be loaded into a committed version.', 16, 1);  
    RETURN @VersionStatusError;  
END;  
  
--Check if there is any record to process.  
IF LEN(@BatchTag) > 0 BEGIN  
    SELECT @MemberCount = COUNT(ID) FROM [stg].[BigArea_Leaf]  
        WHERE LTRIM(RTRIM(BatchTag)) = @BatchTag AND ImportStatus_ID = @StatusDefault;  
    IF @MemberCount = 0 BEGIN  
        RETURN @NoRecordToProcessError;  
    END; -- IF  
END; -- IF  
ELSE BEGIN  
    IF @Batch_ID IS NOT NULL BEGIN  
        SELECT @MemberCount = COUNT(ID) FROM [stg].[BigArea_Leaf]  
            WHERE Batch_ID = @Batch_ID AND ImportStatus_ID = @StatusDefault;  
        IF @MemberCount = 0 BEGIN  
            RETURN @NoRecordToProcessError;  
        END; -- IF  
    END; -- IF  
END; --IF  
  
-- If neither @BatchTag nor @Batch_ID is specified assume that a blank @BatchTag is specified.  
  
IF @Batch_ID IS NULL AND LEN(@BatchTag) = 0 BEGIN  
    SELECT @MemberCount = COUNT(ID) FROM [stg].[BigArea_Leaf]  
        WHERE (BatchTag IS NULL OR LTRIM(RTRIM(BatchTag)) = N'') AND ImportStatus_ID = @StatusDefault;  
    IF @MemberCount = 0 BEGIN  
        RETURN @NoRecordToProcessError;  
    END; -- IF  
END; -- IF  
  
--Check if there is any record with an invalid status.  
IF LEN(@BatchTag) > 0 BEGIN  
    IF EXISTS (SELECT stgl.ID FROM [stg].[BigArea_Leaf] stgl  
        INNER JOIN mdm.tblStgBatch stgb  
        ON LTRIM(RTRIM(stgl.BatchTag)) = LTRIM(RTRIM(stgb.BatchTag)) AND stgb.Status_ID = @Running  
        WHERE LTRIM(RTRIM(stgl.BatchTag)) = @BatchTag AND stgl.ImportStatus_ID = @StatusDefault) BEGIN  
        RAISERROR('MDSERR310029|The status of the specified batch is not valid.', 16, 1);  
        RETURN @BatchStatusError;  
    END; -- IF  
END; -- IF  
  
IF @Batch_ID IS NOT NULL BEGIN  
    IF EXISTS (SELECT stgl.ID FROM [stg].[BigArea_Leaf] stgl  
        INNER JOIN mdm.tblStgBatch stgb  
        ON stgl.Batch_ID = stgb.ID AND stgb.Status_ID IN (@Running, @QueueToClear, @Cleared)  
        WHERE stgl.Batch_ID = @Batch_ID AND stgl.ImportStatus_ID = @StatusDefault) BEGIN  
  
        RAISERROR('MDSERR310029|The status of the specified batch is not valid.', 16, 1);  
        RETURN @BatchStatusError;  
    END; -- IF  
END; -- IF  
  
IF @Batch_ID IS NOT NULL  BEGIN  
    IF NOT EXISTS (SELECT ID FROM mdm.tblStgBatch WHERE ID = @Batch_ID AND Status_ID NOT IN (@Running, @QueueToClear, @Cleared)  
                   AND Version_ID = @Version_ID AND Entity_ID = @Entity_ID AND MemberType_ID = 1) BEGIN  
        SET @GetNewBatch_ID = @BatchIDNotFound  
    END; --IF  
END; --IF  
ELSE BEGIN  
    -- Check if udpEntityStagingFlagForProcessing already assigned a new batch ID (in this case the status is QueuedToRun).  
    SELECT TOP 1 @Batch_ID = ID FROM mdm.tblStgBatch  
        WHERE LTRIM(RTRIM(BatchTag)) = @BatchTag AND Status_ID = @QueuedToRun  
        AND Version_ID = @Version_ID AND Entity_ID = @Entity_ID AND MemberType_ID = @LeafMemberTypeID ORDER BY ID DESC  
  
    IF @Batch_ID IS NULL BEGIN  
        SET @GetNewBatch_ID = @BatchIDForBatchTagNotFound  
    END; --IF  
    ELSE BEGIN  
        -- Set the member count  
        UPDATE mdm.tblStgBatch  
        SET TotalMemberCount = @MemberCount  
        WHERE LTRIM(RTRIM(BatchTag)) = @BatchTag AND Status_ID = @QueuedToRun  
            AND Version_ID = @Version_ID AND Entity_ID = @Entity_ID AND MemberType_ID = @LeafMemberTypeID  
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
        1,  
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
        UPDATE [stg].[BigArea_Leaf]  
        SET Batch_ID = @NewBatch_ID  
        WHERE Batch_ID = @Batch_ID AND ImportStatus_ID = @StatusDefault  
    END; --IF  
    ELSE BEGIN  
        UPDATE [stg].[BigArea_Leaf]  
        SET Batch_ID = @NewBatch_ID  
        WHERE IsNULL(BatchTag, N'') = @BatchTag AND ImportStatus_ID = @StatusDefault  
    END; --IF  
  
    SET @Batch_ID = @NewBatch_ID;  
END --IF  
ELSE BEGIN  
    -- The user specified a valid batch ID.  
    -- Set the status of the batch as Running and set the total member count.  
    UPDATE mdm.tblStgBatch  
    SET Status_ID = @Running,  
        TotalMemberCount = @MemberCount,  
        LastRunStartDTM = GETUTCDATE(),  
        LastRunStartUserID = @User_ID  
    WHERE ID = @Batch_ID  
END; --IF  
  
-- Set ErrorCode = 0  
UPDATE [stg].[BigArea_Leaf]  
SET ErrorCode = 0  
WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
--Error Check all staged members  
--Error 210001 Binary Location 2^1: Multiple Records for the same member record  
UPDATE [stg].[BigArea_Leaf]  
SET ErrorCode = IsNull(ErrorCode,0) | 2  
WHERE Code in (SELECT Code FROM [stg].[BigArea_Leaf] WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID group by Code having COUNT(*) > 1);  
  
--Error 210006 Binary Location 2^3: Member Code is inactive.  
-- The rule is not applicable when purging the member.  
UPDATE stgl  
SET ErrorCode = IsNull(ErrorCode,0) | 8  
FROM [stg].[BigArea_Leaf] stgl  
    INNER JOIN mdm.[tbl_2_8_EN] en   
    ON stgl.Code = en.Code AND en.Version_ID = @Version_ID AND en.Status_ID = @MemberStatusInactive  
    WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID AND ImportType <> @IT_Purge AND ImportType <> @IT_PurgeSetNullToRef;  
      
IF (@AllowCodeGen = 0)  
BEGIN  
    --Error 210035 Binary Location 2^5: Code generation is not allowed for the entity, Code is Mandatory  
    UPDATE [stg].[BigArea_Leaf]  
        SET ErrorCode = IsNull(ErrorCode,0) | 32  
        WHERE IsNull(Code, N'') = N'' AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
END  
ELSE  
BEGIN  
    --Error 210035 Binary Location 2^5: Code generation is allowed for the entity and the Code is an empty string (NULL is allowed).   
    UPDATE [stg].[BigArea_Leaf]  
        SET ErrorCode = IsNull(ErrorCode,0) | 32  
        WHERE Code = N'' AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
END; --IF  
  
--Error 210041 Binary Location 2^6: ROOT is not a valid MemberCode  
UPDATE [stg].[BigArea_Leaf]  
SET ErrorCode = IsNull(ErrorCode,0) | 64  
WHERE UPPER(Code) = N'ROOT' AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
--Error 210042 Binary Location 2^7: MDMUnused is not a valid MemberCode  
UPDATE [stg].[BigArea_Leaf]  
SET ErrorCode = IsNull(ErrorCode,0) | 128  
WHERE UPPER(Code) = N'MDMUNUSED' AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
--Error 300002 Binary Location 2^8: The member code is not valid  
UPDATE stgl  
SET ErrorCode = IsNull(ErrorCode,0) | 256  
FROM [stg].[BigArea_Leaf] stgl  
    LEFT OUTER JOIN mdm.[tbl_2_8_EN] en   
    ON stgl.Code = en.Code AND en.Version_ID = @Version_ID   
WHERE ImportType IN (@IT_Delete, @IT_Purge, @IT_DeleteSetNullToRef, @IT_PurgeSetNullToRef)   
    AND ImportStatus_ID = @StatusDefault  
    AND Batch_ID = @Batch_ID AND en.Code IS NULL;  
  
--Error 300003 Binary Location 2^9: The Member code already exists  
--Verify uniqueness of Code against the entity table  
UPDATE [stg].[BigArea_Leaf]  
SET ErrorCode = IsNull(ErrorCode,0) | 512  
FROM [stg].[BigArea_Leaf] sc  
    INNER JOIN mdm.[tbl_2_8_EN] AS tSource ON sc.Code = tSource.Code  
WHERE tSource.Version_ID = @Version_ID AND sc.ImportType = @IT_Insert  
    AND sc.ImportStatus_ID = @StatusDefault AND sc.Batch_ID = @Batch_ID;  
  
--Error 300003 Binary Location 2^9: The Member code already exists  
--Verify uniqueness of the new code against the entity table  
UPDATE [stg].[BigArea_Leaf]  
SET ErrorCode = IsNull(ErrorCode,0) | 512  
FROM [stg].[BigArea_Leaf] sc  
    INNER JOIN mdm.[tbl_2_8_EN] AS tSource ON sc.NewCode = tSource.Code  
WHERE tSource.Version_ID = @Version_ID AND sc.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite)  
    AND sc.ImportStatus_ID = @StatusDefault AND sc.Batch_ID = @Batch_ID;  
  
--Error 210058 Binary Location 2^10: Invalid ImportType  
UPDATE [stg].[BigArea_Leaf]  
SET ErrorCode = IsNull(ErrorCode,0) | 1024  
WHERE ImportType > @IT_Max AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
--Set ImportStatus on all records with at least one error  
UPDATE [stg].[BigArea_Leaf]  
SET ImportStatus_ID = @StatusError  
WHERE ErrorCode > 0 AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
--Start transaction, being careful to check if we are nested  
DECLARE @TranCounter INT;   
SET @TranCounter = @@TRANCOUNT;  
IF @TranCounter > 0 SAVE TRANSACTION TX;  
ELSE BEGIN TRANSACTION;  
  
BEGIN TRY  
      
IF @AllowCodeGen = 1   
BEGIN  
    --Gather up the valid user provided codes.    
    DECLARE @CodesToProcess mdm.MemberCodes;    
      
    INSERT @CodesToProcess (MemberCode)                     
    SELECT Code FROM [stg].[BigArea_Leaf]  
    WHERE ErrorCode = 0 AND ImportStatus_ID = @StatusDefault   
        AND Batch_ID = @Batch_ID AND Code IS NOT NULL;  
    
    INSERT @CodesToProcess (MemberCode)                     
    SELECT NewCode FROM [stg].[BigArea_Leaf]  
    WHERE ErrorCode = 0 AND ImportStatus_ID = @StatusDefault   
        AND Batch_ID = @Batch_ID AND NewCode IS NOT NULL;  
          
    --Process the user-provided codes to update the code gen info table with the largest one.    
    EXEC mdm.udpProcessCodes @Entity_ID, @CodesToProcess;        
  
END; --IF       
                      
--If code generation is allowed populate new codes into the staging table.  
IF @AllowCodeGen = 1   
BEGIN  
    --Generate the codes.                         
    SELECT @NumberOfCodes = COUNT(*) FROM [stg].[BigArea_Leaf]  
    WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID AND Code IS NULL;  
  
    EXEC mdm.udpGenerateCodeRange @Entity_ID = @Entity_ID, @NumberOfCodesToGenerate = @NumberOfCodes, @CodeRangeStart = @StartCode OUTPUT, @CodeRangeEnd = @EndCode OUTPUT;    
      
    DECLARE @CodeCounter BIGINT = @StartCode - 1;     
                                        
    --Set generated codes into the staging table.      
    UPDATE [stg].[BigArea_Leaf]   
    SET @CodeCounter += 1,  
        Code = CONVERT(NVARCHAR(25), @CodeCounter)    
    WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID AND Code IS NULL;  
  
END; -- IF       
  
--Table for transaction log  
CREATE TABLE #TRANLOG  
(  
            MemberID    INT  
            ,Code       NVARCHAR(250)  
            ,New_Code    NVARCHAR(250)  
            ,Name       NVARCHAR(250) NULL  
            ,New_Name    NVARCHAR(250) NULL  
  
);  
  
--Process Insert all new error free records into MDS internal table.  
UPDATE [stg].[BigArea_Leaf]  
SET ImportStatus_ID = @StatusProcessing  
FROM [stg].[BigArea_Leaf] stgl  
LEFT OUTER JOIN  mdm.[tbl_2_8_EN] en  
    ON  stgl.Code = en.Code AND en.Version_ID = @Version_ID   
WHERE stgl.Batch_ID = @Batch_ID   
    AND stgl.ImportType in (@IT_MergeOptimistic,@IT_Insert,@IT_MergeOverwrite)   
    AND stgl.ImportStatus_ID = @StatusDefault   
    AND en.Code IS NULL;  
  
--Insert the codes into @MemberAttributes table.  
INSERT INTO @MemberAttributes  
(MemberCode)  
SELECT  
    Code  
FROM [stg].[BigArea_Leaf]  
WHERE ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID;  
  
IF @LogFlag = 0  
BEGIN  
    INSERT INTO mdm.[tbl_2_8_EN]  
    (  
        Version_ID,  
        Status_ID,  
        ValidationStatus_ID,  
        Name,  
        Code,  
        EnterDTM,  
        EnterUserID,  
        EnterVersionID,  
        LastChgDTM,  
        LastChgUserID,  
        LastChgVersionID  
    )  
    SELECT  
        @Version_ID,  
        1,  
        @NewAwaitingValidation,  
        stgl.Name,  
        stgl.Code,  
        GETUTCDATE(),  
        @User_ID,  
        @Version_ID,  
        GETUTCDATE(),  
        @User_ID,  
        @Version_ID  
    FROM [stg].[BigArea_Leaf] stgl   
    WHERE stgl.ImportStatus_ID = @StatusProcessing AND stgl.Batch_ID = @Batch_ID;  
END  
ELSE  
BEGIN  
    INSERT INTO mdm.[tbl_2_8_EN]  
    (  
        Version_ID,  
        Status_ID,  
        ValidationStatus_ID,  
        Name,  
        Code,  
        EnterDTM,  
        EnterUserID,  
        EnterVersionID,  
        LastChgDTM,  
        LastChgUserID,  
        LastChgVersionID  
    )  
    OUTPUT inserted.ID, inserted.Code, inserted.Code, inserted.Name, inserted.Name   
        INTO #TRANLOG  
    SELECT  
        @Version_ID,  
        1,  
        @NewAwaitingValidation,  
        stgl.Name,  
        stgl.Code,  
        GETUTCDATE(),  
        @User_ID,  
        @Version_ID,  
        GETUTCDATE(),  
        @User_ID,  
        @Version_ID  
    FROM [stg].[BigArea_Leaf] stgl   
    WHERE stgl.ImportStatus_ID = @StatusProcessing AND stgl.Batch_ID = @Batch_ID;  
END; --IF  
  
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
    attr.Entity_ID = 8 AND   
    attr.ChangeTrackingGroup > 0 AND   
    attr.MemberType_ID = 1;  
  
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
  
    SET @SQLCTG = N'  
    UPDATE mdm.[tbl_2_8_EN]  
    SET ChangeTrackingMask = ISNULL(ChangeTrackingMask, 0) | ISNULL(POWER(2,@ChangeTrackingGroup -1), 0)  
    FROM mdm.[tbl_2_8_EN] en  
        INNER JOIN [stg].[BigArea_Leaf] stgl  
        ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
        AND stgl.ImportStatus_ID = @ImportStatus_ID  
        AND stgl.Batch_ID = @Batch_ID  
        AND stgl.' + quotename(@ChangedAttributeName) + N' IS NOT NULL; ';  
          
    EXEC sp_executesql @SQLCTG, N'@ChangeTrackingGroup INT, @Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT', @ChangeTrackingGroup, @Version_ID, @StatusProcessing, @Batch_ID;  
  
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
        en.ID, --Member_ID    
        @LeafMemberTypeID, --MemberType_ID    
        stgl.Code,    
        N'', --OldValue    
        N'', --OldCode    
        N'', --NewValue    
        N'', --NewCode  
        @Batch_ID,    
        GETUTCDATE(),     
        @User_ID,     
        GETUTCDATE(),     
        @User_ID    
    FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl   
        ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
        AND stgl.ImportStatus_ID = @StatusProcessing AND stgl.Batch_ID = @Batch_ID  
END;  
  
-- Inserting records is done. Updated the status.  
  
UPDATE [stg].[BigArea_Leaf]  
SET ImportStatus_ID = @StatusOK  
WHERE ImportType in (@IT_MergeOptimistic,@IT_Insert,@IT_MergeOverwrite) AND ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID;  
  
-- Set status to process updates.  
UPDATE [stg].[BigArea_Leaf]  
SET ImportStatus_ID = @StatusProcessing  
WHERE ImportType in (@IT_MergeOptimistic, @IT_MergeOverwrite) AND Code in (SELECT Code FROM mdm.[tbl_2_8_EN] WHERE Version_ID = @Version_ID)  
    AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
      
--Insert the codes into @MemberAttributes table.  
INSERT INTO @MemberAttributes  
(MemberCode)  
SELECT  
    Code  
FROM [stg].[BigArea_Leaf]  
WHERE ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID  
    AND ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite);  
  
-- Update change tracking mask.  
-- This should be done before the values in EN table is updated.  
SET @TrackGroupCount = 1;  
  
WHILE @TrackGroupCount <= @TrackGroupMax BEGIN  
    SELECT   
        @ChangeTrackingGroup = ChangeTrackingID,  
        @ChangedAttributeName = AttributeName,  
        @EntityAttributeName = AttributeColumnName,  
        @ChangedAttributeType_ID = AttributeType_ID,  
        @ChangedAttributeDomainEntityTableName = DomainEntityTableName  
    FROM @TABLECTG  
    WHERE ID = @TrackGroupCount;  
  
	IF @ChangedAttributeType_ID = @AttributeType_Domain  
    BEGIN  
        -- Update change tracking mask for merge optimistic.  
        SET @SQLCTG = N'  
        UPDATE en  
        SET en.ChangeTrackingMask = ISNULL(en.ChangeTrackingMask, 0) | ISNULL(POWER(2, @ChangeTrackingGroup - 1), 0)  
        FROM mdm.[tbl_2_8_EN] en  
        INNER JOIN [stg].[BigArea_Leaf] stgl  
        ON      en.Code = stgl.Code AND en.Version_ID = @Version_ID  
            AND stgl.ImportStatus_ID = @ImportStatus_ID  
            AND stgl.Batch_ID = @Batch_ID  
            AND stgl.ImportType = @ImportType  
            AND stgl.' + quotename(@ChangedAttributeName) + N' IS NOT NULL  
        LEFT JOIN [mdm].' + quotename(@ChangedAttributeDomainEntityTableName) + N' domain ON domain.Code = stgl.' + quotename(@ChangedAttributeName) + N'  
        WHERE  
  	  	    COALESCE(NULLIF(domain.ID, en.' + quotename(@EntityAttributeName) + N'), NULLIF(en.' + quotename(@EntityAttributeName) + N', domain.ID)) IS NOT NULL;   
            ';   
          
        EXEC sp_executesql @SQLCTG, N'@ChangeTrackingGroup INT, @Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT', @ChangeTrackingGroup, @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOptimistic;  
  
        -- Update change tracking mask for merge overwrite.  
        SET @SQLCTG = N'  
        UPDATE en  
        SET en.ChangeTrackingMask = ISNULL(en.ChangeTrackingMask, 0) | ISNULL(POWER(2, @ChangeTrackingGroup - 1), 0)  
        FROM mdm.[tbl_2_8_EN] en  
        INNER JOIN [stg].[BigArea_Leaf] stgl  
        ON      en.Code = stgl.Code AND en.Version_ID = @Version_ID  
            AND stgl.ImportStatus_ID = @ImportStatus_ID  
            AND stgl.Batch_ID = @Batch_ID  
            AND stgl.ImportType = @ImportType  
        LEFT JOIN [mdm].' + quotename(@ChangedAttributeDomainEntityTableName) + N' domain ON domain.Code = stgl.' + quotename(@ChangedAttributeName) + N'  
        WHERE  
  	  	    COALESCE(NULLIF(domain.ID, en.' + quotename(@EntityAttributeName) + N'), NULLIF(en.' + quotename(@EntityAttributeName) + N', domain.ID)) IS NOT NULL;   
  	  	    ';  
          
        EXEC sp_executesql @SQLCTG, N'@ChangeTrackingGroup INT, @Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT', @ChangeTrackingGroup, @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOverwrite;  
    END  
    ELSE  
    BEGIN  
		-- Update change tracking mask for merge optimistic.  
		SET @SQLCTG = N'  
		UPDATE mdm.[tbl_2_8_EN]  
		SET ChangeTrackingMask = ISNULL(ChangeTrackingMask, 0) | ISNULL(POWER(2,@ChangeTrackingGroup -1), 0)  
		FROM mdm.[tbl_2_8_EN] en  
			INNER JOIN [stg].[BigArea_Leaf] stgl  
			ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
			AND stgl.ImportStatus_ID = @ImportStatus_ID  
			AND stgl.Batch_ID = @Batch_ID  
			AND stgl.ImportType = @ImportType  
			AND stgl.' + quotename(@ChangedAttributeName) + N' IS NOT NULL   
			AND COALESCE(NULLIF(stgl.' + quotename(@ChangedAttributeName) + N', en.' + quotename(@EntityAttributeName) + N'), NULLIF(en.' + quotename(@EntityAttributeName) + N', stgl.' + quotename(@ChangedAttributeName) + N')) IS NOT NULL;   
			';   
          
		EXEC sp_executesql @SQLCTG, N'@ChangeTrackingGroup INT, @Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT', @ChangeTrackingGroup, @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOptimistic;  
  
		-- Update change tracking mask for merge overwrite.  
		SET @SQLCTG = N'  
		UPDATE mdm.[tbl_2_8_EN]  
		SET ChangeTrackingMask = ISNULL(ChangeTrackingMask, 0) | ISNULL(POWER(2,@ChangeTrackingGroup -1), 0)  
		FROM mdm.[tbl_2_8_EN] en  
			INNER JOIN [stg].[BigArea_Leaf] stgl  
			ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
			AND stgl.ImportStatus_ID = @ImportStatus_ID  
			AND stgl.Batch_ID = @Batch_ID  
			AND stgl.ImportType = @ImportType  
			AND COALESCE(NULLIF(stgl.' + quotename(@ChangedAttributeName) + N', en.' + quotename(@EntityAttributeName) + N'), NULLIF(en.' + quotename(@EntityAttributeName) + N', stgl.' + quotename(@ChangedAttributeName) + N')) IS NOT NULL;   
			';  
          
		EXEC sp_executesql @SQLCTG, N'@ChangeTrackingGroup INT, @Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT', @ChangeTrackingGroup, @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOverwrite;  
	END  
  
    SET @TrackGroupCount += 1;  
  
END; -- WHILE  
  
--Process Updates  
  
--get all the non-system atributes plus name and code attribute info for current entity  
DECLARE @AttributeInfo TABLE  
(  
    ID                  INT IDENTITY (1, 1) NOT NULL PRIMARY KEY,  
    AttributeName       NVARCHAR(50),  
	AttributeColumnName sysname,  
    AttributeID			INT,  
    AttributeType_ID    TINYINT,  
    DomainEntityTableName sysname NULL  
);  
  
INSERT INTO @AttributeInfo (  
    AttributeID,   
    AttributeName,   
    AttributeColumnName,  
    AttributeType_ID,   
    DomainEntityTableName  
    )  
SELECT DISTINCT   
    attr.ID,   
    attr.Name,   
    attr.TableColumn,  
    attr.AttributeType_ID,  
    ent.EntityTable  
FROM mdm.tblAttribute attr  
LEFT JOIN mdm.tblEntity ent ON ent.ID = attr.DomainEntity_ID  
WHERE   
    attr.Entity_ID = 8 AND   
    attr.MemberType_ID = @LeafMemberTypeID AND  
	(attr.IsSystem = 0 OR attr.IsCode = 1 OR attr.IsName = 1); -- Exclude system attributes other than Code and Name.    
  
--store the changed attribute name and Member_ID for the changed row  
--This must be temp tables vs. table variables because we need to reference it in dynamic SQL.  
CREATE TABLE #MemberAttributeWorkingSet (  
		Member_ID				INT NULL,  
		ChangedAttributeName	NVARCHAR(100) COLLATE DATABASE_DEFAULT  
		);  
  
--Check what attributes are changed  
  
SELECT @TrackGroupMax = COUNT(ID) FROM @AttributeInfo;       
SET @TrackGroupCount = 1;  
  
WHILE @TrackGroupCount <= @TrackGroupMax BEGIN  
    SELECT   
        @ChangedAttributeName = AttributeName,  
        @EntityAttributeName = AttributeColumnName,  
        @ChangedAttributeType_ID = AttributeType_ID,  
        @ChangedAttributeDomainEntityTableName = DomainEntityTableName  
    FROM @AttributeInfo  
    WHERE ID = @TrackGroupCount;  
  
	IF @ChangedAttributeType_ID = @AttributeType_Domain  
    BEGIN  
        -- Update change tracking mask for merge optimistic.  
        SET @SQLCTG = N'  
        INSERT INTO #MemberAttributeWorkingSet    
        SELECT DISTINCT  
			en.ID,  
			N''' + @ChangedAttributeName + N'''  
        FROM mdm.[tbl_2_8_EN] en  
        INNER JOIN [stg].[BigArea_Leaf] stgl  
        ON      en.Code = stgl.Code AND en.Version_ID = @Version_ID  
            AND stgl.ImportStatus_ID = @ImportStatus_ID  
            AND stgl.Batch_ID = @Batch_ID  
            AND stgl.ImportType = @ImportType  
            AND stgl.' + quotename(@ChangedAttributeName) + N' IS NOT NULL  
        LEFT JOIN [mdm].' + quotename(@ChangedAttributeDomainEntityTableName) + N' domain ON domain.Code = stgl.' + quotename(@ChangedAttributeName) + N'  
        WHERE  
  	  	    COALESCE(NULLIF(domain.ID, en.' + quotename(@EntityAttributeName) + N'), NULLIF(en.' + quotename(@EntityAttributeName) + N', domain.ID)) IS NOT NULL;   
            ';   
          
        EXEC sp_executesql @SQLCTG, N'@Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT', @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOptimistic;  
  
        -- Update change tracking mask for merge overwrite.  
        SET @SQLCTG = N'  
        INSERT INTO #MemberAttributeWorkingSet    
        SELECT DISTINCT  
			en.ID,  
			N''' + @ChangedAttributeName + N'''  
        FROM mdm.[tbl_2_8_EN] en  
        INNER JOIN [stg].[BigArea_Leaf] stgl  
        ON      en.Code = stgl.Code AND en.Version_ID = @Version_ID  
            AND stgl.ImportStatus_ID = @ImportStatus_ID  
            AND stgl.Batch_ID = @Batch_ID  
            AND stgl.ImportType = @ImportType  
        LEFT JOIN [mdm].' + quotename(@ChangedAttributeDomainEntityTableName) + N' domain ON domain.Code = stgl.' + quotename(@ChangedAttributeName) + N'  
        WHERE  
  	  	    COALESCE(NULLIF(domain.ID, en.' + quotename(@EntityAttributeName) + N'), NULLIF(en.' + quotename(@EntityAttributeName) + N', domain.ID)) IS NOT NULL;   
  	  	    ';  
          
        EXEC sp_executesql @SQLCTG, N'@Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT', @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOverwrite;  
    END  
    ELSE  
    BEGIN  
		-- Update change tracking mask for merge optimistic.  
		SET @SQLCTG = N'  
		INSERT INTO #MemberAttributeWorkingSet    
        SELECT DISTINCT  
			en.ID,  
			N''' + @ChangedAttributeName + N'''  
		FROM mdm.[tbl_2_8_EN] en  
			INNER JOIN [stg].[BigArea_Leaf] stgl  
			ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
			AND stgl.ImportStatus_ID = @ImportStatus_ID  
			AND stgl.Batch_ID = @Batch_ID  
			AND stgl.ImportType = @ImportType  
			AND stgl.' + quotename(@ChangedAttributeName) + N' IS NOT NULL   
			AND COALESCE(NULLIF(stgl.' + quotename(@ChangedAttributeName) + N', en.' + quotename(@EntityAttributeName) + N'), NULLIF(en.' + quotename(@EntityAttributeName) + N', stgl.' + quotename(@ChangedAttributeName) + N')) IS NOT NULL;   
			';   
          
		EXEC sp_executesql @SQLCTG, N'@Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT', @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOptimistic;  
  
		-- Update change tracking mask for merge overwrite.  
		SET @SQLCTG = N'  
		INSERT INTO #MemberAttributeWorkingSet    
        SELECT DISTINCT  
			en.ID,  
			N''' + @ChangedAttributeName + N'''  
		FROM mdm.[tbl_2_8_EN] en  
			INNER JOIN [stg].[BigArea_Leaf] stgl  
			ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
			AND stgl.ImportStatus_ID = @ImportStatus_ID  
			AND stgl.Batch_ID = @Batch_ID  
			AND stgl.ImportType = @ImportType  
			AND COALESCE(NULLIF(stgl.' + quotename(@ChangedAttributeName) + N', en.' + quotename(@EntityAttributeName) + N'), NULLIF(en.' + quotename(@EntityAttributeName) + N', stgl.' + quotename(@ChangedAttributeName) + N')) IS NOT NULL;   
			';  
          
		EXEC sp_executesql @SQLCTG, N'@Version_ID INT, @ImportStatus_ID INT, @Batch_ID INT, @ImportType INT', @Version_ID, @StatusProcessing, @Batch_ID, @IT_MergeOverwrite;  
	END  
  
	SET @TrackGroupCount += 1;  
  
END; -- WHILE  
  
--Process update (Merge Optimistic)  
IF @LogFlag = 0  
BEGIN  
    UPDATE en  
    SET ValidationStatus_ID = @AwaitingRevalidation  
        ,LastChgDTM = GETUTCDATE()  
        ,LastChgUserID = @User_ID  
        ,LastChgVersionID = @Version_ID  
          
          
    FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl   
    ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
      
    WHERE stgl.ImportType =  @IT_MergeOptimistic   
        AND stgl.ImportStatus_ID = @StatusProcessing   
        AND stgl.Batch_ID = @Batch_ID;  
END  
ELSE  
BEGIN  
    -- Insert update information into #TRANLOG table.    
    UPDATE en  
    SET ValidationStatus_ID = @AwaitingRevalidation  
        ,LastChgDTM = GETUTCDATE()  
        ,LastChgUserID = @User_ID  
        ,LastChgVersionID = @Version_ID  
          
          
        OUTPUT inserted.ID, deleted.Code, inserted.Code, deleted.Name, inserted.Name   
        INTO #TRANLOG  
    FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl   
    ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
      
    WHERE stgl.ImportType =  @IT_MergeOptimistic   
        AND stgl.ImportStatus_ID = @StatusProcessing   
        AND stgl.Batch_ID = @Batch_ID;  
END; --IF  
   
 --Process update (Merge Overwrite)  
IF @LogFlag = 0  
BEGIN         
    UPDATE en  
    SET ValidationStatus_ID = @AwaitingRevalidation  
        ,LastChgDTM = GETUTCDATE()  
        ,LastChgUserID = @User_ID  
        ,LastChgVersionID = @Version_ID  
          
          
    FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl   
    ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
      
    WHERE stgl.ImportType =  @IT_MergeOverwrite   
        AND stgl.ImportStatus_ID = @StatusProcessing   
        AND stgl.Batch_ID = @Batch_ID;  
END  
ELSE  
BEGIN  
    -- Insert update information into #TRANLOG table.    
    UPDATE en  
    SET ValidationStatus_ID = @AwaitingRevalidation  
        ,LastChgDTM = GETUTCDATE()  
        ,LastChgUserID = @User_ID  
        ,LastChgVersionID = @Version_ID  
          
          
        OUTPUT inserted.ID, deleted.Code, inserted.Code, deleted.Name, inserted.Name   
        INTO #TRANLOG  
    FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl   
    ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
      
    WHERE stgl.ImportType =  @IT_MergeOverwrite   
        AND stgl.ImportStatus_ID = @StatusProcessing   
        AND stgl.Batch_ID = @Batch_ID;  
END;  
  
----------------------------------------------------------------------------------------    
--Check for Inheritance Business Rules and update dependent members validation status.    
----------------------------------------------------------------------------------------  
  
--check DBA Inheritance    
DECLARE @BRInherit AS TABLE (    
                 RowNumber INT IDENTITY(1,1) NOT NULL PRIMARY KEY  
                ,DependentAttributeColumnName sysname NOT NULL    
                ,DependentEntityTable sysname NULL  
            );    
   
 DECLARE @Counter       INT = 0,  
         @MaxCounter    INT = 0;  
  
            --DBA Inheritance    
            INSERT INTO @BRInherit (DependentEntityTable, DependentAttributeColumnName)    
            SELECT DISTINCT    
                 depEnt.EntityTable    
                ,i.ChildAttributeColumnName    
            FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY i    
            INNER JOIN #MemberAttributeWorkingSet ws   
                ON i.ParentAttributeName = ws.ChangedAttributeName  
					AND i.ParentEntityID = @Entity_ID  
            INNER JOIN mdm.tblEntity AS depEnt    
                ON i.ChildEntityID = depEnt.ID;    
    
            IF EXISTS(SELECT 1 FROM @BRInherit) BEGIN    
                SELECT    
                     @DependentValidationStatus = @AwaitingDependentMemberRevalidation    
                    ,@Counter = 1    
                    ,@MaxCounter = MAX(RowNumber)     
                FROM @BRInherit;    
                    
                --Loop through each Dba Entity updating the dependent members validation status.    
                WHILE @Counter <= @MaxCounter    
                BEGIN    
                    SELECT     
                         @DependentEntityTable = DependentEntityTable    
                        ,@DependentAttributeColumnName = DependentAttributeColumnName    
                     FROM @BRInherit WHERE [RowNumber] = @Counter;    
    
                    --Update immediate dependent member table validation status.    
                    SELECT @SQLCTG = N'    
                        UPDATE   dep    
                        SET dep.ValidationStatus_ID = @DependentValidationStatus  
                        FROM  mdm.' + @DependentEntityTable + N' AS dep    
                        INNER JOIN #MemberAttributeWorkingSet AS ws    
                            ON dep.' + @DependentAttributeColumnName + N' = ws.Member_ID    
                            AND dep.Version_ID = @Version_ID    
                            AND dep.ValidationStatus_ID <> @DependentValidationStatus;    
                        ';    
    
                    --PRINT @SQLCTG;    
                    EXEC sp_executesql @SQLCTG, N'@Version_ID INT, @DependentValidationStatus INT', @Version_ID, @DependentValidationStatus;    
                        
                    SET @Counter += 1;    
    
                END; -- WHILE    
            END; -- IF @DependentEntityTable  
          
--Process name updates  
IF @LogFlag = 0  
BEGIN   
    UPDATE mdm.[tbl_2_8_EN]  
    SET Name = stgl.Name,  
        ValidationStatus_ID = @AwaitingRevalidation,  
        LastChgDTM = GETUTCDATE(),  
        LastChgUserID = @User_ID,  
        LastChgVersionID = @Version_ID  
    FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl  
        ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
        AND LEN(COALESCE(stgl.Name, N'')) > 0 AND COALESCE(en.Name, N'') <> stgl.Name  
        AND stgl.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite) AND stgl.ImportStatus_ID = @StatusProcessing  
        AND stgl.Batch_ID = @Batch_ID;  
END  
ELSE  
BEGIN  
    -- Insert update information into #TRANLOG table.    
    UPDATE mdm.[tbl_2_8_EN]  
    SET Name = stgl.Name,  
        ValidationStatus_ID = @AwaitingRevalidation,  
        LastChgDTM = GETUTCDATE(),  
        LastChgUserID = @User_ID,  
        LastChgVersionID = @Version_ID  
        OUTPUT inserted.ID, deleted.Code, inserted.Code, deleted.Name, inserted.Name   
        INTO #TRANLOG  
    FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl  
        ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
        AND LEN(COALESCE(stgl.Name, N'')) > 0 AND COALESCE(en.Name, N'') <> stgl.Name  
        AND stgl.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite) AND stgl.ImportStatus_ID = @StatusProcessing  
        AND stgl.Batch_ID = @Batch_ID;  
END; --IF  
        
--Process code updates  
IF @LogFlag = 0  
BEGIN   
    UPDATE mdm.[tbl_2_8_EN]  
    SET Code = stgl.NewCode,  
        ValidationStatus_ID = @AwaitingRevalidation,  
        LastChgDTM = GETUTCDATE(),  
        LastChgUserID = @User_ID,  
        LastChgVersionID = @Version_ID  
    FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl  
        ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
        AND LEN(COALESCE(stgl.NewCode, N'')) > 0  
        AND stgl.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite) AND stgl.ImportStatus_ID = @StatusProcessing  
        AND stgl.Batch_ID = @Batch_ID;  
END  
ELSE  
BEGIN  
    -- Insert update information into #TRANLOG table.    
    UPDATE mdm.[tbl_2_8_EN]  
    SET Code = stgl.NewCode,  
        ValidationStatus_ID = @AwaitingRevalidation,  
        LastChgDTM = GETUTCDATE(),  
        LastChgUserID = @User_ID,  
        LastChgVersionID = @Version_ID  
        OUTPUT inserted.ID, deleted.Code, inserted.Code, deleted.Name, inserted.Name   
        INTO #TRANLOG  
    FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl  
        ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
        AND LEN(COALESCE(stgl.NewCode, N'')) > 0  
        AND stgl.ImportType IN (@IT_MergeOptimistic, @IT_MergeOverwrite) AND stgl.ImportStatus_ID = @StatusProcessing  
        AND stgl.Batch_ID = @Batch_ID;  
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
                @TranSQL                NVARCHAR(MAX) = N'';  
  
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
    WHERE A.Entity_ID = @Entity_ID AND A.MemberType_ID = @LeafMemberTypeID  
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
      
            SET @TranSQL = N'    
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
        1, -- Leaf Member Type ID    
        CASE WHEN ISNULL(Code, N'''') = N'''' THEN New_Code ELSE Code END,    
        ' + @CurrentTableColumn + N',   
        ' + @CurrentTableColumn + N',   
        New_' + @CurrentTableColumn + N',   
        New_' + @CurrentTableColumn + N',   
        @Batch_ID,    
        GETUTCDATE(),     
        @User_ID,     
        GETUTCDATE(),     
        @User_ID    
    FROM #TRANLOG  
    WHERE COALESCE(NULLIF(' + @CurrentTableColumn + N', New_' + @CurrentTableColumn + N'), NULLIF(New_' + @CurrentTableColumn + N', ' + @CurrentTableColumn + N')) IS NOT NULL   
        ';   
          
            EXEC sp_executesql @TranSQL, N'@Version_ID INT, @Attribute_ID INT, @Entity_ID INT, @Batch_ID INT, @User_ID INT ', @Version_ID, @CurrentID, @Entity_ID, @Batch_ID, @User_ID;  
        END  
        ELSE  
        BEGIN  
        -- Handle DBA  
        -- Get the old code value and the new code value by table join.    
            SET @TranSQL = N'    
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
        1, -- Leaf Member Type ID      
        CASE WHEN ISNULL(T.Code, N'''') = N'''' THEN T.New_Code ELSE T.Code END,    
        T.' + @CurrentTableColumn + N',   
        DO.Code,   
        New_' + @CurrentTableColumn + N',   
        DN.Code,   
        @Batch_ID,    
        GETUTCDATE(),     
        @User_ID,     
        GETUTCDATE(),     
        @User_ID    
    FROM #TRANLOG T  
    LEFT OUTER JOIN mdm.' + QUOTENAME(@CurrentDomainTable) + N' DN  
    ON T.New_' + @CurrentTableColumn + N' = DN.ID  
    LEFT OUTER JOIN mdm.' + QUOTENAME(@CurrentDomainTable) + N' DO  
    ON T.' + @CurrentTableColumn + N' = DO.ID  
    WHERE COALESCE(NULLIF(T.' + @CurrentTableColumn + N', T.New_' + @CurrentTableColumn + N'), NULLIF(T.New_' + @CurrentTableColumn + N', T.' + @CurrentTableColumn + N')) IS NOT NULL    
        ';    
          
            EXEC sp_executesql @TranSQL, N'@Version_ID INT, @Attribute_ID INT, @Entity_ID INT, @Batch_ID INT, @User_ID INT ', @Version_ID, @CurrentID, @Entity_ID, @Batch_ID, @User_ID;  
          
        END; --IF  
            
        DELETE FROM @TempTable WHERE ID = @CurrentID;      
  
    END; --WHILE  
  
    TRUNCATE TABLE #TRANLOG;  
      
END; --IF  
  
-- Updating is done. Update the status.  
UPDATE [stg].[BigArea_Leaf]  
SET ImportStatus_ID = @StatusOK  
FROM [stg].[BigArea_Leaf]  
WHERE ImportType in (@IT_MergeOptimistic,@IT_MergeOverwrite) AND ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID;  
  
  
IF EXISTS (SELECT 1 FROM @MemberAttributes) BEGIN    
-- Check circular references only when there is a DBA to check.  
    DECLARE @RecursiveHierarchy_ID              INT = 0,  
            @RecursiveHierarchyAttribute_ID     INT = 0,  
            @ParentChildDerivedView             sysname,  
            @CircularReferenceErrors            INT = 0;  
              
    -- Determine if a recursive derived hierarchy is in play.  There may be multiple but just grab the first one.  
    SELECT TOP 1  
         @RecursiveHierarchy_ID  = d.DerivedHierarchy_ID  
        ,@RecursiveHierarchyAttribute_ID = att.Attribute_ID  
    FROM mdm.tblDerivedHierarchyDetail d  
    INNER JOIN [mdm].[viw_SYSTEM_SCHEMA_ATTRIBUTES] att  
        ON att.Attribute_DBAEntity_ID = @Entity_ID  
        AND att.Attribute_ID = d.Foreign_ID  
        AND d.ForeignParent_ID = att.Attribute_DBAEntity_ID  
  
    IF @RecursiveHierarchy_ID > 0 BEGIN  
        --There is a recursive derived hierarchy in play therefore we need to check the DBA values for circular references.  
          
        --Lookup the derived hierarchy view.  
        SET @ParentChildDerivedView = N'viw_SYSTEM_' + CAST(@Model_ID AS NVARCHAR(30)) + N'_' + CAST(@RecursiveHierarchy_ID AS NVARCHAR(30)) + N'_PARENTCHILD_DERIVED';    
          
        DECLARE @CircularReferenceCodeList TABLE  
        (            
            MemberCode            NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
        );  
          
        --Call [udpCircularReferenceMemberCodesGet] and get the number of circular reference errors and the member codes  
        --that participate in the circular reference  
        INSERT INTO @CircularReferenceCodeList EXEC    @CircularReferenceErrors = [mdm].[udpCircularReferenceMemberCodesGet]   
                                                    @RecursiveDerivedView = @ParentChildDerivedView,  
                                                    @MemberAttributes = @MemberAttributes;  
                  
        --If we found circular references, rollback the transaction and set the error code.  
        IF @CircularReferenceErrors > 0  
        BEGIN  
            IF @TranCounter = 0 ROLLBACK TRANSACTION;  
            ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
                      
            -- Set error 210016 (Binary Location: 2^13) for record(s) that caused the issue.  
            UPDATE [stg].[BigArea_Leaf]  
            SET ErrorCode = IsNull(stgl.ErrorCode,0) | 8192,  
                ImportStatus_ID = @StatusError  
            FROM [stg].[BigArea_Leaf] stgl  
                INNER JOIN @CircularReferenceCodeList cref  
                ON stgl.Code = cref.MemberCode  
            WHERE stgl.ImportType IN (@IT_MergeOptimistic, @IT_Insert, @IT_MergeOverwrite)  
                AND stgl.Batch_ID = @Batch_ID;  
              
            -- If there is any circular reference the entire batch process fails.  
            -- Since the records without an error status in the batch process rolled back as well,  
            -- Set their status as not processed.  
              
            UPDATE [stg].[BigArea_Leaf]  
            SET ImportStatus_ID = @StatusDefault               
            WHERE Batch_ID = @Batch_ID AND ImportStatus_ID <> @StatusError;     
              
            --Get the number of errors for the batch ID  
            SELECT @ErrorCount = COUNT(ID) FROM [stg].[BigArea_Leaf]  
                WHERE Batch_ID = @Batch_ID AND ImportStatus_ID = @StatusError;  
  
            -- Set the status of the batch as Not Running (Completed).  
            -- Set the error member count.  
            UPDATE mdm.tblStgBatch  
            SET Status_ID = @Completed,  
                LastRunEndDTM = GETUTCDATE(),  
                LastRunEndUserID = @User_ID,  
                ErrorMemberCount = @ErrorCount  
            WHERE ID = @Batch_ID;  
                      
            RETURN @OtherRuntimeError;  
                      
        END; --IF  
    END;--IF  
END;--IF  
  
-- Set status to process Delete (soft delete) and Purge (hard delete)  
UPDATE [stg].[BigArea_Leaf]  
SET ImportStatus_ID = @StatusProcessing  
WHERE ImportType IN (@IT_Delete, @IT_Purge, @IT_DeleteSetNullToRef, @IT_PurgeSetNullToRef) AND IsNuLL(ErrorCode, 0) = 0   
AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
--Determine if any purge or delete records exist  
IF Exists(SELECT Code FROM [stg].[BigArea_Leaf]   
WHERE ImportType IN (@IT_Delete, @IT_Purge, @IT_DeleteSetNullToRef, @IT_PurgeSetNullToRef) AND ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID)  
BEGIN  
      
    --Populate a temp table of FK Relationships  
    CREATE TABLE #TABLEFK   
    (  
        ID                  INT IDENTITY (0, 1) NOT NULL  
        ,Entity_ID          INT  
        ,EntityName         NVARCHAR(250) COLLATE database_default  
        ,AttributeName      SYSNAME COLLATE database_default NULL  
        ,TableColumn        NVARCHAR(128) NOT NULL  
        ,MemberType_ID      INT  
    );  
             
    INSERT INTO #TABLEFK  
    SELECT e.ID as Entity_ID,   
        e.Name as EntityName,   
        a.Name as AttributeName,   
        a.TableColumn as TableColumn,   
        a.MemberType_ID   
    FROM mdm.tblEntity e  
        INNER JOIN mdm.tblAttribute a   
        ON a.Entity_ID = e.ID  
    WHERE DomainEntity_ID = @Entity_ID;  
      
    DECLARE @FkTotalCount INT = 0;  
           
    SELECT @FkTotalCount = COUNT(ID) FROM #TABLEFK;  
      
    IF @FkTotalCount > 0  
    BEGIN   
        DECLARE @StagingID    INT,  
                @SetToNull    BIT,  
                @MemberReferenced BIT = 0,  
                @RefCount       INT = 0,  
                @FkCount        INT = 0;  
                  
        -- Populate a temp table of MemberCodes to be Removed.  
        CREATE TABLE #TableRR  
        (  
            StagingID   INT NOT NULL,  
            MemberCode  NVARCHAR(250) COLLATE database_default,  
            ImportType  TINYINT NOT NULL,  
            SetToNull   BIT  
        );  
        CREATE CLUSTERED INDEX TableRR_IX ON #TableRR(StagingID);  
		      
        INSERT INTO #TableRR(StagingID, MemberCode, ImportType, SetToNull)  
        SELECT ID, Code, ImportType, CASE WHEN ImportType IN (@IT_Delete, @IT_Purge) THEN 0 ELSE 1 END AS SetToNull  
        FROM [stg].[BigArea_Leaf]  
        WHERE ImportType IN (@IT_Delete, @IT_Purge, @IT_DeleteSetNullToRef, @IT_PurgeSetNullToRef)   
            AND ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID;  
                      
        -- Iterate through these records and reassign the attribute value to null in case when the import type is @IT_DeleteSetNullToRef or @IT_PurgeSetNullToRef.  
        WHILE EXISTS(SELECT 1 FROM #TableRR)  
        BEGIN  
            SELECT TOP 1  
                @StagingID = StagingID,  
                @MemberCode = MemberCode,  
                @ImportType = ImportType,  
                @SetToNull = SetToNull  
            FROM #TableRR;  
  
            SET @MemberReferenced = 0;  
            SET @RefCount = 0;  
            SET @FkCount = 0;  
                      
            -- Get Member ID from the code  
            EXEC mdm.udpMemberTypeIDAndIDGetByCode @Version_ID, @Entity_ID, @MemberCode, @MemberType_ID output, @Member_ID output;  
            SET @FKMemberCode = CONVERT(NVARCHAR(250), @Member_ID);  
  
            --Remove all Foreign Key Selections to allow for Member delete  
            -- Iterate through these Foreign Keys  
            WHILE @FkTotalCount > @FkCount AND @MemberReferenced <> 1   
            BEGIN  
                SELECT @EntityName = EntityName,  
                    @FKEntity_ID = Entity_ID,  
                    @AttributeName = AttributeName,  
                    @TableColumn = TableColumn,  
                    @FKMemberType_ID = MemberType_ID  
                FROM #TABLEFK  
                WHERE ID = @FkCount;  
  
                SET @TableName = mdm.udfTableNameGetByID(@FKEntity_ID, @FKMemberType_ID);  
  
                IF @SetToNull = 1  
                BEGIN  
                --Set the domain-based attribute value that is referencing to the member to NULL                                                      
                    SET @FKSQL = N'      
                    UPDATE mdm.' + quotename(@TableName) + N'   
                    SET ' + quotename(@TableColumn) + N' = NULL,  
                    ValidationStatus_ID = 4,       
                    LastChgDTM = GETUTCDATE(),    
                    LastChgUserID = ' + CONVERT(NVARCHAR(30), @User_ID) + N',    
                    LastChgVersionID = ' + CONVERT(NVARCHAR(30), @Version_ID) + N'    
                    WHERE    
                    ' + quotename(@TableColumn) + N' = N''' + @FKMemberCode + N''' AND    
                    Version_ID = ' + CONVERT(NVARCHAR(30), @Version_ID) + N';'    
                      
                    EXEC sp_executesql @FKSQL;  
                END;  
                ELSE  
                BEGIN  
                --Check if the member is referenced.  
                  
                    SET @FKSQL = N'      
                    SELECT @RefCount = COUNT(*) FROM mdm.' + quotename(@TableName) + N'    
                    WHERE    
                    ' + quotename(@TableColumn) + N' = N''' + @FKMemberCode + N''' AND    
                    Version_ID = ' + CONVERT(NVARCHAR(30), @Version_ID) + N';'    
                      
                    EXEC sp_executesql @FKSQL, N'@RefCount INT OUTPUT', @RefCount OUTPUT;  
                      
                    IF @RefCount > 0  
                    BEGIN  
                    --In case of @IT_Delete and @IT_Purge when the entity is referenced via foreign key, set as an error.  
                    --Error 210052 Binary Location 2^19: The member cannot be deleted or purged when it is referenced as a domain-based attribute value.  
                        UPDATE [stg].[BigArea_Leaf]  
                        SET ErrorCode = IsNull(ErrorCode,0) | 524288,  
                            ImportStatus_ID = @StatusError  
                            WHERE ID = @StagingID;  
                    -- Insert the error detail information.        
                    INSERT INTO [mdm].[tblStgErrorDetail]   
                        (Batch_ID, Code, AttributeName, AttributeValue, UniqueErrorCode)  
                        VALUES  
                        (@Batch_ID, @MemberCode, @TableColumn, @FKMemberCode, 210052)          
                      
                        SET @MemberReferenced = 1;  
                      
                    END; --IF  
                  
                END; --IF  
                  
                SET @FkCount += 1;  
                  
            END -- WHILE  
                      
            DELETE FROM #TableRR WHERE StagingID = @StagingID;            
        END -- WHILE  
    END; -- IF  
      
    -- Deactivate (soft delete) the member in Entity table.      
    UPDATE mdm.[tbl_2_8_EN]  
    SET Status_ID = @MemberStatusInactive  
    FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl  
    ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
    AND stgl.ImportStatus_ID = @StatusProcessing AND stgl.Batch_ID = @Batch_ID  
    AND stgl.ImportType IN (@IT_Delete, @IT_DeleteSetNullToRef);  
      
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
            en.ID, --Member_ID    
            @LeafMemberTypeID, --MemberType_ID    
            stgl.Code,    
            N'1', --OldValue    
            N'Active', --OldCode    
            N'2', --NewValue    
            N'De-Activated', --NewCode  
            @Batch_ID,    
            GETUTCDATE(),     
            @User_ID,     
            GETUTCDATE(),     
            @User_ID  		      
        FROM mdm.[tbl_2_8_EN] en INNER JOIN [stg].[BigArea_Leaf] stgl  
            ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
            AND stgl.ImportStatus_ID = @StatusProcessing AND stgl.Batch_ID = @Batch_ID  
            AND stgl.ImportType IN (@IT_Delete, @IT_DeleteSetNullToRef, @IT_Purge, @IT_PurgeSetNullToRef);  
    END;  
  
      
    -- Hard delete the member from Entity table.  
    DELETE FROM mdm.[tbl_2_8_EN]  
    FROM mdm.[tbl_2_8_EN] en   
    INNER JOIN [stg].[BigArea_Leaf] stgl  
    ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
    AND stgl.ImportStatus_ID = @StatusProcessing AND stgl.Batch_ID = @Batch_ID  
    AND stgl.ImportType IN (@IT_Purge, @IT_PurgeSetNullToRef);          
  
    -- Delete member security  
    DELETE FROM mdm.tblSecurityRoleAccessMember  
    FROM mdm.tblSecurityRoleAccessMember sra  
    INNER JOIN mdm.[tbl_2_8_EN] en   
    ON sra.Member_ID = en.ID AND sra.Version_ID = @Version_ID  
    AND sra.Entity_ID = @Entity_ID AND sra.HierarchyType_ID IN (0, 1) -- Derived and Explicit Hierarchy  
    AND sra.MemberType_ID = @LeafMemberTypeID  
    INNER JOIN [stg].[BigArea_Leaf] stgl  
    ON en.Code = stgl.Code AND en.Version_ID = @Version_ID  
    AND stgl.ImportStatus_ID = @StatusProcessing AND stgl.Batch_ID = @Batch_ID  
    AND stgl.ImportType IN (@IT_Delete, @IT_Purge, @IT_DeleteSetNullToRef, @IT_PurgeSetNullToRef);  
  
    EXEC mdm.udpSecurityMemberProcessRebuildModelVersion @Version_ID, 1;  
      
END -- IF  
  
--Update the status after the delete (soft delete) and the purge (hard delete)  
UPDATE [stg].[BigArea_Leaf]  
SET ImportStatus_ID = @StatusOK  
WHERE ImportType IN (@IT_Delete, @IT_Purge, @IT_DeleteSetNullToRef, @IT_PurgeSetNullToRef)   
    AND ImportStatus_ID = @StatusProcessing AND Batch_ID = @Batch_ID;  
  
--Get the number of errors for the batch ID  
SELECT @ErrorCount = COUNT(ID) FROM [stg].[BigArea_Leaf]  
    WHERE Batch_ID = @Batch_ID AND ImportStatus_ID = @StatusError;  
  
-- Set the status of the batch as Not Running (Completed).  
-- Set the error member count.  
UPDATE mdm.tblStgBatch  
SET Status_ID = @Completed,  
    LastRunEndDTM = GETUTCDATE(),  
    LastRunEndUserID = @User_ID,  
    ErrorMemberCount = @ErrorCount  
WHERE ID = @Batch_ID  
  
-- Reset member count after the staging.  
UPDATE mdm.tblUserMemberCount  
SET LastCount= -1,  
    LastChgDTM = GETUTCDATE()  
WHERE Entity_ID = @Entity_ID AND Version_ID = @Version_ID AND MemberType_ID = 1  
  
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
END;
GO
