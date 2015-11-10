SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [stg].[udp_ChartOfAccounts_Relationship]    
@VersionName NVARCHAR(50), @LogFlag INT=NULL, @BatchTag NVARCHAR(50)=N'', @Batch_ID INT=NULL, @Result SMALLINT=NULL OUTPUT    
WITH EXECUTE AS 'mds_schema_user'    
AS    
BEGIN    
    SET NOCOUNT ON;  
      
    DECLARE @UserName                   NVARCHAR(100),  
            @Model_ID                   INT,  
            @Entity_ID                  INT,  
            @Hierarchy_ID               INT,  
            @TargetType_ID              INT,  
            @Meta_ID                    INT,  
            @Hierarchy_IsMandatory      INT,  
            @MaxSortOrderRelationship   INT,  
            @MaxSortOrderStaging        INT,  
            @Version_ID                 INT,   
            @HierarchyParent_ID         INT,  
            @IsMandatory                BIT,     
            @VersionStatus_ID           INT,    
            @VersionStatus_Committed    INT = 3,  
            @User_ID                    INT = 0, -- The user ID used for logging is 0.  
  
            @MemberCount                INT = 0,  
            @ErrorCount                 INT = 0,  
            @NewBatch_ID                INT = 0,  
            @GetNewBatch_ID             INT = 0,  
              
            -- member type constants  
            @LeafMemberTypeID           INT = 1,  
            @ConsolidatedMemberTypeID   INT = 2,  
            @HierarchyMemberTypeID      INT = 4,  
              
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
                                             
            --Validation status  
            @NewAwaitingValidation      INT = 0,  
            @AwaitingRevalidation       INT = 4,     
                                                         
            --XACT_STATE() constancts    
            @UncommittableTransaction   INT = -1;  
                                      
            DECLARE @tblMeta TABLE     
            (    
                ID                      INT IDENTITY (1, 1) NOT NULL,      
                Hierarchy_ID            INT,    
                Hierarchy_IsMandatory   BIT,    
                TargetType_ID           INT    
            );    
                
            DECLARE @tblHierarchy TABLE     
            (    
                Hierarchy_ID            INT    
            );  
              
            DECLARE @tblDuplicatedCodeInHierarchy TABLE     
            (    
                ChildCode               NVARCHAR(250),  
                HierarchyName           NVARCHAR(250)    
            );  
                
    SET @Model_ID = 4  
    SET @Entity_ID = 34  
                 
    -- Check for invalid Version Name.      
    IF @VersionName IS NULL RETURN @VersionNameError;  
      
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
      
    SELECT @Version_ID = ID, @VersionStatus_ID = Status_ID FROM mdm.tblModelVersion WHERE Model_ID = @Model_ID AND [Name] = @VersionName        
      
     --Ensure that Version is not committed    
    IF (@VersionStatus_ID = @VersionStatus_Committed) BEGIN     
        RAISERROR('MDSERR310040|Data cannot be loaded into a committed version.', 16, 1);  
        RETURN @VersionStatusError;       
    END;  
      
    --Check if there is any record to process.  
    IF LEN(@BatchTag) > 0 BEGIN  
        SELECT @MemberCount = COUNT(ID) FROM [stg].[ChartOfAccounts_Relationship]   
            WHERE LTRIM(RTRIM(BatchTag)) = @BatchTag AND ImportStatus_ID = @StatusDefault;  
        IF @MemberCount = 0 BEGIN   
            RETURN @NoRecordToProcessError;   
        END; -- IF  
    END; -- IF  
    ELSE BEGIN  
        IF @Batch_ID IS NOT NULL BEGIN  
            SELECT @MemberCount = COUNT(ID) FROM [stg].[ChartOfAccounts_Relationship]   
                WHERE Batch_ID = @Batch_ID AND ImportStatus_ID = @StatusDefault;   
            IF @MemberCount = 0 BEGIN   
                RETURN @NoRecordToProcessError;  
            END; -- IF  
        END; -- IF  
    END; -- IF  
      
    -- If neither @BatchTag nor @Batch_ID is specified assume that a blank @BatchTag is specified.  
      
    IF @Batch_ID IS NULL AND LEN(@BatchTag) = 0 BEGIN  
        SELECT @MemberCount = COUNT(ID) FROM [stg].[ChartOfAccounts_Relationship]   
            WHERE (BatchTag IS NULL OR LTRIM(RTRIM(BatchTag)) = N'') AND ImportStatus_ID = @StatusDefault;    
        IF @MemberCount = 0 BEGIN   
            RETURN @NoRecordToProcessError;  
        END; -- IF              
    END; -- IF  
      
    --Check if there is any record with an invalid status.  
    IF LEN(@BatchTag) > 0 BEGIN  
        IF EXISTS (SELECT stgr.ID FROM [stg].[ChartOfAccounts_Relationship] stgr  
            INNER JOIN mdm.tblStgBatch stgb              
            ON LTRIM(RTRIM(stgr.BatchTag)) = LTRIM(RTRIM(stgb.BatchTag)) AND stgb.Status_ID = @Running   
            WHERE LTRIM(RTRIM(stgr.BatchTag)) = @BatchTag AND stgr.ImportStatus_ID = @StatusDefault) BEGIN   
           
            RAISERROR('MDSERR310029|The status of the specified batch is not valid.', 16, 1);  
            RETURN @BatchStatusError;                 
        END; -- IF              
    END; -- IF   
      
    IF @Batch_ID IS NOT NULL  BEGIN  
        IF EXISTS (SELECT stgr.ID FROM [stg].[ChartOfAccounts_Relationship] stgr  
            INNER JOIN mdm.tblStgBatch stgb  
            ON stgr.Batch_ID = stgb.ID AND stgb.Status_ID IN (@Running, @QueueToClear, @Cleared)  
            WHERE stgr.Batch_ID = @Batch_ID AND stgr.ImportStatus_ID = @StatusDefault) BEGIN   
              
            RAISERROR('MDSERR310029|The status of the specified batch is not valid.', 16, 1);  
            RETURN @BatchStatusError;                 
        END; -- IF              
    END; -- IF  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
      
    BEGIN TRY  
      
        --Create relationship staging temporary table    
        CREATE TABLE #tblStage     
        (    
            ID                    BIGINT IDENTITY (1, 1) NOT NULL,     
            Stage_ID            INT NOT NULL,    
            Relationship_ID        INT NOT NULL DEFAULT -1,    --ID from the hierarchy relationship table    
            Member_ID            INT NOT NULL,    
            Member_Code            NVARCHAR(250) COLLATE database_default NOT NULL,     
            ChildType_ID        INT NOT NULL DEFAULT 0,        --Source member type: 1=EN and 2=HP   
            MemberStatus_ID        TINYINT NOT NULL DEFAULT 1,    --Defaults to active     
            TargetType_ID        INT NOT NULL,                --Type of relationship: 1=parent; 2=sibling (move behind sibling)    
            Target_ID            INT NULL,    
            Target_Code            NVARCHAR(250) COLLATE database_default NULL,     
            TargetMemberType_ID    INT NOT NULL DEFAULT 0,        --Target member type: 1=leaf member, 2=consolidated member, 3=collection (derived)    
            TargetStatus_ID        TINYINT NOT NULL DEFAULT 1,    --Defaults to active    
            SortOrder            INT NOT NULL DEFAULT 0,    
            PrevTarget_ID        INT NULL,                    --For transaction logging    
            PrevTarget_Code        NVARCHAR(250) COLLATE database_default, --For transaction logging    
            Status_ID            INT NOT NULL DEFAULT 1,     
            Status_ErrorCode    NVARCHAR(10) COLLATE database_default NOT NULL DEFAULT N'210000'    
        );    
    
        --Create relationship temporary table - contains the list of new relationships    
        CREATE TABLE #tblRelation     
        (    
            ID                BIGINT IDENTITY (1, 1) NOT NULL,     
            Version_ID        INT NOT NULL,    
            Status_ID        INT NOT NULL DEFAULT 1,    
            Hierarchy_ID    INT NULL,    
            Parent_ID        INT NULL DEFAULT -2,    
            Child_ID        INT NOT NULL DEFAULT -2,    
            ChildType_ID    INT NOT NULL DEFAULT 0,    
            SortOrder        INT NOT NULL DEFAULT 0,    
            LevelNumber        SMALLINT NOT NULL DEFAULT (-1)    
        );      
      
        IF @Batch_ID IS NOT NULL  BEGIN  
            IF NOT EXISTS (SELECT ID FROM mdm.tblStgBatch WHERE ID = @Batch_ID AND Status_ID NOT IN (@Running, @QueueToClear, @Cleared)  
                AND Version_ID = @Version_ID AND Entity_ID = @Entity_ID AND MemberType_ID = @HierarchyMemberTypeID) BEGIN     
                SET @GetNewBatch_ID = @BatchIDNotFound   
            END; --IF  
        END; --IF                          
        ELSE BEGIN  
        -- Check if udpEntityStagingFlagForProcessing already assigned a new batch ID (in this case the status is QueuedToRun).  
            SELECT TOP 1 @Batch_ID = ID FROM mdm.tblStgBatch   
                WHERE LTRIM(RTRIM(BatchTag)) = @BatchTag AND Status_ID = @QueuedToRun   
                AND Version_ID = @Version_ID AND Entity_ID = @Entity_ID AND MemberType_ID = @HierarchyMemberTypeID ORDER BY ID DESC  
               
            IF @Batch_ID IS NULL BEGIN  
                SET @GetNewBatch_ID = @BatchIDForBatchTagNotFound      
            END; --IF  
            ELSE BEGIN  
            -- Set the member count      
                UPDATE mdm.tblStgBatch  
                SET TotalMemberCount = @MemberCount  
                WHERE LTRIM(RTRIM(BatchTag)) = @BatchTag AND Status_ID = @QueuedToRun   
                            AND Version_ID = @Version_ID AND Entity_ID = @Entity_ID AND MemberType_ID = @HierarchyMemberTypeID        
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
                @HierarchyMemberTypeID,  
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
                UPDATE [stg].[ChartOfAccounts_Relationship]  
                SET Batch_ID = @NewBatch_ID  
                WHERE Batch_ID = @Batch_ID AND ImportStatus_ID = @StatusDefault  
            END; --IF  
            ELSE BEGIN  
                UPDATE [stg].[ChartOfAccounts_Relationship]  
                SET Batch_ID = @NewBatch_ID  
                WHERE IsNULL(BatchTag, N'') = @BatchTag AND ImportStatus_ID = @StatusDefault  
            END; --IF  
              
            SET @Batch_ID = @NewBatch_ID;  
        END; --IF      
        ELSE BEGIN  
            -- Set the status of the batch as Running.  
            UPDATE mdm.tblStgBatch   
                SET Status_ID = @Running,  
                    TotalMemberCount = @MemberCount,  
                    LastRunStartDTM = GETUTCDATE(),  
                    LastRunStartUserID = @User_ID  
                WHERE ID = @Batch_ID   
        END; --  
      
        -- Set ErrorCode = 0   
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = 0  
            WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
        --Error Check all staged members  
  
        --Error 210006 Binary Location 2^3: Child Code is inactive.              
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 8  
            WHERE ChildCode IN  
                (SELECT DISTINCT stgr.ChildCode FROM [stg].[ChartOfAccounts_Relationship] stgr  
                INNER JOIN mdm.[tbl_4_34_EN] en ON stgr.ChildCode = en.Code WHERE en.Version_ID = @Version_ID AND en.Status_ID = 2)  
                AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
        --Error 300002 Binary Location 2^8: Child Code does not exist in Entity Table nor Parent Table.  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 256  
            WHERE ChildCode NOT IN  
                (SELECT DISTINCT stgr.ChildCode FROM [stg].[ChartOfAccounts_Relationship] stgr  
                INNER JOIN mdm.[tbl_4_34_EN] en ON stgr.ChildCode = en.Code WHERE en.Version_ID = @Version_ID)  
                AND ChildCode NOT IN  
                (SELECT DISTINCT stgr.ChildCode FROM [stg].[ChartOfAccounts_Relationship] stgr  
                 INNER JOIN mdm.[tbl_4_34_HP] hp   
                    ON stgr.ChildCode = hp.Code  
                 INNER JOIN mdm.tblHierarchy h -- join with the hierarchy table to validate the hierarchy name  
                    ON      stgr.HierarchyName = h.Name  
                        AND hp.Hierarchy_ID = h.ID  
                 WHERE  
                        hp.Version_ID = @Version_ID   
                    AND h.Entity_ID = @Entity_ID  
                )  
                AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
                  
        --Error 300002 Binary Location 2^8: Parent Code does not exist in Parent Table when RelationshipType is 1 (parent).  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 256  
            WHERE ParentCode <> N'ROOT' AND ParentCode NOT IN  
                (SELECT DISTINCT stgr.ParentCode FROM [stg].[ChartOfAccounts_Relationship] stgr  
                 INNER JOIN mdm.[tbl_4_34_HP] hp   
                    ON stgr.ParentCode = hp.Code   
                 INNER JOIN mdm.tblHierarchy h -- join with the hierarchy table to validate the hierarchy name  
                    ON      stgr.HierarchyName = h.Name  
                        AND hp.Hierarchy_ID = h.ID  
                 WHERE  
                        hp.Version_ID = @Version_ID   
                    AND h.Entity_ID = @Entity_ID  
                )  
                AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID AND RelationshipType = 1;  
          
        --Error 210011 Binary Location 2^11: When RelationshipType is 1 (parent) the ParentCode cannot be a leaf member.  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 2048  
            WHERE ParentCode IN  
                (SELECT DISTINCT stgr.ParentCode FROM [stg].[ChartOfAccounts_Relationship] stgr  
                INNER JOIN mdm.[tbl_4_34_EN] en ON stgr.ParentCode = en.Code WHERE en.Version_ID = @Version_ID)  
                AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID AND RelationshipType = 1;  
  
        --Error 210015 Binary Location 2^12: The MemberCode exists multiple times in the staging table for a hierarchy and a batch.  
        INSERT INTO @tblDuplicatedCodeInHierarchy (ChildCode, HierarchyName)  
        SELECT ChildCode, HierarchyName  
            FROM [stg].[ChartOfAccounts_Relationship]   
            WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID  
            GROUP BY ChildCode, HierarchyName having COUNT(*) > 1;  
          
        UPDATE stgr  
            SET ErrorCode = IsNull(ErrorCode,0) | 4096  
            FROM [stg].[ChartOfAccounts_Relationship] stgr  
            INNER JOIN @tblDuplicatedCodeInHierarchy dup  
            ON stgr.ChildCode = dup.ChildCode  
            AND stgr.HierarchyName = dup.HierarchyName              
            WHERE stgr.ImportStatus_ID = @StatusDefault AND stgr.Batch_ID = @Batch_ID;  
  
        --Error 210032 Binary Location 2^4: The HierarchyName is missing or invalid.   
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 16   
            Where LEN(COALESCE(HierarchyName, N'')) = 0  
                AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
                  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 16  
            WHERE LEN(COALESCE(HierarchyName, N'')) > 0 AND HierarchyName NOT IN  
                (SELECT DISTINCT [Name] FROM mdm.tblHierarchy   
                WHERE Entity_ID = @Entity_ID)  
                AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
          
        --Error 210035 Binary Location 2^5: Child Code is required.  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 32  
            WHERE LEN(COALESCE(ChildCode, N'')) = 0  
                AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
          
        --Error 210041 Binary Location 2^6: ROOT is not a valid Child Code  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 64   
            WHERE ChildCode = N'ROOT' AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;      
  
        --Error 210042 Binary Location 2^7: MDMUnused is not a valid Child Code  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 128   
            WHERE ChildCode = 'MDMUnused' AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
          
        --Error 210043 Binary Location 2^14: The RelationshipType must be 1 (parent) or 2 (sibling)  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 16384   
            WHERE RelationshipType <> 1 AND RelationshipType <> 2 AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;          
  
        --Error 210035 Binary Location 2^5: Parent Code is required.  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 32  
            WHERE LEN(COALESCE(ParentCode, N'')) = 0 AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
        --Error 210046 Binary Location 2^15: The member cannot be a sibling of ROOT.  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 32768   
            WHERE ParentCode = N'ROOT' AND RelationshipType = 2 AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;      
  
        --Error 210047 Binary Location 2^16: The member cannot be a sibling of Unused.  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 65536   
            WHERE ParentCode = 'MDMUnused' AND RelationshipType = 2 AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
        --Error 210048 Binary Location 2^17: Parent Code and Child Code cannot be the same.  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ErrorCode = IsNull(ErrorCode,0) | 131072  
            WHERE Upper(ParentCode) = Upper(ChildCode) AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
        --Set ImportStatus on all records with at least one error  
        UPDATE [stg].[ChartOfAccounts_Relationship]  
            SET ImportStatus_ID = @StatusError  
            WHERE ErrorCode > 0 AND ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
              
        --Process Insert all new error free records into MDS internal table  
        UPDATE [stg].[ChartOfAccounts_Relationship]   
            SET ImportStatus_ID = @StatusProcessing  
            WHERE ImportStatus_ID = @StatusDefault AND Batch_ID = @Batch_ID;  
  
  
        --Identify entities and hierarchies (for recalculating level numbers and sort orders)  
        INSERT INTO @tblHierarchy  
        SELECT DISTINCT hr.ID  
        FROM [stg].[ChartOfAccounts_Relationship] stgr  
        LEFT OUTER JOIN mdm.tblHierarchy hr ON LTRIM(RTRIM(stgr.HierarchyName)) = hr.Name AND hr.Entity_ID = @Entity_ID    
        WHERE hr.ID IS NOT NULL AND hr.ID > 0  
        AND stgr.ImportStatus_ID = @StatusProcessing AND stgr.Batch_ID = @Batch_ID;  
  
        --Identify entities and hierarchies  
        INSERT INTO @tblMeta  
        (  
            Hierarchy_ID, Hierarchy_IsMandatory, TargetType_ID  
        )  
        SELECT DISTINCT  
            hr.ID,  
            hr.IsMandatory,  
            stgr.RelationshipType  
        FROM [stg].[ChartOfAccounts_Relationship] stgr  
        INNER JOIN mdm.tblHierarchy hr   
        ON LTRIM(RTRIM(stgr.HierarchyName)) = hr.Name AND hr.Entity_ID = @Entity_ID    
        WHERE hr.ID IS NOT NULL AND hr.ID > 0  
        AND stgr.ImportStatus_ID = @StatusProcessing AND stgr.Batch_ID = @Batch_ID;  
  
        --Iterate through the meta table  
        WHILE EXISTS(SELECT 1 FROM @tblMeta) BEGIN  
          
            SELECT TOP 1  
                @Meta_ID = ID,   
                @Hierarchy_ID = Hierarchy_ID,  
                @Hierarchy_IsMandatory = Hierarchy_IsMandatory,  
                @TargetType_ID = TargetType_ID  
            FROM @tblMeta;  
      
            --Populate temporary staging table  
            INSERT INTO #tblStage  
            (  
                Stage_ID, Member_ID, Member_Code, TargetType_ID, Target_ID, Target_Code, SortOrder  
            )  
            SELECT  
                stgr.ID,  
                -2,   
                stgr.ChildCode,   
                stgr.RelationshipType,  
                CASE  
                    WHEN LTRIM(RTRIM(stgr.ParentCode)) = N'ROOT' THEN 0  
                    WHEN LTRIM(RTRIM(stgr.ParentCode)) = N'MDMUNUSED' AND hr.IsMandatory = 0 THEN -1  
                    ELSE -2  
                END,  
                stgr.ParentCode,  
                CASE  
                    WHEN stgr.SortOrder IS NULL THEN 0  
                    ELSE stgr.SortOrder  
                END          
            FROM [stg].[ChartOfAccounts_Relationship] stgr  
            INNER JOIN mdm.tblHierarchy hr   
            ON LTRIM(RTRIM(stgr.HierarchyName)) = hr.Name AND hr.Entity_ID = @Entity_ID    
            WHERE  
                hr.ID = @Hierarchy_ID  
                AND stgr.RelationshipType = @TargetType_ID  
                AND stgr.ImportStatus_ID = @StatusProcessing  
                AND stgr.Batch_ID = @Batch_ID  
            ORDER BY    
                stgr.ID DESC; --To accommodate multiple moves for the same member load the most recent data first.  
            /*  
            ------------------------  
            FETCH SOURCE MEMBER DATA  
            ------------------------  
            */  
  
            --Update temporary table with Member_ID, MemberStatus_ID, and ChildType_ID = 1 (EN)              
            UPDATE tStage SET   
                Member_ID = tSource.ID,   
                MemberStatus_ID = tSource.Status_ID,   
                ChildType_ID = 1 -- Leaf   
            FROM #tblStage AS tStage   
            INNER JOIN mdm.[tbl_4_34_EN] AS tSource   
                ON tStage.Member_Code = tSource.Code   
            WHERE tSource.Version_ID = @Version_ID;  
              
            --Update temporary table with Member_ID, MemberStatus_ID, and ChildType_ID = 2 (HP)  
            UPDATE tStage SET   
                Member_ID = tSource.ID,   
                MemberStatus_ID = tSource.Status_ID,   
                ChildType_ID = 2 -- Parent  
            FROM #tblStage AS tStage  
            INNER JOIN mdm.[tbl_4_34_HP] AS tSource   
                ON tStage.Member_Code = tSource.Code   
            WHERE tSource.Version_ID = @Version_ID  
            AND tSource.Hierarchy_ID = @Hierarchy_ID;  
                  
            /*  
            ------------------------  
            FETCH TARGET MEMBER DATA  
            ------------------------  
            */  
             
            --Process hierarchy; target may be a leaf (if a sibling) or a consolidation  
  
            --Update temporary table with Target_ID, TargetStatus_ID, and TargetMemberType_ID = 1 (leaf)  
            UPDATE tStage SET   
                Target_ID = tSource.ID,   
                TargetStatus_ID = tSource.Status_ID,   
                TargetMemberType_ID = 1   
            FROM #tblStage AS tStage      
            INNER JOIN mdm.[tbl_4_34_EN] AS tSource   
                ON tStage.Target_Code = tSource.Code   
            WHERE tSource.Version_ID = @Version_ID;  
  
            --Update temporary table with Target_ID, TargetStatus_ID, and TargetMemberType_ID = 2 (consolidated)  
            UPDATE tStage SET   
                Target_ID = tSource.ID,   
                TargetStatus_ID = tSource.Status_ID,   
                TargetMemberType_ID = 2  
            FROM #tblStage AS tStage   
            INNER JOIN mdm.[tbl_4_34_HP] AS tSource   
                ON tStage.Target_Code = tSource.Code   
            WHERE tSource.Version_ID = @Version_ID   
                AND tSource.Hierarchy_ID = @Hierarchy_ID;  
              
            --If the target is a sibling (@TargetType_ID is 2) then reassign the target ID (fetch the parent ID of the target) and assign the sort order of the sibling  
            IF @TargetType_ID = 2 BEGIN  
              
                UPDATE tStage SET   
                     Target_ID = tRel.Parent_HP_ID  
                    ,SortOrder = tRel.SortOrder  
                FROM #tblStage AS tStage   
                INNER JOIN mdm.[tbl_4_34_HR] AS tRel   
                    ON tStage.TargetMemberType_ID = tRel.ChildType_ID  
                    AND tStage.Target_ID = CASE tStage.TargetMemberType_ID   
                        WHEN 1 THEN tRel.Child_EN_ID -- Leaf  
                        WHEN 2 THEN tRel.Child_HP_ID -- Consolidated  
                    END --case  
                WHERE tRel.Version_ID = @Version_ID  
                    AND tRel.Hierarchy_ID = @Hierarchy_ID;  
                          
            END; --if  
       
            --EN  
            UPDATE tStage SET   
                Relationship_ID = tSource.ID  
            FROM #tblStage AS tStage   
            INNER JOIN mdm.[tbl_4_34_HR] AS tSource   
                ON tStage.ChildType_ID = tSource.ChildType_ID                  
                AND tStage.Member_ID = tSource.Child_EN_ID                      
            WHERE tSource.Version_ID = @Version_ID   
                AND tStage.ChildType_ID = 1 -- Leaf  
                AND tSource.Hierarchy_ID = @Hierarchy_ID;  
              
            --HP  
            UPDATE tStage SET   
                Relationship_ID = tSource.ID  
            FROM #tblStage AS tStage   
            INNER JOIN mdm.[tbl_4_34_HR] AS tSource   
                ON tStage.ChildType_ID = tSource.ChildType_ID                  
                AND tStage.Member_ID = tSource.Child_HP_ID      
            WHERE tSource.Version_ID = @Version_ID   
                AND tStage.ChildType_ID = 2 -- Consolidated  
                AND tSource.Hierarchy_ID = @Hierarchy_ID;  
              
            IF @TargetType_ID = 1 BEGIN  
                --EN              
                --Warning - redundant assignment; transaction will not be logged      
                UPDATE tStage SET   
                    Status_ID = 3  
                FROM #tblStage AS tStage   
                INNER JOIN mdm.[tbl_4_34_HR] AS tSource   
                    ON tStage.ChildType_ID = tSource.ChildType_ID  
                    AND tStage.Member_ID = tSource.Child_EN_ID  
                    AND tStage.Target_ID = tSource.Parent_HP_ID  
                WHERE tSource.Version_ID = @Version_ID   
                    AND tStage.ChildType_ID = 1 -- Leaf  
                    AND tStage.Status_ID = 1    
                    AND tSource.Hierarchy_ID = @Hierarchy_ID;                                  
                --HP      
                --Warning - redundant assignment; transaction will not be logged              
                UPDATE tStage SET   
                    Status_ID = 3  
                FROM #tblStage AS tStage   
                INNER JOIN mdm.[tbl_4_34_HR] AS tSource   
                    ON tStage.ChildType_ID = tSource.ChildType_ID  
                    AND tStage.Member_ID = tSource.Child_HP_ID  
                    AND tStage.Target_ID = tSource.Parent_HP_ID  
                WHERE tSource.Version_ID = @Version_ID   
                    AND tStage.ChildType_ID = 2 --- Consolidated  
                    AND tStage.Status_ID = 1    
                    AND tSource.Hierarchy_ID = @Hierarchy_ID;  
                  
            END; --if  
              
            --Mark new records  
            UPDATE #tblStage SET   
                Status_ID = 4   
            WHERE Status_ID = 1 AND Relationship_ID = -1;  
              
            --Mark records to be removed (moving to Unused for non-mandatory hierarchies)  
            UPDATE #tblStage SET   
                Status_ID = 5   
            WHERE Target_ID = -1 AND Status_ID = 1;  
              
                           
            /*  
            --------------------------------------------  
            FETCH PRIOR VALUES (FOR TRANSACTION LOGGING)  
            --------------------------------------------  
            If logging is requested then insert into the transaction log  
            */  
              
            IF @LogFlag = 1 BEGIN  
                              
                --Fetch previous target ID from relationship table  
                UPDATE tStage SET   
                    PrevTarget_ID = tSource.Parent_HP_ID   
                FROM #tblStage AS tStage   
                INNER JOIN mdm.[tbl_4_34_HR] AS tSource  
                    ON tStage.Relationship_ID = tSource.ID  
                WHERE tSource.Version_ID = @Version_ID  
                    AND tStage.Status_ID = 1  
                    AND tSource.Hierarchy_ID = @Hierarchy_ID;  
  
                --Fetch previous target code from hierarchy parent table  
                UPDATE tStage SET   
                    PrevTarget_Code = tSource.Code   
                FROM #tblStage AS tStage   
                INNER JOIN mdm.[tbl_4_34_HP] AS tSource   
                    ON tStage.PrevTarget_ID = tSource.ID  
                WHERE tSource.Version_ID = @Version_ID    
                    AND tStage.Status_ID = 1;  
  
            END; --if  
              
            /*  
              ---------------------------  
              UPDATE RELATIONSHIP RECORDS  
              ---------------------------  
              Update mdm.tblHR with the new relationship records.  
              Assign the SortOrder = Stage_ID for parent assignments (to force ordering of relationships by data entry).    
              Assign the SortOrder = sibling sort order for sibling assignments.    
              This step is only pertinent for hierarchies; collection relationships support redundancy (i.e., more than one of the same member).  
            */  
                      
            --EN  
            UPDATE tSource SET  
                 Parent_HP_ID = NULLIF(tStage.Target_ID, 0)  
                ,ValidationStatus_ID = @AwaitingRevalidation  
                ,LastChgDTM = GETUTCDATE()  
                ,LevelNumber = -1  
                ,LastChgUserID = @User_ID   
                ,LastChgVersionID = @Version_ID   
            FROM #tblStage AS tStage   
            INNER JOIN mdm.[tbl_4_34_HR] AS tSource  
                ON tStage.ChildType_ID = tSource.ChildType_ID   
                AND tStage.Member_ID = tSource.Child_EN_ID  
            WHERE tSource.Version_ID = @Version_ID   
                AND tStage.ChildType_ID = 1 -- Leaf  
                AND tStage.Status_ID = 1    
                AND tSource.Hierarchy_ID = @Hierarchy_ID;  
              
            --HP  
            UPDATE tSource SET  
                 Parent_HP_ID = NULLIF(tStage.Target_ID, 0)  
                ,ValidationStatus_ID = @AwaitingRevalidation  
                ,LastChgDTM = GETUTCDATE()  
                ,LevelNumber = -1  
                ,LastChgUserID = @User_ID   
                ,LastChgVersionID = @Version_ID   
            FROM #tblStage AS tStage   
            INNER JOIN mdm.[tbl_4_34_HR] AS tSource  
                ON tStage.ChildType_ID = tSource.ChildType_ID   
                AND tStage.Member_ID = tSource.Child_HP_ID  
            WHERE tSource.Version_ID = @Version_ID   
                AND tStage.ChildType_ID = 2 --Parent  
                AND tStage.Status_ID = 1    
                AND tSource.Hierarchy_ID = @Hierarchy_ID;  
                                   
                   
            /*  
            ---------------------------  
            DELETE RELATIONSHIP RECORDS  
            ---------------------------  
            Update mdm.tblHR - remove records where the target is unused  
            */  
              
            DELETE FROM mdm.[tbl_4_34_HR]    
            WHERE Version_ID = @Version_ID   
                AND ID IN (SELECT Relationship_ID FROM #tblStage WHERE Status_ID = 5);  
              
            /*  
            ----------------------------------------------------------  
            UPDATE SortOrder previously inserted from udpStgMemberSave  
            ----------------------------------------------------------  
            */              
            SET @MaxSortOrderRelationship = 0;  
            SET @MaxSortOrderStaging = 0;  
  
            -- Get the maximum Sort Order for the existing records in the HR table  
            SELECT @MaxSortOrderRelationship = MAX(tSource.SortOrder)   
                    FROM mdm.[tbl_4_34_HR] AS tSource  
                        INNER JOIN #tblStage tStage1   
                        ON tStage1.ChildType_ID = tSource.ChildType_ID   
                    WHERE NOT EXISTS (SELECT tStage.Member_ID   
                        FROM #tblStage AS tStage   
                            WHERE tStage.Member_ID = tSource.Child_EN_ID  )  
                            AND tSource.Hierarchy_ID = @Hierarchy_ID            
                            AND tSource.Status_ID = 1;  
                                          
            -- Get the maximum Sort Order for the records to be inserted in the staging table      
            SELECT @MaxSortOrderStaging = MAX(tStage.SortOrder)  
                     FROM #tblStage AS tStage   
                        INNER JOIN mdm.[tbl_4_34_HR] AS tSource   
                        ON tStage.Relationship_ID = tSource.ID  
                    WHERE tSource.Hierarchy_ID = @Hierarchy_ID;  
                              
          
            UPDATE tSource    
                SET tSource.SortOrder =   
                    CASE WHEN @MaxSortOrderStaging <= @MaxSortOrderRelationship THEN tStage.SortOrder + @MaxSortOrderRelationship   
                    ELSE tStage.SortOrder  
                    END,  
                    ValidationStatus_ID = @AwaitingRevalidation                              
                FROM mdm.[tbl_4_34_HR] AS tSource    
                    INNER JOIN #tblStage AS tStage ON    
                    tStage.Relationship_ID = tSource.ID;  
                           
        
              
            /*  
            -------------------------------  
            INSERT NEW RELATIONSHIP RECORDS  
            -------------------------------  
            */  
  
            --Insert into the hierarchy temporary table (necessary to generate key values)  
            --Added a DISTINCT to eliminate potential duplicate records for collections  
  
            INSERT INTO #tblRelation   
            (  
                Version_ID,  
                Hierarchy_ID,  
                Parent_ID,  
                Child_ID,  
                ChildType_ID,  
                SortOrder  
            ) SELECT DISTINCT  
                @Version_ID,    
                @Hierarchy_ID,   
                Target_ID, --Parent_ID  
                Member_ID,   
                ChildType_ID,  
                SortOrder  
            FROM #tblStage   
            WHERE Status_ID = 4;  
  
            --Insert into hierarchy relationship table  
              
            INSERT INTO mdm.[tbl_4_34_HR]  
            (  
                Version_ID,  
                Status_ID,  
                ValidationStatus_ID,  
                Parent_HP_ID,  
                Child_EN_ID,   
                Child_HP_ID,  
                ChildType_ID,  
                SortOrder,  
                EnterDTM,   
                EnterUserID,  
                EnterVersionID,  
                LastChgDTM,  
                LastChgUserID,  
                LastChgVersionID,  
                Hierarchy_ID,   
                LevelNumber)  
        
            --Assign the SortOrder = SortOrder from the staging table  
            SELECT  
                Version_ID,  
                Status_ID,  
                @NewAwaitingValidation,  
                NULLIF(Parent_ID, 0), --Parent_HP_ID / Parent_CN_ID  
                CASE WHEN ChildType_ID = 1 THEN Child_ID ELSE NULL END, --EN  
                CASE WHEN ChildType_ID = 2 THEN Child_ID ELSE NULL END, --HP  
                ChildType_ID,  
                SortOrder,  
                GETUTCDATE(),   
                @User_ID ,   
                @Version_ID,   
                GETUTCDATE(),   
                @User_ID ,   
                @Version_ID,  
                Hierarchy_ID,  
                LevelNumber  
            FROM #tblRelation;  
  
            /*  
            --------------------------------------------------------------------------------------------  
            VERIFY THAT RECURSIVE ASSINGMENTS HAVE NOT BEEN ENTERED  
            This can be accomplished by calculating the level number.    
            Any levels that can not be calculated are deemed recursive and will be moved to the Root.  
            --------------------------------------------------------------------------------------------  
            */  
              
            --Calculate level numbers for the current hierarchy  
            EXEC mdm.udpHierarchyMemberLevelSave @Version_ID, @Hierarchy_ID, 0, 2;  
              
            --For those relationships where the LevelNumber = -1 (i.e., can not be calculated) move to Root                  
            UPDATE tStage SET   
                Target_ID = PrevTarget_ID,   
                Target_Code = PrevTarget_Code,   
                Status_ID = 6     
            FROM #tblStage AS tStage   
            INNER JOIN mdm.[tbl_4_34_HR] AS tSource   
                ON tStage.Relationship_ID = tSource.ID  
            WHERE tSource.LevelNumber = -1   
                AND tSource.Version_ID = @Version_ID    
                AND tSource.Hierarchy_ID = @Hierarchy_ID  AND tStage.Status_ID = 1;  
                  
            -- Set the error code when circular reference is detected.  
            --Error 210016 Binary Location 2^13:   
            UPDATE stgr SET   
                ErrorCode = IsNull(ErrorCode,0) | 8192,  
                ImportStatus_ID = @StatusError                       
            FROM [stg].[ChartOfAccounts_Relationship] AS stgr  
            INNER JOIN #tblStage AS tStage   
                ON stgr.ID = tStage.Stage_ID    
            WHERE tStage.Status_ID = 6;       
                   
            --Reset the source table  
            --EN  
            UPDATE tSource SET   
                 Parent_HP_ID = NULLIF(tStage.PrevTarget_ID, 0),  
                 ValidationStatus_ID = @AwaitingRevalidation  
            FROM #tblStage AS tStage   
            INNER JOIN mdm.[tbl_4_34_HR] AS tSource   
                ON tStage.ChildType_ID = tSource.ChildType_ID   
                AND tStage.Member_ID = tSource.Child_EN_ID  
            WHERE tSource.LevelNumber = -1  
                AND tStage.ChildType_ID = 1  
                AND tSource.Version_ID = @Version_ID   
                AND tSource.Hierarchy_ID = @Hierarchy_ID;     
                              
             --Reset the source table  
             --HP                   
                UPDATE tSource SET   
                     Parent_HP_ID = NULLIF(tStage.PrevTarget_ID, 0),  
                     ValidationStatus_ID = @AwaitingRevalidation  
                FROM #tblStage AS tStage   
                INNER JOIN mdm.[tbl_4_34_HR] AS tSource   
                    ON tStage.ChildType_ID = tSource.ChildType_ID   
                    AND tStage.Member_ID = tSource.Child_HP_ID  
                WHERE tSource.LevelNumber = -1   
                    AND tStage.ChildType_ID = 2 -- Parent  
                    AND tSource.Version_ID = @Version_ID   
                    AND tSource.Hierarchy_ID = @Hierarchy_ID;     
                                  
        
            /*  
            ---------------------------  
            PROCESS TRANSACTION LOGGING  
            ---------------------------  
            If logging is requested then insert into the transaction log  
            */  
              
            IF @LogFlag = 1 BEGIN  
                --Log relationship transactions  
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
                    EnterDTM,  
                    EnterUserID,  
                    LastChgDTM,  
                    LastChgUserID  
                )  
                SELECT   
                    @Version_ID,   
                    CASE TargetType_ID WHEN 1 THEN 4 WHEN 2 THEN 5 ELSE 0 END,   
                    0,   
                    @Hierarchy_ID,   
                    @Entity_ID,   
                    Member_ID,   
                    ChildType_ID,   
                    Member_Code,  
                    CASE PrevTarget_ID WHEN NULL THEN -1 ELSE PrevTarget_ID END,   
                    CASE PrevTarget_ID WHEN NULL THEN N'MDMUNUSED' WHEN -1 THEN N'MDMUNUSED' WHEN 0 THEN N'ROOT' ELSE PrevTarget_Code END,   
                    Target_ID,   
                    Target_Code,   
                    GETUTCDATE(),   
                    @User_ID ,   
                    GETUTCDATE(),   
                    @User_ID   
                FROM #tblStage   
                WHERE Status_ID IN (1, 4, 5);        
  
            END; --if  
                    
  
            TRUNCATE TABLE #tblStage;  
            TRUNCATE TABLE #tblRelation;  
              
            DELETE FROM @tblMeta WHERE ID = @Meta_ID;  
              
        END; --while  
  
        DROP TABLE #tblStage;  
        DROP TABLE #tblRelation;  
          
        /*  
        ---------------------------------------  
        RECALCULATE HIERARCHY SYSTEM ATTRIBUTES  
        ---------------------------------------  
        */  
        --Iterate through the meta table  
        WHILE EXISTS(SELECT 1 FROM @tblHierarchy) BEGIN  
          
           SELECT TOP 1 @Hierarchy_ID = Hierarchy_ID FROM @tblHierarchy;  
  
           --Recalculate system hierarchy attributes (level number, sort order, and index code)  
           EXEC mdm.udpHierarchySystemAttributesSave @Version_ID, @Hierarchy_ID;  
           DELETE FROM @tblHierarchy WHERE Hierarchy_ID = @Hierarchy_ID;  
             
        END; --while  
                                       
      
        UPDATE [stg].[ChartOfAccounts_Relationship]   
        SET ImportStatus_ID = @StatusOK  
        FROM [stg].[ChartOfAccounts_Relationship]  
        WHERE ImportStatus_ID = @StatusProcessing;  
          
        --Get the number of errors for the batch ID  
        SELECT @ErrorCount = COUNT(ID) FROM [stg].[ChartOfAccounts_Relationship]  
            WHERE Batch_ID = @Batch_ID AND ImportStatus_ID = @StatusError;  
          
        -- Set the status of the batch as Completed.  
        UPDATE mdm.tblStgBatch   
            SET Status_ID = @Completed,  
                LastRunEndDTM = GETUTCDATE(),  
                LastRunEndUserID = @User_ID,  
                ErrorMemberCount = @ErrorCount    
            WHERE ID = @Batch_ID   
          
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
