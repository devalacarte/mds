SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    Procedure  : mdm.udpStagingMemberSave  
    Component  : Import (Staging)  
    Description: mdm.udpStagingMemberSave verifies and loads leaf, consolidation, and collections members into +EDM  
                NOTE **: When an unknown exception is encountered during member staging,  
                potential offending records are marked as error and the process continues   
                through a single transaction.  To allow for this type of processing, this stored   
                procedure cannot be executed in a context of outer transaction from a calling stored  
                procedure.  
    Parameters : User name, Model version ID, transaction log indicator (Boolean - defaults to No)  
    Return     : Status indicator  
  
    UPDATE mdm.tblStgMember SET MemberCode = mdm.udfAttributeGenerateName(NEWID()), Status_ID = 0, ErrorCode = N'';  
    DECLARE @Result INT;  
    EXEC mdm.udpStagingMemberSave 1, 4, 1, NULL, @Result OUTPUT;  
    PRINT @Result;  
      
    EXEC mdm.udpStagingMemberSave 1, 4;  
      
    SELECT * FROM mdm.tblStgMember;  
    select * FROM mdm.udfStagingMembersGet(1, 2, 0,null);  
*/  
CREATE PROCEDURE [mdm].[udpStagingMemberSave]  
(  
   @User_ID     INT,  
   @Version_ID  INT,  
   @LogFlag     INT = NULL, --1 = Log; any other value = do not log  
   @Batch_ID    INT = NULL,  
   @Result      SMALLINT = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
         @UserName                  NVARCHAR(100)  
        ,@Model_ID                  INT  
        ,@Entity_ID                 INT              
        ,@Hierarchy_ID              INT              
        ,@MemberType_ID             INT              
        ,@Stage_ID                  INT  
        ,@Meta_ID                   INT  
        ,@MemberTypeLeaf            INT = 1--EN  
        ,@MemberTypeCons            INT = 2--HP  
        ,@MemberTypeColl            INT = 3--CN  
        ,@HasHierarchy              BIT              
        ,@Model_Name                NVARCHAR(50)  
        ,@Entity_Name               NVARCHAR(50)              
        ,@Hierarchy_Name            NVARCHAR(50)              
        ,@Member_Code               NVARCHAR(250)  
        ,@Member_Name               NVARCHAR(250)          
        ,@Entity_Table              sysname  
        ,@Hierarchy_Table           sysname  
        ,@Collection_Table          sysname  
        ,@SQL                       NVARCHAR(MAX)  
        ,@ErrorMessage              NVARCHAR(4000)   
        ,@ErrorSeverity             INT   
        ,@ErrorState                INT   
        ,@Error                     INT  
        ,@VersionStatus_ID			INT  
        ,@VersionStatus_Committed	INT = 3  
        ,@TranCounter               INT  
              
        -- staging datastatus constants  
        ,@StatusDefault				INT = 0  
        ,@StatusOK					INT = 1  
        ,@StatusError				INT = 2  
          
        --XACT_STATE() constants  
        ,@UncommittableTransaction	INT = -1;       
          
    DECLARE @TableMeta TABLE   
    (  
        ID                    INT IDENTITY (1, 1) NOT NULL,   
        Entity_ID            INT NOT NULL,   
        Entity_Name            NVARCHAR(50) NOT NULL,   
        Entity_Table        sysname NULL,   
        Entity_HasHierarchy    BIT,   
        Hierarchy_ID        INT,   
        Hierarchy_Table        sysname NULL,   
        Collection_Table    sysname NULL,   
        MemberType_ID        INT  
    );  
      
    DECLARE @TableHierarchy TABLE   
    (  
        Hierarchy_ID        INT  
    );  
      
    SET @Result = 1; --0=Success; 1=Failed-General; 2=Failed-Invalid User; 3=Failed-Invalid Version; 4--Failed-Need Admin privileges  
  
    --Check for invalid User  
    IF @User_ID IS NULL RETURN 2;      
    SET @UserName = mdm.udfUserNameGetByUserID(@User_ID);  
    IF @UserName IS NULL RETURN 2;      
      
    --Check for invalid Model  
    SELECT @Model_ID = Model_ID, @VersionStatus_ID = Status_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID;    
    IF @Model_ID IS NULL RETURN 3;      
    SELECT @Model_Name = [Name] FROM mdm.tblModel WHERE ID = @Model_ID;  
    IF @Model_Name IS NULL RETURN 3;  
  
    --Confirm that the user possesses Model administrator rights before allowing staging to begin  
    IF NOT EXISTS(SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MODEL WHERE [User_ID] = @User_ID AND ID = @Model_ID AND IsAdministrator = 1) BEGIN  
        RAISERROR('MDSERR120002|The user does not have permission to perform this operation.', 16, 1);  
        RETURN 4;  
    END; --if      
  
    --Ensure that Version is not committed  
    IF (@VersionStatus_ID = @VersionStatus_Committed) BEGIN  
        RAISERROR('MDSERR310040|Data cannot be loaded into a committed version.', 16, 1);  
        RETURN 3;      
    END;      
      
    BEGIN TRY  
      
        --Create member staging temporary table  
        CREATE TABLE #tblStage   
        (  
           Stage_ID             BIGINT NOT NULL,  
           Member_ID            INT IDENTITY (1, 1) NOT NULL,   
           Member_Code          NVARCHAR(250) COLLATE database_default NOT NULL,   
           Member_Name          NVARCHAR(250) COLLATE database_default NOT NULL,   
           Status_ID            INT NOT NULL DEFAULT 1,   
           Status_ErrorCode     NVARCHAR(10) COLLATE database_default NOT NULL DEFAULT N'210000'  
        );  
  
        --Create relationship temporary table  
        CREATE TABLE #tblRelation  
        (  
           ID                  BIGINT IDENTITY (1, 1) NOT NULL,   
           Version_ID          INT NOT NULL,  
           Status_ID           INT NOT NULL DEFAULT 1,  
           Hierarchy_ID        INT NOT NULL,  
           Parent_ID           INT NOT NULL DEFAULT 0,  
           Child_ID            INT NOT NULL,  
           Child_Code          NVARCHAR(250) COLLATE database_default NOT NULL,   
           ChildType_ID        INT NOT NULL,  
           SortOrder           INT NOT NULL DEFAULT 0,  
           LevelNumber         SMALLINT NOT NULL DEFAULT (-1)  
        );  
          
        CREATE TABLE #tblMemberID  
        (  
            Stage_ID    INT NOT NULL PRIMARY KEY,  
            ID          INT NOT NULL  
        );  
  
        --PRE-PROCESSING AND VALIDATION  
        --Exclude duplicate codes in the staging table {MDS data verification}  
        UPDATE tStage SET   
           Status_ID = @StatusError,   
           ErrorCode = N'210001'  
        FROM  
           mdm.tblStgMember AS tStage          
        INNER JOIN ( --udfStagingMembersGet returns only records that have been pre-validated for the current user and Model  
            SELECT Entity_Name, Member_Code   
            FROM mdm.udfStagingMembersGet(@User_ID, @Model_ID, 0,@Batch_ID)   
            GROUP BY Entity_Name, Member_Code HAVING COUNT(*) > 1  
        ) AS tDup   
            ON LTRIM(RTRIM(tStage.EntityName)) = tDup.Entity_Name   
            AND LTRIM(RTRIM(tStage.MemberCode)) = tDup.Member_Code   
            AND LEN(LTRIM(RTRIM(tStage.MemberCode))) > 0              
            AND tStage.ID > (    SELECT MIN(ID) --Allow the first of the 'duplicate' codes to be staged.  All others flagged as duplicates.  
                                FROM mdm.tblStgMember AS tStage2   
                                INNER JOIN (    SELECT Entity_Name, Member_Code   
                                                FROM mdm.udfStagingMembersGet(@User_ID, @Model_ID, 0,@Batch_ID) GROUP BY Entity_Name, Member_Code HAVING COUNT(*) > 1) AS tDup2   
                                    ON LTRIM(RTRIM(tStage2.EntityName)) = tDup2.Entity_Name   
                                    AND LTRIM(RTRIM(tStage2.MemberCode)) = tDup2.Member_Code   
                                    AND LEN(LTRIM(RTRIM(tStage2.MemberCode))) > 0  
                                    AND tDup.Entity_Name = tDup2.Entity_Name  
                                    AND tDup.Member_Code = tDup2.Member_Code  
                                    WHERE Status_ID = @StatusDefault AND ModelName = @Model_Name  
            )  
        WHERE Status_ID = @StatusDefault AND ModelName = @Model_Name;  
   
        --Identify entities and hierarchies (for recalculating level numbers and sort orders)  
        INSERT INTO @TableHierarchy(Hierarchy_ID)  
        SELECT DISTINCT Hierarchy_ID  
        FROM mdm.udfStagingMembersGet(@User_ID, @Model_ID, 0, @Batch_ID)   
        WHERE Hierarchy_ID IS NOT NULL AND Hierarchy_ID > 0;  
  
        --Identify and exclude duplicate codes in the MDM model - must be unique across an entire entity  
        INSERT INTO @TableMeta(Entity_ID, Entity_Name)  
        SELECT DISTINCT Entity_ID, Entity_Name  
        FROM mdm.udfStagingMembersGet(@User_ID, @Model_ID, 0, @Batch_ID);  
  
        --Iterate through each entity in the meta table  
        WHILE EXISTS(SELECT 1 FROM @TableMeta) BEGIN  
  
            SELECT TOP 1   
                @Meta_ID = ID, @Entity_ID = Entity_ID, @Entity_Name = Entity_Name   
            FROM @TableMeta;  
              
            SELECT   
                @Entity_Table = EntityTableName, @Hierarchy_Table = HierarchyParentTableName, @Collection_Table = CollectionTableName   
            FROM [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Entity_ID;  
  
            --Verify uniqueness against the entity table  
            SET @SQL = N'  
                UPDATE tStage SET   
                    Status_ID = @StatusError,   
                    ErrorCode = N''300003''  
                FROM mdm.tblStgMember AS tStage   
                INNER JOIN mdm.' + quotename(@Entity_Table) + N' AS tSource   
                    ON tStage.MemberCode = tSource.Code   
                WHERE tSource.Version_ID = @Version_ID AND tStage.ModelName = @Model_Name AND tStage.EntityName = @Entity_Name  
                    AND tStage.MemberType_ID IN (SELECT ID FROM mdm.tblEntityMemberType WHERE ID IN (1, 2, 3))  
                    AND tStage.Status_ID = @StatusDefault   
                    AND (tStage.UserName = @UserName OR LEN(LTRIM(RTRIM(ISNULL(tStage.UserName, N'''')))) = 0)   
                    AND (COALESCE(tStage.Batch_ID, -1) = COALESCE(@Batch_ID, -1) OR LEN(LTRIM(RTRIM(ISNULL(tStage.Batch_ID, N'''')))) = 0);';  
  
            --PRINT @SQL;  
            EXEC sp_executesql @SQL,   
                N'@Version_ID INT, @Model_Name NVARCHAR(50), @Entity_Name NVARCHAR(50), @UserName NVARCHAR(100), @StatusError INT, @StatusDefault INT, @Batch_ID INT',   
                @Version_ID, @Model_Name, @Entity_Name, @UserName, @StatusError, @StatusDefault, @Batch_ID;  
  
            --Verify uniqueness against the parent table  
            IF @Hierarchy_Table IS NOT NULL BEGIN  
  
                SET @SQL = N'  
                    UPDATE tStage SET   
                        Status_ID = @StatusError,   
                        ErrorCode = N''300003''  
                    FROM mdm.tblStgMember AS tStage   
                    INNER JOIN mdm.' + quotename(@Hierarchy_Table) + N' AS tSource   
                        ON tStage.MemberCode = tSource.Code   
                    WHERE tSource.Version_ID = @Version_ID AND tStage.ModelName = @Model_Name AND tStage.EntityName = @Entity_Name   
                        AND tStage.MemberType_ID IN (SELECT ID FROM mdm.tblEntityMemberType WHERE ID IN (1, 2, 3))  
                        AND tStage.Status_ID = @StatusDefault   
                        AND (tStage.UserName = @UserName OR LEN(LTRIM(RTRIM(ISNULL(tStage.UserName, N'''')))) = 0)   
                        AND (COALESCE(tStage.Batch_ID , -1) = COALESCE(@Batch_ID, -1) OR LEN(LTRIM(RTRIM(ISNULL(tStage.Batch_ID, N'''')))) = 0);';  
                          
                --PRINT @SQL;  
                EXEC sp_executesql @SQL,   
                    N'@Version_ID INT, @Model_Name NVARCHAR(50), @Entity_Name NVARCHAR(50), @UserName NVARCHAR(100), @StatusError INT, @StatusDefault INT, @Batch_ID INT',   
                    @Version_ID, @Model_Name, @Entity_Name, @UserName, @StatusError, @StatusDefault, @Batch_ID;  
  
                --Verify uniqueness against the collection table (GEMINI:2473: Include collections when determining code uniqueness)  
                SET @SQL = N'  
                    UPDATE tStage SET   
                        Status_ID = @StatusError,   
                        ErrorCode = N''300003''  
                    FROM mdm.tblStgMember AS tStage   
                    INNER JOIN mdm.' + quotename(@Collection_Table) + N' AS tSource   
                        ON tStage.MemberCode = tSource.Code   
                    WHERE tSource.Version_ID = @Version_ID AND tStage.ModelName = @Model_Name AND tStage.EntityName = @Entity_Name  
                        AND tStage.MemberType_ID IN (SELECT ID FROM mdm.tblEntityMemberType WHERE ID IN (1, 2, 3))  
                        AND tStage.Status_ID = @StatusDefault   
                        AND (tStage.UserName = @UserName OR LEN(LTRIM(RTRIM(ISNULL(tStage.UserName, N'''')))) = 0)   
                        AND (COALESCE(tStage.Batch_ID, -1) = COALESCE(@Batch_ID, -1) OR LEN(LTRIM(RTRIM(ISNULL(tStage.Batch_ID, N'''')))) = 0);';  
                          
                --PRINT @SQL;  
                EXEC sp_executesql @SQL,   
                    N'@Version_ID INT, @Model_Name NVARCHAR(50), @Entity_Name NVARCHAR(50), @UserName NVARCHAR(100), @StatusError INT, @StatusDefault INT, @Batch_ID INT',   
                    @Version_ID, @Model_Name, @Entity_Name, @UserName, @StatusError, @StatusDefault, @Batch_ID;  
                  
            END; --if  
                
            DELETE FROM @TableMeta WHERE ID = @Meta_ID;  
              
        END; --while  
  
        --Exclude errors identified by the view {MDM data verification}  
        UPDATE tStage SET   
            tStage.Status_ID = tView.Status_ID,   
            tStage.ErrorCode = tView.Status_ErrorCode  
        FROM mdm.tblStgMember AS tStage   
        INNER JOIN mdm.udfStagingMembersGet(@User_ID, @Model_ID, 2, @Batch_ID) AS tView --Returns all staging records in error for the current user and model  
            ON tStage.ID = tView.Stage_ID;  
  
        --ITERATIONS  
        --Identify entities and hierarchies  
        INSERT INTO @TableMeta   
        (  
            Entity_ID,  
            Entity_Name,   
            Entity_Table,   
            Entity_HasHierarchy,  
            Hierarchy_ID,   
            Hierarchy_Table,   
            Collection_Table,   
            MemberType_ID   
        )          
        SELECT DISTINCT  
            Entity_ID,   
            Entity_Name,   
            Entity_Table,   
            Entity_HasHierarchy,  
            Hierarchy_ID,   
            Hierarchy_Table,   
            Collection_Table,   
            MemberType_ID   
        FROM   
            mdm.udfStagingMembersGet(@User_ID, @Model_ID, 0, @Batch_ID); --Returns only records that have been pre-validated for the current user and Model  
              
        --Iterate through each entity in the meta table  
        WHILE EXISTS(SELECT 1 FROM @TableMeta) BEGIN  
              
             --Start transaction, being careful to check if we are nested  
            SET @TranCounter = @@TRANCOUNT;  
            IF @TranCounter > 0 SAVE TRANSACTION TX;  
            ELSE BEGIN TRANSACTION;   
            BEGIN TRY  
                    SELECT TOP 1  
                        @Meta_ID = ID,   
                        @Entity_ID = Entity_ID,  
                        @Entity_Name = Entity_Name,  
                        @Entity_Table = Entity_Table,  
                        @HasHierarchy = Entity_HasHierarchy,  
                        @Hierarchy_ID = Hierarchy_ID,  
                        @Hierarchy_Table = Hierarchy_Table,  
                        @Collection_Table = Collection_Table,  
                        @MemberType_ID = MemberType_ID   
                    FROM   
                        @TableMeta;  
                      
                    INSERT INTO #tblStage(Stage_ID, Member_Code, Member_Name)  
                    SELECT  
                        Stage_ID,  
                        Member_Code = ISNULL(NULLIF(Member_Code, N''), N'#SYS-' + CONVERT(NVARCHAR(36), NEWID()) + N'#'),  
                        Member_Name   
                    FROM   
                        mdm.udfStagingMembersGet(@User_ID, @Model_ID, 0, @Batch_ID) --Returns only records that have been pre-validated for the current user and Model  
                    WHERE   
                        Entity_ID = @Entity_ID  
                        AND ((@Hierarchy_ID IS NULL AND Hierarchy_ID IS NULL) OR (Hierarchy_ID = @Hierarchy_ID))  
                        AND MemberType_ID = @MemberType_ID;  
  
                    /*  
                    ----------------------  
                    PROCESS ENTITY MEMBERS  
                    ----------------------  
                    */  
                                                                  
                    --Insert into the entity (EN) table  
                    SET @SQL = N'  
                        TRUNCATE TABLE #tblMemberID;  
                        INSERT INTO mdm.' + quotename(@Entity_Table) + N'   
                        (  
                             Version_ID   
                            ,AsOf_ID --Use this column to map between new @@IDENTITY and Stage_ID within OUTPUT clause  
  
                            ,Status_ID  
                            ,ValidationStatus_ID  
                            ,Name  
                            ,Code  
                            ,EnterDTM  
                            ,EnterUserID  
                            ,EnterVersionID  
                            ,LastChgDTM  
                            ,LastChgUserID  
                            ,LastChgVersionID  
                            ' + CASE @MemberType_ID   
                                    WHEN @MemberTypeCons THEN N',Hierarchy_ID'   
                                    WHEN @MemberTypeColl THEN N',Owner_ID'  
                                    ELSE N''  
                                END + N'  
                        )  
                        OUTPUT inserted.AsOf_ID, inserted.ID INTO #tblMemberID(Stage_ID, ID)  
                        SELECT  
                             @Version_ID --Version_ID  
                            ,Stage_ID --AsOf_ID  
                            ,1 --Status_ID  
                            ,CASE @MemberType_ID   
                                    WHEN ' + CONVERT(NVARCHAR, @MemberTypeColl) + N' THEN 3 --Set ValidationStatus_ID TO 3 (validation succeeded) for collection members since business rules does not apply   
                                    ELSE 0 --Set ValidationStatus_ID to New AwaitingValidation  
                                 END    
                            ,Member_Name  
                            ,Member_Code  
                            ,GETUTCDATE() --EnterDTM  
                            ,@User_ID --EnterUserID  
                            ,@Version_ID --EnterVersionID  
                            ,GETUTCDATE() --LastChgDTM  
                            ,@User_ID --LastChgUserID  
                            ,@Version_ID --LastChgVersionID  
                            ' + CASE @MemberType_ID   
                                    WHEN @MemberTypeCons THEN N',@Hierarchy_ID' --Hierarchy_ID  
                                    WHEN @MemberTypeColl THEN N',@User_ID'      --Owner_ID  
                                    ELSE N''   
                                END + N'  
                        FROM #tblStage   
                        WHERE Status_ID = @StatusOK;  
                          
                        --Reset all AsOf_ID values since we just needed them temporarily for OUTPUT clause  
                        UPDATE mdm.' + quotename(@Entity_Table) + N' SET [AsOf_ID] = NULL   
                        WHERE Version_ID = @Version_ID AND ID IN (SELECT ID FROM #tblMemberID);';  
  
                    --PRINT @SQL;  
                    EXEC sp_executesql @SQL,   
                        N'@User_ID INT, @Version_ID INT, @Hierarchy_ID INT, @MemberType_ID INT, @StatusOK INT',   
                        @User_ID, @Version_ID, @Hierarchy_ID, @MemberType_ID, @StatusOK;  
  
                    --If a leaf (that has a hierarchy) or a consolidation then insert into the hierarchy relationship table  
                    IF @HasHierarchy = 1 AND @MemberType_ID IN (1,2) BEGIN  
  
                        /*  
                        -----------------  
                        PROCESS HIERARCHY   
                        -----------------  
                        Cons member: If a hierarchy is specified, then insert into hierarchy table and default to ROOT {MDS system rule}  
                        Leaf member: Insert a record for each hierarchy {MDS system rule}  
                        */  
  
                        --Insert into the hierarchy temporary table (necessary to generate key values)  
                        SET @SQL = N'  
                            INSERT INTO #tblRelation   
                            (  
                                 Version_ID  
                                ,Hierarchy_ID  
                                ,Child_ID  
                                ,Child_Code  
                                ,ChildType_ID  
                                ,SortOrder  
                            )                      
                            SELECT  
                                 @Version_ID --Version_ID  
                                ,tHier.ID --Hierarchy_ID  
                                ,tID.ID --Child_ID  
                                ,Member_Code --Child_Code  
                                ,@MemberType_ID --ChildType_ID  
                                ,tID.ID --SortOrder  
                            FROM #tblStage AS tStage                           
                            INNER JOIN #tblMemberID AS tID   
                                ON (tStage.Stage_ID = tID.Stage_ID)  
                            INNER JOIN mdm.tblHierarchy AS tHier';  
                           
                        /*  
                        If the member type is a consolidation use the specified hierarchy.  Otherwise, insert all hierarchies associated with the entity,   
                        for leaves appear in all hierarchies and default to ROOT {MDS system rule}.    
  
                        Non-Mandatory Hierarchies  
                        -------------------------  
                        1) Leaf members are exluded from insertions into the relationship table and will appear under the 'UNUSED' node.  
                        2) Consolidation members are inserted into the relationship table and will appear under the 'ROOT' node.  
                        */  
                        IF @MemberType_ID = @MemberTypeCons   
                            SET @SQL = @SQL + N'                      
                                ON COALESCE(tHier.ID, -1) = COALESCE(@Hierarchy_ID, -1)   
                            WHERE tStage.Status_ID = @StatusOK;';  
                        ELSE  
                            SET @SQL = @SQL + N'   
                                ON tHier.Entity_ID = @Entity_ID   
                            WHERE tStage.Status_ID = @StatusOK AND tHier.IsMandatory = 1;';  
  
                        --PRINT @SQL;  
                        EXEC sp_executesql @SQL,   
                            N'@Version_ID INT, @MemberType_ID INT, @Hierarchy_ID INT, @Entity_ID INT, @StatusOK INT',   
                            @Version_ID, @MemberType_ID, @Hierarchy_ID, @Entity_ID, @StatusOK;  
  
                        --Insert into hierarchy relationship (HR) table  
                       SET @SQL = N'  
                            INSERT INTO mdm.' + quotename(@Hierarchy_Table) + '  
                            (  
                                Version_ID,  
                                Status_ID,  
                                Hierarchy_ID,  
                                Parent_HP_ID,  
                                Child_EN_ID,  
                                Child_HP_ID,                      
                                ChildType_ID,  
                                SortOrder,  
                                LevelNumber,  
                                EnterDTM,   
                                EnterUserID,  
                                EnterVersionID,  
                                LastChgDTM,  
                                LastChgUserID,  
                                LastChgVersionID  
                            )  
                            SELECT  
                                Version_ID,  
                                Status_ID,  
                                Hierarchy_ID,  
                                NULLIF(Parent_ID, 0), --Parent_HP_ID  
                                CASE WHEN ChildType_ID = 1 THEN Child_ID ELSE NULL END, --Child_EN_ID  
                                CASE WHEN ChildType_ID = 2 THEN Child_ID ELSE NULL END, --Child_HP_ID  
                                ChildType_ID,  
                                SortOrder,  
                                LevelNumber,  
                                GETUTCDATE(),   
                                @User_ID,  
                                @Version_ID,   
                                GETUTCDATE(),   
                                @User_ID,  
                                @Version_ID  
                            FROM #tblRelation;';  
  
                        --PRINT @SQL;  
                        EXEC sp_executesql @SQL, N'@User_ID INT, @Version_ID INT', @User_ID, @Version_ID;  
                          
                    END; --if  
  
  
                    /*  
                    ---------------------------  
                    PROCESS TRANSACTION LOGGING  
                    ---------------------------  
                    If logging is requested then insert into the transaction log  
                    */  
                    IF @LogFlag = 1 BEGIN  
  
                        --Log member add transactions  
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
                            @Version_ID, --Version_ID  
                            1, --TransactionType_ID  
                            0, --OriginalTransaction_ID  
                            @Hierarchy_ID, --Hierarchy_ID  
                            @Entity_ID, --Entity_ID  
                            tID.ID, --Member_ID  
                            @MemberType_ID, --MemberType_ID  
                            tStage.Member_Code,  
                            N'', --OldValue  
                            N'', --OldCode  
                            N'', --NewValue  
                            N'', --NewCode  
                            GETUTCDATE(),   
                            @User_ID,   
                            GETUTCDATE(),   
                            @User_ID  
                        FROM #tblStage AS tStage  
                        INNER JOIN #tblMemberID AS tID  
                            ON (tStage.Stage_ID = tID.Stage_ID)  
                        WHERE tStage.Status_ID = @StatusOK;--';  
                           
                        --If a leaf (that has a hierarchy) or a consolidation then log the relationship save transaction  
                        IF @HasHierarchy = 1 BEGIN  
                           
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
                                Version_ID,   
                                4,   
                                0,   
                                Hierarchy_ID,   
                                @Entity_ID,   
                                Child_ID,   
                                ChildType_ID,  
                                Child_Code,   
                                0,   
                                N'ROOT',   
                                0,   
                                N'ROOT',   
                                GETUTCDATE(),   
                                @User_ID,   
                                GETUTCDATE(),   
                                @User_ID  
                            FROM #tblRelation;  
  
                        END; --if  
                    END; --if  
                        
  
                    /*  
                    ----------------------  
                    UPDATE STAGING RECORDS  
                    ----------------------  
                    Update mdm.tblStgMember with member status  
                    */  
                    UPDATE tStage SET Status_ID = tTemp.Status_ID, ErrorCode = tTemp.Status_ErrorCode  
                    FROM mdm.tblStgMember tStage JOIN #tblStage tTemp ON tTemp.Stage_ID = tStage.ID;  
  
                    TRUNCATE TABLE #tblMemberID;  
                    TRUNCATE TABLE #tblStage;  
                    TRUNCATE TABLE #tblRelation;  
                     
                    DELETE FROM @TableMeta WHERE ID = @Meta_ID;  
                      
                    --Commit only if we are not nested  
                    IF @TranCounter = 0   
                        COMMIT TRANSACTION;  
                 
            END TRY  
            BEGIN CATCH  
                  
                --Rollback any previously uncommitted transactions    
                IF @TranCounter = 0     
                    ROLLBACK TRANSACTION;    
                ELSE IF XACT_STATE() <> @UncommittableTransaction     
                    ROLLBACK TRANSACTION TX;    
                  
                --Mark the records as having an unknown exception and continue processing the rest of the batch  
                UPDATE tStage SET   
                    Status_ID = @StatusError,   
                    ErrorCode = N'210055'  
                FROM mdm.tblStgMember tStage  
                    INNER JOIN mdm.udfStagingMembersGet(@User_ID, @Model_ID, 0, @Batch_ID) tView --Returns only records that have been pre-validated for the current user and Model  
                        ON tStage.ID = tView.Stage_ID  
                WHERE tView.Entity_ID = @Entity_ID  
                        AND ((@Hierarchy_ID IS NULL AND tView.Hierarchy_ID IS NULL) OR (tView.Hierarchy_ID = @Hierarchy_ID))  
                        AND tView.MemberType_ID = @MemberType_ID;  
                      
                DELETE FROM @TableMeta WHERE ID = @Meta_ID;  
       
            END CATCH;  
        END; ---while  
          
        DROP TABLE #tblMemberID;  
        DROP TABLE #tblStage;  
        DROP TABLE #tblRelation;  
          
           /*  
        ---------------------------------------  
        RECALCULATE HIERARCHY SYSTEM ATTRIBUTES  
        ---------------------------------------  
        */  
        --Iterate through the meta table  
        WHILE EXISTS(SELECT 1 FROM @TableHierarchy) BEGIN  
             
           SELECT @Hierarchy_ID = Hierarchy_ID FROM @TableHierarchy;  
  
           --Recalculate system hierarchy attributes (level number, sort order, and index code)  
           EXEC mdm.udpHierarchySystemAttributesSave @Version_ID, @Hierarchy_ID;  
  
           DELETE FROM @TableHierarchy WHERE Hierarchy_ID = @Hierarchy_ID;  
             
        END; --while  
  
        SET @Result = 0;  
          
        RETURN(0);  
          
    END TRY  
    BEGIN CATCH  
  
        SELECT @Error = @@ERROR, @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
  
        RAISERROR('MDSERR310051|An unknown error occurred when staging members.', 16, 1);  
  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
