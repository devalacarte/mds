SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Procedure  : mdm.udpStagingRelationshipSave  
Component  : Import (Staging)  
Description: mdm.udpStagingRelationshipSave verifies and loads leaf, consolidation, and collections member relationships into MDS  
Parameters : User name, Model version ID, transaction log indicator (Boolean - defaults to No)  
Return     : Status indicator  
  
                EXEC mdm.udpStagingRelationshipSave 1, 2;  
                EXEC mdm.udpStagingRelationshipSave 'edmAdmin', 2, 1;  
                  
*/  
CREATE PROCEDURE [mdm].[udpStagingRelationshipSave]  
(  
   @User_ID            INT,  
   @Version_ID        INT,  
   @LogFlag            INT = NULL, --1 = Log; any other value = do not log  
   @Batch_ID        INT = NULL,  
   @Result            SMALLINT = NULL OUTPUT  
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
        ,@TargetType_ID             INT  
        ,@Stage_ID                  INT  
        ,@Meta_ID                   INT  
        ,@Model_Name                NVARCHAR(50)  
        ,@Entity_Name               NVARCHAR(50)  
        ,@Hierarchy_Name            NVARCHAR(50)              
        ,@Entity_Table              sysname  
        ,@Parent_Table              sysname  
        ,@Collection_Table          sysname  
        ,@Relationship_Table        sysname              
        ,@Member_Code               NVARCHAR(250)  
        ,@Target_Code               NVARCHAR(250)  
        ,@IsHierarchy               BIT  
        ,@Hierarchy_IsMandatory     BIT  
        ,@SQL                       NVARCHAR(MAX)  
        ,@ParamList                 NVARCHAR(MAX)  
        ,@ErrorMessage              NVARCHAR(4000)  
        ,@ErrorSeverity             INT   
        ,@ErrorState                INT   
        ,@Error                     INT  
        ,@MaxSortOrderRelationship	INT  
        ,@MaxSortOrderStaging		INT  
        ,@VersionStatus_ID			INT  
        ,@VersionStatus_Committed	INT = 3;    
  
          
    DECLARE @tblMeta TABLE   
    (  
         ID                        INT IDENTITY (1, 1) NOT NULL  
        ,Entity_ID                INT NOT NULL  
        ,Entity_Name            NVARCHAR(50) COLLATE database_default NOT NULL  
        ,Entity_Table            sysname  
        ,Parent_Table            sysname  
        ,Collection_Table        sysname  
        ,Relationship_Table        sysname  
        ,Hierarchy_ID            INT  
        ,Hierarchy_IsMandatory    BIT  
        ,MemberType_ID            INT  
        ,TargetType_ID            INT  
    );  
      
    DECLARE @tblHierarchy TABLE   
    (  
        Hierarchy_ID            INT  
    );  
  
    SET @Result = 1; --0=Success; 1=Failed-General; 2=Failed-Invalid User; 3=Failed-Invalid Version  
  
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
        RETURN(4);        
    END; --if  
  
        --Ensure that Version is not committed  
    IF (@VersionStatus_ID = @VersionStatus_Committed) BEGIN  
        RAISERROR('MDSERR310040|Data cannot be loaded into a committed version.', 16, 1);  
        RETURN(3);      
    END;   
      
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
            Relationship_ID        INT NOT NULL DEFAULT -1,    --ID from the hierarchy relationship or collection member table  
            MemberType_ID        INT NOT NULL,                --4=hierarchy relationship; 5=collection relationship (input)   
            Member_ID            INT NOT NULL,  
            Member_Code            NVARCHAR(250) COLLATE database_default NOT NULL,   
            ChildType_ID        INT NOT NULL DEFAULT 0,        --Source member type: 1=EN, 2=HP, 3=CN  
            MemberStatus_ID        TINYINT NOT NULL DEFAULT 1,    --Defaults to active   
            TargetType_ID        INT NOT NULL,                --Type of relationship: 1=parent; 2=sibling (move behind sibling)  
            Target_ID            INT NULL,  
            Target_Code            NVARCHAR(250) COLLATE database_default NULL,   
            TargetMemberType_ID    INT NOT NULL DEFAULT 0,        --Target member type: 1=leaf member, 2=parent member, 3=collection (derived)  
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
            Parent_ID        INT NOT NULL DEFAULT -2,  
            Child_ID        INT NOT NULL DEFAULT -2,  
            ChildType_ID    INT NOT NULL DEFAULT 0,  
            SortOrder        INT NOT NULL DEFAULT 0,  
            LevelNumber        SMALLINT NOT NULL DEFAULT (-1)  
        );  
  
        --Exclude errors identified by the view  
        UPDATE tStage SET   
            tStage.Status_ID = tView.Status_ID,   
            tStage.ErrorCode = tView.Status_ErrorCode  
        FROM mdm.tblStgRelationship AS tStage   
        INNER JOIN mdm.udfStagingRelationshipsGet(@User_ID, @Model_ID, 2,@Batch_ID) AS tView   
            ON tStage.ID = tView.Stage_ID;  
  
        --Identify entities and hierarchies (for recalculating level numbers and sort orders)  
        INSERT INTO @tblHierarchy (Hierarchy_ID)  
        SELECT DISTINCT Hierarchy_ID  
        FROM mdm.udfStagingRelationshipsGet(@User_ID, @Model_ID, 0,@Batch_ID)   
        WHERE Hierarchy_ID IS NOT NULL AND Hierarchy_ID > 0;  
  
        --Identify entities and hierarchies  
        INSERT INTO @tblMeta  
        (  
            Entity_ID, Entity_Name, Entity_Table, Parent_Table, Collection_Table, Relationship_Table, Hierarchy_ID, Hierarchy_IsMandatory, MemberType_ID, TargetType_ID  
        )  
        SELECT DISTINCT  
            Entity_ID,   
            Entity_Name,   
            Entity_Table,   
            Parent_Table,   
            Collection_Table,   
            Relationship_Table,   
            Hierarchy_ID,  
            Hierarchy_IsMandatory,  
            MemberType_ID,  
            TargetType_ID  
        FROM mdm.udfStagingRelationshipsGet(@User_ID, @Model_ID, 0, @Batch_ID);  
  
        --Iterate through the meta table  
        WHILE EXISTS(SELECT 1 FROM @tblMeta) BEGIN  
          
            SELECT TOP 1  
                @Meta_ID = ID,   
                @Entity_ID = Entity_ID,  
                @Entity_Table = Entity_Table,  
                @Parent_Table = Parent_Table,  
                @Collection_Table = Collection_Table,  
                @Relationship_Table = Relationship_Table,  
                @Hierarchy_ID = Hierarchy_ID,  
                @Hierarchy_IsMandatory = Hierarchy_IsMandatory,  
                @MemberType_ID = MemberType_ID,  
                @TargetType_ID = TargetType_ID  
            FROM @tblMeta;  
             
            IF @MemberType_ID = 4 SET @IsHierarchy = 1   
            ELSE SET @IsHierarchy = 0; --4=HR  
  
            --Populate temporary staging table  
            INSERT INTO #tblStage  
            (  
                Stage_ID, MemberType_ID, Member_ID, Member_Code, TargetType_ID, Target_ID, Target_Code, SortOrder  
            )  
            SELECT  
                Stage_ID,  
                MemberType_ID,  
                Member_ID,   
                Member_Code,   
                TargetType_ID,  
                Target_ID,  
                Target_Code,  
                SortOrder  
            FROM   
                mdm.udfStagingRelationshipsGet(@User_ID, @Model_ID, 0, @Batch_ID)  
            WHERE   
                Entity_ID = @Entity_ID  
                AND ((Hierarchy_ID IS NULL AND @Hierarchy_ID IS NULL) OR (Hierarchy_ID = @Hierarchy_ID))  
                AND MemberType_ID = @MemberType_ID  
                AND TargetType_ID = @TargetType_ID  
            ORDER BY    
                Stage_ID DESC; --To accommodate multiple moves for the same member load the most recent data first (EDM-2471)  
  
            /*  
            ------------------------  
            FETCH SOURCE MEMBER DATA  
            ------------------------  
            */  
  
            SET @ParamList = N'@VersionID INT, @HierarchyID INT';  
  
            --Update temporary table with Member_ID, MemberStatus_ID, and ChildType_ID = 1 (EN)              
            SET @SQL = N'  
                UPDATE tStage SET   
                    Member_ID = tSource.ID,   
                    MemberStatus_ID = tSource.Status_ID,   
                    ChildType_ID = 1   
                FROM #tblStage AS tStage   
                INNER JOIN mdm.' + quotename(@Entity_Table) + N' AS tSource   
                    ON tStage.Member_Code = tSource.Code   
                WHERE tSource.Version_ID = @VersionID;';  
  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
  
            --Update temporary table with Member_ID, MemberStatus_ID, and ChildType_ID = 2 (HP)  
            SET @SQL = N'  
                UPDATE tStage SET   
                    Member_ID = tSource.ID,   
                    MemberStatus_ID = tSource.Status_ID,   
                    ChildType_ID = 2  
                FROM #tblStage AS tStage  
                INNER JOIN mdm.' + quotename(@Parent_Table) + N' AS tSource   
                    ON tStage.Member_Code = tSource.Code   
                WHERE tSource.Version_ID = @VersionID';  
  
            IF @IsHierarchy = 1 SET @SQL = @SQL + N'  
                AND tSource.Hierarchy_ID = @HierarchyID;';  
                  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
  
            --Update temporary table with Member_ID, MemberStatus_ID, and ChildType_ID = 3 (collection) --EDM-2275: Staging should allow collections of collections  
            SET @SQL = N'  
                UPDATE tStage SET   
                    Member_ID = tSource.ID,   
                    MemberStatus_ID = tSource.Status_ID,   
                    ChildType_ID = 3   
                FROM #tblStage AS tStage   
                INNER JOIN mdm.' + quotename(@Collection_Table) + N' AS tSource   
                    ON tStage.Member_Code = tSource.Code   
                WHERE tSource.Version_ID = @VersionID;';  
  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
  
            /*  
            ------------------------  
            FETCH TARGET MEMBER DATA  
            ------------------------  
            */  
             
            IF @IsHierarchy = 1 BEGIN --Process hierarchy; target may be a leaf (if a sibling) or a consolidation  
  
                --Update temporary table with Target_ID, TargetStatus_ID, and TargetMemberType_ID = 1 (leaf)  
                SET @SQL = N'  
                    UPDATE tStage SET   
                        Target_ID = tSource.ID,   
                        TargetStatus_ID = tSource.Status_ID,   
                        TargetMemberType_ID = 1   
                    FROM #tblStage AS tStage      
                    INNER JOIN mdm.' + quotename(@Entity_Table) + N' AS tSource   
                        ON tStage.Target_Code = tSource.Code   
                    WHERE tSource.Version_ID = @VersionID;';  
  
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
  
                --Update temporary table with Target_ID, TargetStatus_ID, and TargetMemberType_ID = 2 (consolidation)  
                SET @SQL = N'  
                    UPDATE tStage SET   
                        Target_ID = tSource.ID,   
                        TargetStatus_ID = tSource.Status_ID,   
                        TargetMemberType_ID = 2  
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Parent_Table) + N' AS tSource   
                        ON tStage.Target_Code = tSource.Code   
                    WHERE tSource.Version_ID = @VersionID   
                        AND tSource.Hierarchy_ID = @HierarchyID;';  
  
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
  
            END ELSE BEGIN --Process collection (target is a collection)  
                  
                --Update temporary table with Target_ID, TargetStatus_ID, and TargetMemberType_ID = 3 (collection)  
                SET @SQL = N'  
                    UPDATE tStage SET   
                        Target_ID = tSource.ID,   
                        TargetStatus_ID = tSource.Status_ID,   
                        TargetMemberType_ID = 3   
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Collection_Table) + N' AS tSource   
                        ON tStage.Target_Code = tSource.Code   
                    WHERE tSource.Version_ID = @VersionID;';  
  
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
  
            END; --if  
             
            --If the target is a sibling then reassign the target ID (fetch the parent ID of the target) and assign the sort order of the sibling  
            IF @TargetType_ID = 2 BEGIN  
              
                SET @SQL = N'  
                    UPDATE tStage SET   
                         Target_ID = tRel.' + CASE @IsHierarchy WHEN 1 THEN N'Parent_HP_ID' ELSE N'Parent_CN_ID' END + N'  
                        ,SortOrder = tRel.SortOrder  
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tRel   
                        ON tStage.TargetMemberType_ID = tRel.ChildType_ID  
                        AND tStage.Target_ID = CASE tStage.TargetMemberType_ID   
                            WHEN 1 THEN tRel.Child_EN_ID   
                            WHEN 2 THEN tRel.Child_HP_ID' + CASE @IsHierarchy WHEN 1 THEN N'' ELSE N'  
                            WHEN 3 THEN tRel.Child_CN_ID' END + N'  
                        END --case  
                    WHERE tRel.Version_ID = @VersionID';  
  
                IF @IsHierarchy = 1 SET @SQL = @SQL + N'  
                        AND tRel.Hierarchy_ID = @HierarchyID;';  
                  
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
  
            END; --if                        
             
            --Mark records as invalid where the status is inactive  
            UPDATE #tblStage SET   
                Status_ID = 2,   
                Status_ErrorCode = N'210006'   
            WHERE MemberStatus_ID = 2;  
              
            UPDATE #tblStage SET   
                Status_ID = 2,   
                Status_ErrorCode = N'210008'   
            WHERE TargetStatus_ID = 2;  
  
            --Mark records as invalid where the codes do not exist  
            UPDATE #tblStage SET   
                Status_ID = 2,   
                Status_ErrorCode = N'210009'   
            WHERE Member_ID = -2 AND Status_ID = 1;  
              
            UPDATE #tblStage SET   
                Status_ID = 2,   
                Status_ErrorCode = N'210010'   
            WHERE Target_ID = -2 AND Status_ID = 1;  
  
            --Mark records as invalid where the target codes are leaves and the target type is parent  
            IF @TargetType_ID = 1  
                UPDATE #tblStage SET   
                    Status_ID = 2,   
                    Status_ErrorCode = N'210011'   
                WHERE TargetMemberType_ID = 1 AND Status_ID = 1;  
  
            --Populate relationship key for tracking purposes  
            --Orig  
            --SET @SQL = N'  
            --    UPDATE tStage SET   
            --        Relationship_ID = tSource.ID  
            --    FROM #tblStage AS tStage   
            --    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
            --        ON tStage.ChildType_ID = tSource.ChildType_ID                  
            --        AND tStage.Member_ID = CASE tStage.ChildType_ID  
            --                WHEN 1 THEN tSource.Child_EN_ID  
            --                WHEN 2 THEN tSource.Child_HP_ID' + CASE @IsHierarchy WHEN 1 THEN N'' ELSE N'  
            --                WHEN 3 THEN tSource.Child_CN_ID' END + N'  
            --            END --case  
            --    WHERE tSource.Version_ID = @VersionID   
            --        AND tStage.Status_ID = 1';  
                      
            --IF @IsHierarchy = 1 SET @SQL = @SQL + N'  
            --        AND tSource.Hierarchy_ID = @HierarchyID;';  
            --EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
              
            --EN  
            SET @SQL = N'  
                UPDATE tStage SET   
                    Relationship_ID = tSource.ID  
                FROM #tblStage AS tStage   
                INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
                    ON tStage.ChildType_ID = tSource.ChildType_ID                  
                    AND tStage.Member_ID = tSource.Child_EN_ID  
                          
                WHERE tSource.Version_ID = @VersionID   
                    AND tStage.ChildType_ID = 1  
                    AND tStage.Status_ID = 1';  
                      
            IF @IsHierarchy = 1 SET @SQL = @SQL + N'  
                    AND tSource.Hierarchy_ID = @HierarchyID;';  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
              
            --HP  
            SET @SQL = N'  
                UPDATE tStage SET   
                    Relationship_ID = tSource.ID  
                FROM #tblStage AS tStage   
                INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
                    ON tStage.ChildType_ID = tSource.ChildType_ID                  
                    AND tStage.Member_ID = tSource.Child_HP_ID  
                      
                WHERE tSource.Version_ID = @VersionID   
                    AND tStage.ChildType_ID = 2  
                    AND tStage.Status_ID = 1';  
                      
            IF @IsHierarchy = 1 SET @SQL = @SQL + N'  
                    AND tSource.Hierarchy_ID = @HierarchyID;';  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
              
            ----CN  
            --print 'about to start step 1c'  
            --SET @SQL = N'  
            --    UPDATE tStage SET   
            --        Relationship_ID = tSource.ID  
            --    FROM #tblStage AS tStage   
            --    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
            --        ON tStage.ChildType_ID = tSource.ChildType_ID                  
            --        AND tStage.Member_ID = tSource.Child_CN_ID  
            --    WHERE tSource.Version_ID = @VersionID   
            --        AND tStage.ChildType_ID = 3  
            --        AND tStage.Status_ID = 1';  
                      
            --IF @IsHierarchy = 1 SET @SQL = @SQL + N'  
            --        AND tSource.Hierarchy_ID = @HierarchyID;';  
            --print @SQL  
            --EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
              
  
            /*  
              Mark records that are redundant.  This step is only pertinent for parent hierarchy assignments.    
              Sibling assignents are considered unique for they are employed to reassign sort orders.  
              Collection relationships support redundancy (i.e., more than one of the same member).  
            */  
            IF @IsHierarchy = 1 AND @TargetType_ID = 1 BEGIN  
                ----orig  
                --SET @SQL = N'   
                --    UPDATE tStage SET   
                --        Status_ID = 3,   
                --        Status_Message = N''Warning - redundant relationship; transaction will not be logged''  
                --    FROM #tblStage AS tStage   
                --    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
                --        ON tStage.ChildType_ID = tSource.ChildType_ID  
                --        AND tStage.Member_ID = CASE tStage.ChildType_ID  
                --            WHEN 1 THEN tSource.Child_EN_ID  
                --            WHEN 2 THEN tSource.Child_HP_ID  
                --        END --case  
                --        AND tStage.Target_ID = tSource.Parent_HP_ID  
                --    WHERE tSource.Version_ID = @VersionID   
                --        AND tStage.Status_ID = 1    
                --        AND tSource.Hierarchy_ID = @HierarchyID;';  
                --EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
                  
                --EN              
                --Warning - redundant assignment; transaction will not be logged      
                SET @SQL = N'   
                    UPDATE tStage SET   
                        Status_ID = 3,   
                        Status_ErrorCode = N''210007''  
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
                        ON tStage.ChildType_ID = tSource.ChildType_ID  
                        AND tStage.Member_ID = tSource.Child_EN_ID  
                        AND tStage.Target_ID = tSource.Parent_HP_ID  
                    WHERE tSource.Version_ID = @VersionID   
                        AND tStage.ChildType_ID = 1  
                        AND tStage.Status_ID = 1    
                        AND tSource.Hierarchy_ID = @HierarchyID;';  
                  
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
                                  
                --HP      
                --Warning - redundant assignment; transaction will not be logged              
                SET @SQL = N'   
                    UPDATE tStage SET   
                        Status_ID = 3,   
                        Status_ErrorCode = N''210007''  
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
                        ON tStage.ChildType_ID = tSource.ChildType_ID  
                        AND tStage.Member_ID = tSource.Child_HP_ID  
                        AND tStage.Target_ID = tSource.Parent_HP_ID  
                    WHERE tSource.Version_ID = @VersionID   
                        AND tStage.ChildType_ID = 2  
                        AND tStage.Status_ID = 1    
                        AND tSource.Hierarchy_ID = @HierarchyID;';  
                  
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
                  
  
            END; --if  
  
            --Mark new records (MDS supports redundant collection records; hence, the IF/ELSE clause)  
            IF @IsHierarchy = 1              
                UPDATE #tblStage SET   
                    Status_ID = 4,  
                    Status_ErrorCode = N'210012'   
                WHERE Status_ID = 1 AND Relationship_ID = -1;  
                  
            ELSE --A collection  
                UPDATE #tblStage SET   
                    Status_ID = 4,  
                    Status_ErrorCode = N'210013'   
                WHERE Status_ID = 1;  
  
            --Mark records to be removed (moving to Unused for non-mandatory hierarchies)  
            UPDATE #tblStage SET   
                Status_ID = 5,   
                Status_ErrorCode = N'210014'   
            WHERE Target_ID = -1 AND Status_ID = 1;  
  
            /*  
            --------------------------------------------  
            FETCH PRIOR VALUES (FOR TRANSACTION LOGGING)  
            --------------------------------------------  
            If logging is requested then insert into the transaction log  
            */  
              
            IF @LogFlag = 1 BEGIN  
              
                SET @ParamList = N'@VersionID INT, @HierarchyID INT';  
                  
                --Fetch previous target ID from relationship table  
                SET @SQL = N'  
                    UPDATE tStage SET   
                        PrevTarget_ID = tSource.' + CASE @IsHierarchy WHEN 1 THEN N'Parent_HP_ID' ELSE N'Parent_CN_ID' END + N'  
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource  
                        ON tStage.Relationship_ID = tSource.ID  
                    WHERE tSource.Version_ID = @VersionID  
                        AND tStage.Status_ID = 1';  
  
                IF @IsHierarchy = 1 SET @SQL = @SQL + N'  
                        AND tSource.Hierarchy_ID = @HierarchyID;';  
  
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
  
                --Fetch previous target code from hierarchy parent table  
                SET @SQL = N'  
                    UPDATE tStage SET   
                        PrevTarget_Code = tSource.Code   
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Parent_Table) + N' AS tSource   
                        ON tStage.PrevTarget_ID = tSource.ID  
                    WHERE tSource.Version_ID = @VersionID    
                        AND tStage.Status_ID = 1;';  
  
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;  
  
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
            IF @IsHierarchy = 1 BEGIN  
              
                SET @ParamList = N'@UserID INT, @VersionID INT, @HierarchyID INT';  
  
                ----Orig  
                --SET @SQL = N'  
                --    UPDATE tSource SET  
                --         Parent_HP_ID = NULLIF(tStage.Target_ID, 0)  
                --        ,SortOrder =  COALESCE(NULLIF(tStage.SortOrder, 0), tStage.Stage_ID)  
                --        ,LastChgDTM = GETUTCDATE()  
                --        ,LevelNumber = -1  
                --        ,IndexCode = NULL  
                --        ,LastChgUserID = @UserID   
                --        ,LastChgVersionID = @VersionID   
                --    FROM #tblStage AS tStage   
                --    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource  
                --        ON tStage.ChildType_ID = tSource.ChildType_ID   
                --        AND tStage.Member_ID = CASE tStage.ChildType_ID  
                --            WHEN 1 THEN tSource.Child_EN_ID  
                --            WHEN 2 THEN tSource.Child_HP_ID  
                --        END --case  
                --    WHERE tSource.Version_ID = @VersionID   
                --        AND tStage.Status_ID = 1    
                --        AND tSource.Hierarchy_ID = @HierarchyID;';  
  
                --EXEC sp_executesql @SQL, @ParamList, @User_ID, @Version_ID, @Hierarchy_ID;  
                  
                --EN  
                SET @SQL = N'  
                    UPDATE tSource SET  
                         Parent_HP_ID = NULLIF(tStage.Target_ID, 0)  
                        ,LastChgDTM = GETUTCDATE()  
                        ,LevelNumber = -1  
                        ,LastChgUserID = @UserID   
                        ,LastChgVersionID = @VersionID   
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource  
                        ON tStage.ChildType_ID = tSource.ChildType_ID   
                        AND tStage.Member_ID = tSource.Child_EN_ID  
                    WHERE tSource.Version_ID = @VersionID   
                        AND tStage.ChildType_ID = 1  
                        AND tStage.Status_ID = 1    
                        AND tSource.Hierarchy_ID = @HierarchyID;';  
  
                EXEC sp_executesql @SQL, @ParamList, @User_ID, @Version_ID, @Hierarchy_ID;  
                  
                --HP  
                SET @SQL = N'  
                    UPDATE tSource SET  
                         Parent_HP_ID = NULLIF(tStage.Target_ID, 0)  
                        ,LastChgDTM = GETUTCDATE()  
                        ,LevelNumber = -1  
                        ,LastChgUserID = @UserID   
                        ,LastChgVersionID = @VersionID   
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource  
                        ON tStage.ChildType_ID = tSource.ChildType_ID   
                        AND tStage.Member_ID = tSource.Child_HP_ID  
                    WHERE tSource.Version_ID = @VersionID   
                        AND tStage.ChildType_ID = 2  
                        AND tStage.Status_ID = 1    
                        AND tSource.Hierarchy_ID = @HierarchyID;';  
  
                EXEC sp_executesql @SQL, @ParamList, @User_ID, @Version_ID, @Hierarchy_ID;                  
            END; --if  
          
            /*  
            ---------------------------  
            DELETE RELATIONSHIP RECORDS  
            ---------------------------  
            Update mdm.tblHR - remove records where the target is unused  
            */  
              
            SET @ParamList = N'@VersionID INT';  
  
            SET @SQL = N'  
                DELETE FROM mdm.' + quotename(@Relationship_Table) + N'   
                WHERE Version_ID = @VersionID   
                    AND ID IN (SELECT Relationship_ID FROM #tblStage WHERE Status_ID = 5);';  
  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID;  
  
            --Flag Duplicate Child Records in a NonMandatory Hierarchy  
            IF @IsHierarchy = 1 AND @Hierarchy_IsMandatory = 0 BEGIN  
                UPDATE #tblStage SET     
                     Status_ID = 2    
                    ,Status_ErrorCode = N'210015'   
                FROM #tblStage s  
                WHERE Member_ID <> -2 AND EXISTS     
                    (    
                        SELECT ds.Member_ID   
                        FROM #tblStage ds  
                        WHERE ds.Member_ID = s.Member_ID  
                        AND ds.ChildType_ID = s.ChildType_ID  
                        GROUP BY Member_ID    
                        HAVING COUNT(*) <> 1    
                    );  
  
            END; --if  
              
            /*  
            ----------------------------------------------------------  
            UPDATE SortOrder previously inserted from udpStgMemberSave  
            ----------------------------------------------------------  
            */  
            IF @IsHierarchy = 1 BEGIN   
              
                SET @MaxSortOrderRelationship = 0;  
                SET @MaxSortOrderStaging = 0;  
  
                -- Get the maximum Sort Order for the existing records in the HR table  
                SET @SQL = N'SELECT  @MaxSortOrderRelationship = MAX(tSource.SortOrder)   
                            FROM mdm.' + quotename(@Relationship_Table) + N' AS tSource  
                                INNER JOIN #tblStage tStage1   
                                ON tStage1.ChildType_ID = tSource.ChildType_ID   
                            WHERE NOT EXISTS (SELECT tStage.Member_ID   
                                              FROM #tblStage AS tStage   
                                              WHERE tStage.Member_ID = tSource.Child_EN_ID  )  
                                    AND tSource.Hierarchy_ID = @HierarchyID		    
                                    AND tSource.Status_ID = 1;';  
                                  
                EXEC sp_executesql @SQL, N'@HierarchyID INT, @MaxSortOrderRelationship INT OUTPUT', @Hierarchy_ID, @MaxSortOrderRelationship OUTPUT;    
                  
                -- Get the maximum Sort Order for the records to be inserted in the staging table	  
                SET @SQL = N'SELECT @MaxSortOrderStaging = MAX(tStage.SortOrder)  
                             FROM #tblStage AS tStage   
                                INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
                                ON tStage.Relationship_ID = tSource.ID  
                                WHERE tSource.Hierarchy_ID = @HierarchyID;';  
                                  
                EXEC sp_executesql @SQL, N'@HierarchyID INT, @MaxSortOrderStaging INT OUTPUT', @Hierarchy_ID, @MaxSortOrderStaging OUTPUT;   
                  
            END;  
              
            SET @SQL = 'UPDATE tSource    
                SET tSource.SortOrder = tStage.SortOrder ';  
              
            -- Bump up the sort order for the staging records by adding the current maximum Sort Order 	  
            IF @MaxSortOrderStaging <= @MaxSortOrderRelationship SET @SQL = @SQL + ' + @MaxSortOrderRelationship';  
                      
            SET @SQL = @SQL + '	FROM mdm.' + quotename(@Relationship_Table) + N' AS  tSource    
                        INNER JOIN #tblStage AS tStage ON    
                        tStage.Relationship_ID = tSource.ID';    
              
            EXEC sp_executesql @SQL, N'@MaxSortOrderRelationship INT', @MaxSortOrderRelationship;   
   
              
            /*  
            -------------------------------  
            INSERT NEW RELATIONSHIP RECORDS  
            -------------------------------  
            */  
  
            --Insert into the hierarchy temporary table (necessary to generate key values)  
            --Added a DISTINCT to eliminate potential duplicate records for collections  
            SET @ParamList = N'@VersionID INT, @HierarchyID INT';  
              
            SET @SQL = N'  
                INSERT INTO #tblRelation   
                (  
                    Version_ID,  
                    Hierarchy_ID,  
                    Parent_ID,  
                    Child_ID,  
                    ChildType_ID,  
                    SortOrder  
                ) SELECT DISTINCT  
                    @VersionID,    
                    @HierarchyID,   
                    Target_ID, --Parent_ID  
                    Member_ID,   
                    ChildType_ID,  
                    SortOrder  
                FROM #tblStage   
                WHERE Status_ID = 4;';  
                
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID;           
  
            --Insert into hierarchy relationship table  
               SET @ParamList = N'@UserID INT, @VersionID INT';  
                
            SET @SQL = N'  
                INSERT INTO mdm.' + quotename(@Relationship_Table) + N'  
                (  
                    Version_ID,  
                    Status_ID,  
                    ' + CASE @IsHierarchy WHEN 1 THEN N'Parent_HP_ID' ELSE N'Parent_CN_ID' END + N',  
                    Child_EN_ID,   
                    Child_HP_ID,' + CASE @IsHierarchy WHEN 1 THEN N'' ELSE N'  
                    Child_CN_ID,' END + N'  
                    ChildType_ID,  
                    SortOrder,  
                    EnterDTM,   
                    EnterUserID,  
                    EnterVersionID,  
                    LastChgDTM,  
                    LastChgUserID,  
                    LastChgVersionID';  
  
            --If a hierarchy include the Hierarchy_ID and LevelNumber  
            IF @IsHierarchy = 1  
                SET @SQL = @SQL + N',  
                    Hierarchy_ID,   
                    LevelNumber';  
  
            --Assign the SortOrder = SortOrder from the staging table  
            SET @SQL = @SQL + N'  
                )  
                SELECT  
                    Version_ID,  
                    Status_ID,  
                    NULLIF(Parent_ID, 0), --Parent_HP_ID / Parent_CN_ID  
                    CASE WHEN ChildType_ID = 1 THEN Child_ID ELSE NULL END, --EN  
                    CASE WHEN ChildType_ID = 2 THEN Child_ID ELSE NULL END, --HP' + CASE @IsHierarchy WHEN 1 THEN N'' ELSE N'  
                    CASE WHEN ChildType_ID = 3 THEN Child_ID ELSE NULL END, --CN' END + N'  
                    ChildType_ID,  
                    SortOrder,  
                    GETUTCDATE(),   
                    @UserID ,   
                    @VersionID,   
                    GETUTCDATE(),   
                    @UserID ,   
                    @VersionID';  
  
            --If a hierarchy include the Hierarchy_ID and LevelNumber  
            IF @IsHierarchy = 1   
                SET @SQL = @SQL + N',  
                    Hierarchy_ID,  
                    LevelNumber';  
                      
            SET @SQL = @SQL + N'  
                FROM #tblRelation;';  
  
            EXEC sp_executesql @SQL,@ParamList, @User_ID, @Version_ID;  
  
            /*  
            --------------------------------------------------------------------------------------------  
            VERIFY THAT RECURSIVE ASSINGMENTS HAVE NOT BEEN ENTERED  
            This can be accomplished by calculating the level number.    
            Any levels that can not be calculated are deemed recursive and will be moved to the Root.  
            --------------------------------------------------------------------------------------------  
            */  
  
            IF @IsHierarchy = 1 BEGIN   
              
                --Calculate level numbers for the current hierarchy  
                EXEC mdm.udpHierarchyMemberLevelSave @Version_ID, @Hierarchy_ID, 0, 2;  
                  
                SET @ParamList = N'@VersionID INT, @HierarchyID INT';  
                  
                --For those relationships where the LevelNumber = -1 (i.e., can not be calculated) move to Root                  
                SET @SQL = N'  
                    UPDATE tStage SET   
                        Target_ID = PrevTarget_ID,   
                        Target_Code = PrevTarget_Code,   
                        Status_ID = 6,   
                        Status_ErrorCode = N''210016''  
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
                        ON tStage.Relationship_ID = tSource.ID  
                    WHERE tSource.LevelNumber = -1   
                        AND tSource.Version_ID = @VersionID    
                        AND tSource.Hierarchy_ID = @HierarchyID  AND tStage.Status_ID = 1;';  
  
                EXEC sp_executesql @SQL,@ParamList, @Version_ID, @Hierarchy_ID;    
  
                -- --orig  
             --    --Reset the source table  
                --SET @SQL = N'  
                --    UPDATE tSource SET   
                --         Parent_HP_ID = NULLIF(tStage.PrevTarget_ID, 0)  
                --    FROM #tblStage AS tStage   
                --    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
                --        ON tStage.ChildType_ID = tSource.ChildType_ID   
                --        AND tStage.Member_ID = CASE tStage.ChildType_ID  
                --            WHEN 1 THEN tSource.Child_EN_ID  
                --            WHEN 2 THEN tSource.Child_HP_ID  
                --        END --case  
                --    WHERE tSource.LevelNumber = -1   
                --        AND tSource.Version_ID = @VersionID   
                --        AND tSource.Hierarchy_ID = @HierarchyID;';  
                --print 'here5'  
                --EXEC sp_executesql @SQL,@ParamList, @Version_ID, @Hierarchy_ID;     
                  
                 --Reset the source table  
                 --EN  
                SET @SQL = N'  
                    UPDATE tSource SET   
                         Parent_HP_ID = NULLIF(tStage.PrevTarget_ID, 0)  
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
                        ON tStage.ChildType_ID = tSource.ChildType_ID   
                        AND tStage.Member_ID = tSource.Child_EN_ID  
                    WHERE tSource.LevelNumber = -1  
                        AND tStage.ChildType_ID = 1  
                        AND tSource.Version_ID = @VersionID   
                        AND tSource.Hierarchy_ID = @HierarchyID;';  
                  
                EXEC sp_executesql @SQL,@ParamList, @Version_ID, @Hierarchy_ID;     
                                  
                 --Reset the source table  
                 --HP                   
                SET @SQL = N'  
                    UPDATE tSource SET   
                         Parent_HP_ID = NULLIF(tStage.PrevTarget_ID, 0)  
                    FROM #tblStage AS tStage   
                    INNER JOIN mdm.' + quotename(@Relationship_Table) + N' AS tSource   
                        ON tStage.ChildType_ID = tSource.ChildType_ID   
                        AND tStage.Member_ID = tSource.Child_HP_ID  
                    WHERE tSource.LevelNumber = -1   
                        AND tStage.ChildType_ID = 2  
                        AND tSource.Version_ID = @VersionID   
                        AND tSource.Hierarchy_ID = @HierarchyID;';  
                  
                EXEC sp_executesql @SQL,@ParamList, @Version_ID, @Hierarchy_ID;     
                                  
            END; --if  
  
            /*  
            ---------------------------  
            PROCESS TRANSACTION LOGGING  
            ---------------------------  
            If logging is requested then insert into the transaction log  
            */  
              
            IF @LogFlag = 1 BEGIN  
              
                SET @ParamList = N'@VersionID INT, @HierarchyID INT, @EntityID INT, @UserID INT';  
  
                --Log relationship transactions  
                SET @SQL = N'  
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
                        @VersionID,   
                        CASE TargetType_ID WHEN 1 THEN 4 WHEN 2 THEN 5 ELSE 0 END,   
                        0,   
                        @HierarchyID,   
                        @EntityID,   
                        Member_ID,   
                        ChildType_ID,   
                        Member_Code,  
                        CASE PrevTarget_ID WHEN NULL THEN -1 ELSE PrevTarget_ID END,   
                        CASE PrevTarget_ID WHEN NULL THEN ''MDMUNUSED'' WHEN -1 THEN ''MDMUNUSED'' WHEN 0 THEN ''ROOT'' ELSE PrevTarget_Code END,   
                        Target_ID,   
                        Target_Code,   
                        GETUTCDATE(),   
                        @UserID ,   
                        GETUTCDATE(),   
                        @UserID   
                    FROM #tblStage   
                    WHERE Status_ID IN (1, 4, 5);';  
                      
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Hierarchy_ID, @Entity_ID, @User_ID;           
  
            END; --if  
              
            /*  
            ----------------------  
            UPDATE STAGING RECORDS  
            ----------------------  
            Update mdm.tblStgRelationship with member status  
            */  
              
            UPDATE tStage SET   
                Status_ID = CASE tTemp.Status_ID WHEN 2 THEN 2 ELSE 1 END,   
                ErrorCode = tTemp.Status_ErrorCode  
            FROM mdm.tblStgRelationship AS tStage   
            INNER JOIN #tblStage AS tTemp   
                ON tTemp.Stage_ID = tStage.ID;  
  
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
  
        SET @Result = 0;  
        --Commit only if we are not nested  
        IF @TranCounter = 0   
            COMMIT TRANSACTION;  
            
        RETURN(0);  
          
    END TRY  
    BEGIN CATCH  
  
        SELECT @Error = @@ERROR, @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
  
        IF @TranCounter = 0   
            ROLLBACK TRANSACTION;  
        ELSE IF XACT_STATE() <> -1   
            ROLLBACK TRANSACTION TX;  
              
        RAISERROR('MDSERR310053|An unknown error occurred when staging relatonships.', 16, 1);  
  
        RETURN(1)  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
