SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
DECLARE @MemberIdList mdm.IdList;  
INSERT INTO @MemberIdList  
VALUES (1), (2), (3)  
  
EXEC mdm.udpMembersStatusSet @User_ID=1, @Version_ID=20, @Entity_ID=37, @MemberIds = @MemberIds, @Status_ID=2  
  
SELECT * FROM mdm.tblAttribute WHERE DomainEntity_ID=37  
  
*/  
  
CREATE PROCEDURE [mdm].[udpMembersStatusSet]  
(  
   @User_ID       INT,  
   @Version_ID    INT,  
   @Entity_ID     INT,  
   @MemberIds     mdm.MemberId READONLY,  
   @Status_ID     TINYINT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE  
         @MemberType_Leaf               INT = 1  
        ,@MemberType_Consolidated       INT = 2  
        ,@MemberType_Collection         INT = 3  
        ,@MemberType_Hierarchy          INT = 4  
        ,@MemberType_CollectionMember   INT = 5  
  
        ,@Status_Active                 INT = 1  
        ,@Status_Deactivated            INT = 2  
  
        ,@ValidationStatus_AwaitingRevalidation INT = 4  
  
        ,@TransactionType_ChangeMemberStatus INT = 2  
  
        ,@InvalidIdError                NVARCHAR(MAX) = N'MDSERR120003|The user does not have permission or the object ID is not valid'  
  
        -- This pseudo-constant is for use in string concatenation operations to prevent string truncation. When concatenating two or more strings,  
        -- if none of the strings is an NVARCHAR(MAX) or an NVARCHAR constant that is longer than 4,000 characters, then the resulting string   
        -- will be silently truncated to 4,000 characters. Concatenating with this empty NVARCHAR(MAX), is sufficient to prevent truncation.  
        -- See http://connect.microsoft.com/SQLServer/feedback/details/283368/nvarchar-max-concatenation-yields-silent-truncation.  
        ,@TruncationGuard               NVARCHAR(MAX) = N''  
        ;  
  
    -- Create a temp table as a staging area for members being processed. A temp table is used instead of a table var so that it can   
    --    1. Have a multi-column index, and  
    --    2. Be used within dynamic SQL statements.  
    CREATE TABLE #MemberWorkingSet  
    (  
         ID             INT IDENTITY(1, 1)  
        ,Member_ID      INT  
        ,MemberType_ID  TINYINT  
        ,OldStatus      TINYINT  
        ,ErrorCode      NVARCHAR(MAX) COLLATE DATABASE_DEFAULT  
    );  
    CREATE UNIQUE CLUSTERED INDEX #ix_MemberWorkingSet_Member_ID_MemberType_ID ON #MemberWorkingSet(Member_ID, MemberType_ID);  
    INSERT INTO #MemberWorkingSet (Member_ID, MemberType_ID)  
    SELECT DISTINCT  
         ID  
        ,MemberType_ID  
    FROM @MemberIds  
  
    -- Check for invalid member types.  
    UPDATE #MemberWorkingSet  
    SET ErrorCode = @InvalidIdError  
    WHERE COALESCE(MemberType_ID, 0) NOT IN (@MemberType_Leaf, @MemberType_Consolidated, @MemberType_Collection, @MemberType_Hierarchy, @MemberType_CollectionMember);  
  
    --Check to make sure that the members are not referenced by a DBA (Leaf members only. Consolidated members can't be referenced by a DBA).  
    DECLARE @ReferringEntities TABLE  
    (  
         ID                     INT IDENTITY(1, 1)  
        ,Entity_ID              INT  
        ,MemberType_ID          TINYINT  
        ,AttributeColumnName    NVARCHAR(128) COLLATE DATABASE_DEFAULT  
    )  
    INSERT INTO @ReferringEntities (Entity_ID, MemberType_ID, AttributeColumnName)  
    SELECT DISTINCT  
         Entity_ID  
        ,MemberType_ID  
        ,TableColumn  
    FROM mdm.tblAttribute  
    WHERE DomainEntity_ID = @Entity_ID  
    ORDER BY Entity_ID;  
  
    DECLARE  @ID                            INT  
            ,@ReferringEntity_ID            INT  
            ,@ReferringAttributeColumnName  NVARCHAR(100)  
            ,@ReferringMemberType_ID        TINYINT  
            ,@ReferringEntityTableName      SYSNAME  
            ,@ReferringEntityName           NVARCHAR(50)  
            ,@SQL                           NVARCHAR(MAX)  
    WHILE EXISTS(SELECT 1 FROM @ReferringEntities)  
    BEGIN  
        SELECT TOP 1  
             @ID = ID  
            ,@ReferringEntity_ID = Entity_ID  
            ,@ReferringAttributeColumnName = AttributeColumnName  
            ,@ReferringMemberType_ID = MemberType_ID  
        FROM @ReferringEntities;  
  
        SET @ReferringEntityName = (SELECT Name FROM mdm.tblEntity WHERE ID = @ReferringEntity_ID);  
        SET @ReferringEntityTableName = mdm.udfTableNameGetByID(@ReferringEntity_ID, @ReferringMemberType_ID);  
          
        SET @SQL = @TruncationGuard + N'  
        UPDATE ws  
        SET  
            ws.ErrorCode = N''MDSERR300004|The member cannot be deleted. It is currently used by {0}: {1}|' + @ReferringEntityName + '|'' + ref.Code  
        FROM #MemberWorkingSet ws  
        INNER JOIN mdm.' + QUOTENAME(@ReferringEntityTableName) + N' ref  
            ON ws.Member_ID = ref.' + QUOTENAME(@ReferringAttributeColumnName) + N'  
        WHERE  
                ws.ErrorCode IS NULL  
            AND ws.MemberType_ID = ' + CONVERT(NVARCHAR, @MemberType_Leaf) + ' -- Leaf (Consolidated and Collection members cannot be referenced by DBAs)  
            AND ref.Version_ID = @Version_ID  
            AND ref.Status_ID = ' + CONVERT(NVARCHAR, @Status_Active);  
       EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;  
  
       DELETE FROM @ReferringEntities WHERE ID = @ID;  
    END -- WHILE  
  
    -- Get a list of all the distinct member types, and process them in batches  
    DECLARE @MemberTypes TABLE(MemberType_ID TINYINT PRIMARY KEY);  
    INSERT INTO @MemberTypes  
    SELECT DISTINCT   
        MemberType_ID  
    FROM #MemberWorkingSet  
    WHERE ErrorCode IS NULL  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT = @@TRANCOUNT;  
    IF @TranCounter > 0   
    BEGIN  
        SAVE TRANSACTION TX;  
    END ELSE   
    BEGIN  
        BEGIN TRANSACTION;  
    END;  
  
    BEGIN TRY  
  
        DECLARE   
             @MemberTableName    SYSNAME  
            ,@MemberType_ID      TINYINT  
            ,@Member_ID          INT  
            ,@MemberIdList       mdm.IdList;  
  
        -- Loop through each member type  
        WHILE EXISTS (SELECT 1 FROM @MemberTypes)  
        BEGIN  
          
            SET @MemberType_ID = (SELECT TOP 1 MemberType_ID FROM @MemberTypes);  
            SET @MemberTableName = mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID);  
  
            IF NULLIF(@MemberTableName, N'') IS NULL  
            BEGIN  
                -- Invalid member type.  
                UPDATE #MemberWorkingSet  
                SET ErrorCode = @InvalidIdError  
                WHERE  
                        ErrorCode IS NULL  
                    AND MemberType_ID = @MemberType_ID;  
            END ELSE   
            BEGIN  
                SET @SQL = @TruncationGuard + N'  
                -- Add an error if the member does not exist and record the previous Status_ID value, for use in logging a transaction.  
                UPDATE ws  
                SET  
                     ws.OldStatus = mem.Status_ID  
                    ,ws.ErrorCode = CASE WHEN mem.ID IS NULL  THEN N''' + @InvalidIdError + N''' ELSE NULL END -- Add an error for invalid member   
                FROM #MemberWorkingSet ws  
                LEFT JOIN mdm.' + QUOTENAME(@MemberTableName)+ N' mem  
                    ON ws.Member_ID = mem.ID  
                WHERE  
                        ws.ErrorCode IS NULL  
                    AND ws.MemberType_ID = @MemberType_ID  
                    AND mem.Version_ID = @Version_ID;  
          
                -- Update the Status_ID in the member table.  
                UPDATE mem  
                SET  
                    mem.Status_ID = @Status_ID  
                FROM #MemberWorkingSet ws  
                INNER JOIN mdm.' + QUOTENAME(@MemberTableName)+ N' mem  
                    ON ws.Member_ID = mem.ID  
                WHERE  
                        ws.ErrorCode IS NULL  
                    AND ws.MemberType_ID = @MemberType_ID  
                    AND mem.Version_ID = @Version_ID;  
                ';  
  
                EXEC sp_executesql @SQL, N'@Version_ID INT, @MemberType_ID TINYINT, @Status_ID TINYINT', @Version_ID, @MemberType_ID, @Status_ID;  
  
                -- Create a list of all updated member ids.  
                INSERT INTO @MemberIdList  
                SELECT Member_ID  
                FROM #MemberWorkingSet  
                WHERE   
                        ErrorCode IS NULL  
                    AND MemberType_ID = @MemberType_ID;  
  
                -- Update validation issues or status.  
                IF @Status_ID = @Status_Deactivated  
                BEGIN              
                    --If deleting then delete any validation issues.  
                    EXEC mdm.udpValidationLogClearByMemberIDs   
                         @Version_ID = @Version_ID  
                        ,@Entity_ID = @Entity_ID  
                        ,@MemberType_ID = @MemberType_ID  
                        ,@MemberIdList = @MemberIdList;  
                END ELSE IF @Status_ID = @Status_Active  
                BEGIN  
                    --If reactivating then set the validation status to 'Awaiting Revalidation'.  
                    EXEC mdm.udpMembersValidationStatusUpdate  
                         @Version_ID = @Version_ID  
                        ,@Entity_ID = @Entity_ID  
                        ,@MemberType_ID = @MemberType_ID  
                        ,@ValidationStatus_ID = @ValidationStatus_AwaitingRevalidation  
                        ,@MemberIdList = @MemberIdList;  
                END  
  
                -- Clear the list of updated members ids, to prepare it for reuse in the next loop iteration.  
                DELETE FROM @MemberIdList;  
            END; -- IF  
  
            DELETE FROM @MemberTypes WHERE MemberType_ID = @MemberType_ID;  
        END; -- WHILE  
  
        DECLARE @HierarchyTableName SYSNAME = mdm.udfTableNameGetByID(@Entity_ID, @MemberType_Hierarchy)  
        IF LEN(@HierarchyTableName) > 0   
        BEGIN  
            DECLARE @SqlLevelString NVARCHAR(MAX) = CASE @Status_ID WHEN @Status_Deactivated THEN N'  
                    ,hr.LevelNumber = -1 ' ELSE N'' END;  
            SET @SQL = @TruncationGuard + N'  
                --Update The hierarchy relationship record and reset level number for recalculation  
                UPDATE hr  
                SET  
                    hr.Status_ID = @Status_ID' + @SqlLevelString + '  
                FROM #MemberWorkingSet ws  
                INNER JOIN mdm.' + QUOTENAME(@HierarchyTableName) + N' hr  
                    ON  
                            ws.MemberType_ID = hr.ChildType_ID  
                        AND ws.Member_ID = CASE hr.ChildType_ID  
                                WHEN ' + CONVERT(NVARCHAR, @MemberType_Leaf) +         N' THEN hr.Child_EN_ID   
                                WHEN ' + CONVERT(NVARCHAR, @MemberType_Consolidated) + N' THEN hr.Child_HP_ID END  
                WHERE  
                        hr.Version_ID = @Version_ID  
                    AND ws.ErrorCode IS NULL  
  
                --Update children of consolidated nodes to Root and reset level number for recalculation  
                UPDATE hr  
                SET  
                    hr.Parent_HP_ID = NULL' + @SqlLevelString + '  
                FROM #MemberWorkingSet ws  
                INNER JOIN mdm.' + QUOTENAME(@HierarchyTableName) + N' hr  
                    ON ws.Member_ID = hr.Parent_HP_ID  
                WHERE  
                        hr.Version_ID = @Version_ID  
                    AND ws.MemberType_ID = ' + CONVERT(NVARCHAR, @MemberType_Consolidated) + N'  
                    AND ws.ErrorCode IS NULL';  
  
            EXEC sp_executesql @SQL, N'@Version_ID INT, @Status_ID TINYINT', @Version_ID, @Status_ID;  
        END  
  
        --Log the transactions.  
        DECLARE   
             @RowID INT = 0  
            ,@OldStatus NVARCHAR(1)  
            ,@NewStatus NVARCHAR(1) = CONVERT(NVARCHAR, @Status_ID);  
  
        WHILE EXISTS (SELECT 1 FROM #MemberWorkingSet WHERE ErrorCode IS NULL AND ID > @RowID)  
        BEGIN  
            -- Get the next changed member.  
            SELECT TOP 1  
                 @RowID = ID  
                ,@MemberType_ID = MemberType_ID  
                ,@Member_ID = Member_ID  
                ,@OldStatus = CONVERT(NVARCHAR, OldStatus)  
            FROM #MemberWorkingSet  
            WHERE   
                ErrorCode IS NULL  
                AND ID > @RowID  
            ORDER BY ID ASC;  
  
            -- Log a transaction for the member status change.  
            EXEC mdm.udpTransactionSave   
                @User_ID = @User_ID,  
                @Version_ID = @Version_ID,   
                @TransactionType_ID = @TransactionType_ChangeMemberStatus,  
                @OriginalTransaction_ID = NULL,  
                @Hierarchy_ID = NULL,  
                @Entity_ID = @Entity_ID,  
                @Member_ID = @Member_ID,  
                @MemberType_ID = @MemberType_ID,  
                @Attribute_ID = NULL,   
                @OldValue = @OldStatus,  
                @NewValue = @NewStatus;  
        END; -- WHILE  
  
        --Commit only if we are not nested.  
        IF @TranCounter = 0 COMMIT TRANSACTION;  
  
        -- Return error rows.  
        SELECT  
             Member_ID  
            ,MemberType_ID  
            ,ErrorCode  
        FROM #MemberWorkingSet  
        WHERE ErrorCode IS NOT NULL;  
  
    END TRY  
    --Compensate as necessary  
    BEGIN CATCH  
  
        -- Get error info  
        DECLARE  
            @ErrorMessage NVARCHAR(4000),  
            @ErrorSeverity INT,  
            @ErrorState INT;  
        EXEC mdm.udpGetErrorInfo  
            @ErrorMessage = @ErrorMessage OUTPUT,  
            @ErrorSeverity = @ErrorSeverity OUTPUT,  
            @ErrorState = @ErrorState OUTPUT;  
                  
        IF @TranCounter = 0   
        BEGIN  
            ROLLBACK TRANSACTION;  
        END ELSE IF XACT_STATE() <> -1   
        BEGIN  
            ROLLBACK TRANSACTION TX;  
        END;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
  
        RETURN;  
          
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
