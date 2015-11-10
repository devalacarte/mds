SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    --Create new hierarchy  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER, @Type INT;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpEntityHierarchySave 1, NULL, 47, 'test2', 1, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblHierarchy WHERE ID = @Return_ID;  
  
    --Update existing hierarchy  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER, @Type INT;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpEntityHierarchySave 1, 12, 1, 'test5', 1, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblHierarchy WHERE ID = @Return_ID;  
*/  
CREATE PROCEDURE [mdm].[udpEntityHierarchySave]  
(  
    @User_ID            INT,  
    @Hierarchy_ID       INT = NULL,  
    @Entity_ID          INT,    
    @HierarchyName      NVARCHAR(100),  
    @IsMandatory        BIT,  
    @Return_ID          INT = NULL OUTPUT,  
    @Return_MUID        UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
        @SQL                        NVARCHAR(MAX),  
        @IsFlat                     BIT,  
        @EntityTable                sysname,  
        @HierarchyParentTable       sysname,  
        @HierarchyTable             sysname,  
        @CollectionTable            sysname,  
        @CollectionMemberTable      sysname,  
        @StagingConsolidatedTable   sysname,  
        @StagingRelationshipTable   sysname,  
        @StagingBase                NVARCHAR(60),   
        @SecurityTable              sysname,  
        @Version_ID                 INT,  
        @Model_ID                   INT,  
        @CurrentDTM                 DATETIME2(3),  
        @Compress                   NVARCHAR(MAX) = N'';  
  
    --Initialize output parameters and local variables  
    SELECT  
        @HierarchyName = NULLIF(LTRIM(RTRIM(@HierarchyName)), N''),  
        @Return_ID = NULL,  
        @CurrentDTM = GETUTCDATE();  
  
    --Get the latest Model Version, whilst checking for other invalid parameters  
    SELECT  @Model_ID = m.ID,   
            @IsFlat = e.IsFlat,   
            @Version_ID = MAX(v.ID)  
    FROM mdm.tblModel m  
    INNER JOIN mdm.tblEntity e ON (m.ID = e.Model_ID)  
    INNER JOIN mdm.tblModelVersion v ON (m.ID = v.Model_ID)  
    WHERE e.ID = @Entity_ID  
    GROUP BY m.ID, e.IsFlat;  
      
    --Set the staging table names       
    SELECT    
        @StagingConsolidatedTable = StagingConsolidatedName,  
        @StagingRelationshipTable = StagingRelationshipName,   
        @StagingBase = StagingBase  
    FROM  
        [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Entity_ID;  
      
    --Test for invalid parameters  
    IF (@Model_ID IS NULL) --Invalid @Entity_ID (via invalid @Model_ID)  
        OR (@Hierarchy_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblHierarchy WHERE Entity_ID = @Entity_ID AND ID = @Hierarchy_ID)) --Invalid @Hierarchy_ID  
        OR NOT EXISTS(SELECT ID FROM mdm.tblUser WHERE ID = @User_ID) --Invalid @User_ID  
    BEGIN  
        SELECT @Hierarchy_ID = NULL, @Return_MUID = NULL;  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
  
    DECLARE @HierarchyNameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @HierarchyName, @HierarchyNameHasReservedCharacters OUTPUT;  
    IF @HierarchyNameHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100053|The explicit hierarchy cannot be created because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
          
        --Fetch main table name for Entity  
        SELECT   
            @EntityTable = EntityTable,  
            @SecurityTable = SecurityTable  
        FROM mdm.tblEntity WHERE ID = @Entity_ID;  
                  
        --If Entity does not currently have hierarchies, create the necessary tables  
        IF @IsFlat = 1 BEGIN  
  
            --Generate table names  
            WITH cte(prefix) AS (SELECT N'tbl_' + CONVERT(sysname, @Model_ID) + N'_' + CONVERT(sysname, @Entity_ID))  
            SELECT  
                @HierarchyTable = prefix + N'_HR',  
                @HierarchyParentTable = prefix + N'_HP',  
                @CollectionTable = prefix + N'_CN',  
                @CollectionMemberTable = prefix + N'_CM'  
            FROM cte;  
  
            --Flag current Entity to be non-flat  
            UPDATE mdm.tblEntity SET   
                IsFlat = 0, --Mark Entity as now using hierarchies  
                --Assign table names  
                HierarchyTable = @HierarchyTable,  
                HierarchyParentTable = @HierarchyParentTable,  
                CollectionTable = @CollectionTable,  
                CollectionMemberTable = @CollectionMemberTable,  
                SecurityTable = @SecurityTable,  
                --Ensure changes are audited  
                LastChgDTM = @CurrentDTM,  
                LastChgUserID = @User_ID,  
                LastChgVersionID = @Version_ID  
            WHERE ID = @Entity_ID;  
  
            --Create the Hierarchy Parent table (HP)  
            SET @SQL =  N'  
                CREATE TABLE mdm.' + quotename(@HierarchyParentTable) + N'   
                (   
                    --Identity  
                    Version_ID          INT NOT NULL,  
                    ID                  INT IDENTITY (1, 1) NOT NULL,  
                    --Status  
                    Status_ID           TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyParentTable  + N'_Status_ID') + N' DEFAULT 1,  
                    ValidationStatus_ID TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyParentTable  + N'_ValidationStatus_ID') + N' DEFAULT 0,  
                      
                    --Data  
                    [Name]              NVARCHAR(250) NULL,  
                    Code                NVARCHAR(250) NOT NULL,  
                    Hierarchy_ID        INT NOT NULL,  
  
                    --Change Tracking  
                    ChangeTrackingMask  INT NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyParentTable  + N'_ChangeTrackingMask') + N' DEFAULT 0,  
                      
                    --Auditing                      
                    EnterDTM            DATETIME2(3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyParentTable  + N'_EnterDTM') + N' DEFAULT GETUTCDATE(),  
                    EnterUserID         INT NOT NULL,  
                    EnterVersionID      INT NOT NULL,  
                    LastChgDTM          DATETIME2(3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyParentTable  + N'_LastChgDTM') + N' DEFAULT GETUTCDATE(),  
                    LastChgUserID       INT NOT NULL,  
                    LastChgVersionID    INT NOT NULL,  
                    LastChgTS           ROWVERSION NOT NULL,  
                    AsOf_ID             INT NULL,                      
                    MUID                UNIQUEIDENTIFIER NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyParentTable + N'_MUID') + N' DEFAULT NEWID() ROWGUIDCOL,  
                                                              
                    --Create PRIMARY KEY constraint  
                    CONSTRAINT ' + quotename(N'pk_' + @HierarchyParentTable  + N'') + N'   
                        PRIMARY KEY CLUSTERED (Version_ID, ID),  
                      
                    --Create FOREIGN KEY contraints  
                    CONSTRAINT ' + quotename(N'fk_' + @HierarchyParentTable  + N'_tblModelVersion_Version_ID') + N'  
                        FOREIGN KEY (Version_ID) REFERENCES mdm.tblModelVersion(ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE NO ACTION,  
                    CONSTRAINT ' + quotename(N'fk_' + @HierarchyParentTable  + N'_tblHierarchy_Hierarchy_ID') + N'  
                        FOREIGN KEY (Hierarchy_ID) REFERENCES mdm.tblHierarchy(ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE CASCADE,  
  
                    --Create CHECK constraints  
                    CONSTRAINT ' + quotename(N'ck_' + @HierarchyParentTable  + N'_Status_ID') + N'   
                        CHECK (Status_ID BETWEEN 1 AND 2),  
                    CONSTRAINT ' + quotename(N'ck_' + @HierarchyParentTable  + N'_ValidationStatus_ID') + N'   
                        CHECK (ValidationStatus_ID BETWEEN 0 and 5)                          
                )  
                ' + @Compress + N';  
                ';  
                                
            --Direct assignment of expression > 4000 nchars seems to truncate string. Workaround is to concatenate.  
            SET @SQL = @SQL + N'  
                --Ensure uniqueness of [Code]  
                CREATE UNIQUE NONCLUSTERED INDEX ' + quotename(N'ux_' + @HierarchyParentTable  + N'_Version_ID_Code') + N'   
                    ON mdm.' + quotename(@HierarchyParentTable) + N'(Version_ID, Code)  
                    ' + @Compress + N';  
  
                --Index [Name] for performance  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @HierarchyParentTable + N'_Version_ID_Name') + N'   
                    ON mdm.' + quotename(@HierarchyParentTable) + N'(Version_ID, Name)  
                    ' + @Compress + N';  
                      
                --Ensure uniqueness of [MUID]  
                CREATE UNIQUE NONCLUSTERED INDEX ' + quotename(N'ux_' + @HierarchyParentTable + N'_MUID') + N'  
                    ON mdm.' + quotename(@HierarchyParentTable) + N'(MUID)  
                    ' + @Compress + N';  
  
                --Required for VersionCopy operations  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @HierarchyParentTable  + N'_Version_ID_AsOf_ID') + N'   
                    ON mdm.' + quotename(@HierarchyParentTable) + N'(Version_ID, AsOf_ID)  
                    WHERE [AsOf_ID] IS NOT NULL  
                    ' + @Compress + N';  
                    ';  
  
            --Execute the dynamic SQL  
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL;  
  
            --If @StagingConsolidatedTable is specified create the Consolidated Staging table (_Consolidated) in Staging (stg) Schema  
            IF COALESCE(@StagingConsolidatedTable, N'') <> N'' BEGIN  
                SET @SQL =  N'    
                    CREATE TABLE [stg].' + quotename(@StagingConsolidatedTable) + N'     
                    (     
                        --Identity    
                        ID                  INT IDENTITY (1, 1) NOT NULL,  
                          
                        --Import Specific  
                        ImportType          TINYINT NOT NULL,  
  
                        --Status    
                        ImportStatus_ID     TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @StagingConsolidatedTable  + N'_ImportStatus_ID') + N' DEFAULT 0,   
                            
                        --Info    
                        Batch_ID            INT NULL,  
                        BatchTag            NVARCHAR(50) NULL,  
                        --Error Code  
                        ErrorCode           INT,  
                        HierarchyName       NVARCHAR(250) NULL,     
                        Code                NVARCHAR(250) NOT NULL,      
                        [Name]              NVARCHAR(250) NULL,  
                        NewCode             NVARCHAR(250) NULL,                         
                                                                                          
                        --Create PRIMARY KEY constraint    
                        CONSTRAINT ' + quotename(N'pk_' + @StagingConsolidatedTable) + N'     
                            PRIMARY KEY CLUSTERED (ID),    
                        
                        --Create CHECK constraints    
                        CONSTRAINT ' + quotename(N'ck_' + @StagingConsolidatedTable + N'_ImportType') + N'     
                            CHECK (ImportType BETWEEN 0 AND 4),    
                              
                        CONSTRAINT ' + quotename(N'ck_' + @StagingConsolidatedTable + N'_ImportStatus_ID') + N'     
                            CHECK (ImportStatus_ID BETWEEN 0 and 3)                            
                    )    
                    ' + @Compress + N';    
                      
                    --Index [Batch_ID] for performance  
                    CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @StagingConsolidatedTable + N'_Batch_ID') + N'   
                        ON [stg].' + quotename(@StagingConsolidatedTable) + N'(Batch_ID)  
                        ' + @Compress + N';  
                    --Index [BatchTag] for performance  
                    CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @StagingConsolidatedTable + N'_BatchTag') + N'   
                        ON [stg].' + quotename(@StagingConsolidatedTable) + N'(BatchTag)  
                        ' + @Compress + N';                               
                    ';  
        
                --Execute the dynamic SQL    
                --PRINT(@SQL);    
                EXEC sp_executesql @SQL;              
  
                EXEC mdm.udpEntityStagingCreateConsolidatedStoredProcedure @Entity_ID  
              
            END; --IF  
  
            --Create the Hierarchy Relationship table (HR)  
            SET @SQL = N'  
                CREATE TABLE mdm.' + quotename(@HierarchyTable) + N'   
                (   
                    --Identity  
                    Version_ID          INT NOT NULL,  
                    ID                  INT IDENTITY(1, 1) NOT NULL,  
                      
                    --Status  
                    Status_ID           TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyTable + N'_Status_ID') + N' DEFAULT 1,  
                    ValidationStatus_ID TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyTable + N'_ValidationStatus_ID') + N' DEFAULT 0,  
                      
                    --Pointers  
                    Hierarchy_ID        INT NOT NULL,  
                    Parent_HP_ID        INT NULL, --Root is NULL  
                    ChildType_ID        TINYINT NOT NULL,  
                    Child_EN_ID         INT NULL, --Only used when ChildType_ID = 1 (EN)  
                    Child_HP_ID         INT NULL, --Only used when ChildType_ID = 2 (HP)  
  
                    --Data  
                    SortOrder           INT NOT NULL,  
                    LevelNumber         SMALLINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyTable + N'_LevelNumber_ID') + N' DEFAULT -1,  
                                          
                    --Auditing  
                    EnterDTM            DATETIME2(3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyTable + N'_EnterDTM') + N' DEFAULT GETUTCDATE(),  
                    EnterUserID         INT NOT NULL,  
                    EnterVersionID      INT NOT NULL,  
                    LastChgDTM          DATETIME2(3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyTable + N'_LastChgDTM') + N' DEFAULT GETUTCDATE(),  
                    LastChgUserID       INT NOT NULL,  
                    LastChgVersionID    INT NOT NULL,  
                    LastChgTS           ROWVERSION NOT NULL,  
                    AsOf_ID             INT NULL,  
                    MUID                UNIQUEIDENTIFIER NOT NULL CONSTRAINT ' + quotename(N'df_' + @HierarchyTable + N'_MUID') + N' DEFAULT NEWID() ROWGUIDCOL,  
                                                              
                    --Create PRIMARY KEY constraint  
                    CONSTRAINT ' + quotename(N'pk_' + @HierarchyTable) + N'  
                        PRIMARY KEY NONCLUSTERED (Version_ID, ID)  
                        ' + @Compress + N',  
                                              
                    --Create FOREIGN KEY constraints  
                    CONSTRAINT ' + quotename(N'fk_' + @HierarchyTable + N'_tblModelVersion_Version_ID') + N'  
                        FOREIGN KEY (Version_ID) REFERENCES mdm.tblModelVersion(ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE NO ACTION,  
                    CONSTRAINT ' + quotename(N'fk_' + @HierarchyTable + N'_tblHierarchy_Hierarchy_ID') + N'  
                        FOREIGN KEY (Hierarchy_ID) REFERENCES mdm.tblHierarchy(ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE CASCADE,  
                    CONSTRAINT ' + quotename(N'fk_' + @HierarchyTable + N'_' + @HierarchyParentTable + N'_Parent_HP_ID') + N'  
                        FOREIGN KEY (Version_ID, Parent_HP_ID) REFERENCES mdm.' + quotename(@HierarchyParentTable) + N'(Version_ID, ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE NO ACTION, --Cannot use DELETE SET NULL since Version_ID is NOT NULLable  
                    CONSTRAINT ' + quotename(N'fk_' + @HierarchyTable + N'_' + @EntityTable + N'_Child_EN_ID') + N'  
                        FOREIGN KEY (Version_ID, Child_EN_ID) REFERENCES mdm.' + quotename(@EntityTable) + N'(Version_ID, ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE CASCADE,  
                    CONSTRAINT ' + quotename(N'fk_' + @HierarchyTable + N'_' + @HierarchyParentTable + N'_Child_HP_ID') + N'  
                        FOREIGN KEY (Version_ID, Child_HP_ID) REFERENCES mdm.' + quotename(@HierarchyParentTable) + N'(Version_ID, ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE NO ACTION, --Cannot use DELETE CASCADE due to chance of cycles  
                                              
                    --Create CHECK constraints  
                    CONSTRAINT ' + quotename(N'ck_' + @HierarchyTable + N'_Status_ID') + N'  
                        CHECK (Status_ID BETWEEN 1 AND 2),  
                    CONSTRAINT ' + quotename(N'ck_' + @HierarchyTable + N'_ValidationStatus_ID') + N'  
                        CHECK (ValidationStatus_ID BETWEEN 0 and 5),  
                    CONSTRAINT ' + quotename(N'ck_' + @HierarchyTable + N'_ChildType_ID') + N'  
                        CHECK (    (ChildType_ID = 1 AND Child_EN_ID IS NOT NULL AND Child_HP_ID IS NULL) OR  
                                (ChildType_ID = 2 AND Child_HP_ID IS NOT NULL AND Child_EN_ID IS NULL)),  
                    CONSTRAINT ' + quotename(N'ck_' + @HierarchyTable + N'_Parent_HP_ID_Child_HP_ID') + N'  
                        CHECK (NOT (ChildType_ID = 2 AND Parent_HP_ID = Child_HP_ID)) --Prevent self-reference  
                )  
                ' + @Compress + N';  
                ';  
  
            --Direct assignment of expression > 4000 nchars seems to truncate string. Workaround is to concatenate.  
            SET @SQL = @SQL + N'  
                --Ensure uniqueness of keyset  
                CREATE UNIQUE CLUSTERED INDEX ' + quotename(N'ux_' + @HierarchyTable + N'_Version_ID_Hierarchy_ID_ChildType_ID_Child_HP_ID_Child_EN_ID') + N'   
                    ON mdm.' + quotename(@HierarchyTable) + N'(Version_ID, Hierarchy_ID, ChildType_ID, Child_HP_ID, Child_EN_ID);  
                  
                --Required for foreign key join performance  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @HierarchyTable + N'_Version_ID_Parent_HP_ID') + N'  
                    ON mdm.' + quotename(@HierarchyTable) + N'(Version_ID, Parent_HP_ID)  
                    WHERE [Parent_HP_ID] IS NOT NULL  
                    ' + @Compress + N';  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @HierarchyTable + N'_Version_ID_Child_EN_ID') + N'  
                    ON mdm.' + quotename(@HierarchyTable) + N'(Version_ID, Child_EN_ID)  
                    WHERE [Child_EN_ID] IS NOT NULL  
                    ' + @Compress + N';  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @HierarchyTable + N'_Version_ID_Child_HP_ID') + N'  
                    ON mdm.' + quotename(@HierarchyTable) + N'(Version_ID, Child_HP_ID)  
                    WHERE [Child_HP_ID] IS NOT NULL  
                    ' + @Compress + N';  
  
                --Required for VersionCopy operations  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @HierarchyTable  + N'_Version_ID_AsOf_ID') + N'   
                    ON mdm.' + quotename(@HierarchyTable) + N'(Version_ID, AsOf_ID)  
                    WHERE [AsOf_ID] IS NOT NULL  
                    ' + @Compress + N';  
                      
                --Required for faster entity deletes  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @HierarchyTable  + N'_Version_ID_Status_ID_Parent_HP_ID_ChildType_ID_Child_EN_ID_Child_HP_ID_Asof_ID') + N'   
                    ON mdm.' + quotename(@HierarchyTable) + N'([Version_ID],[Status_ID],[Parent_HP_ID],[ChildType_ID],[Child_EN_ID],[Child_HP_ID],[AsOf_ID])  
                    ' + @Compress + N';  
  
                --Required for faster entity gets  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @HierarchyTable  + N'_Version_ID_ChildType_ID_Hierarchy_ID_Child_EN_ID') + N'   
                    ON mdm.' + quotename(@HierarchyTable) + N'([Version_ID],[ChildType_ID],[Hierarchy_ID],[Child_EN_ID])  
                    ' + @Compress + N';  
  
                --Required for faster hierarchy moves  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @HierarchyTable  + N'_Version_ID_Hierarchy_ID_Parent_HP_ID') + N'   
                    ON mdm.' + quotename(@HierarchyTable) + N'([Version_ID],[Hierarchy_ID],[Parent_HP_ID])  
                    ' + @Compress + N';  
                ';  
              
            --Execute the dynamic SQL           
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL;  
  
            --If @StagingRelationshipTable is specified create the Hierarchy Relationship Staging table (_Relationship) in Staging (stg) Schema  
            IF COALESCE(@StagingRelationshipTable, N'') <> N'' BEGIN  
                SET @SQL =  N'    
                    CREATE TABLE [stg].' + quotename(@StagingRelationshipTable) + N'     
                    (     
                        --Identity    
                        ID                  INT IDENTITY (1, 1) NOT NULL,  
                          
                        --Import Specific  
                        RelationshipType    TINYINT NOT NULL,  
  
                        --Status    
                        ImportStatus_ID     TINYINT NOT NULL,  
                            
                        --Info  
                        Batch_ID            INT NULL,    
                        BatchTag            NVARCHAR(50) NULL,  
                        --Error Code  
                        ErrorCode           INT,  
                        HierarchyName       NVARCHAR(250) NOT NULL,  
                        ParentCode          NVARCHAR(250) NOT NULL,    
                        ChildCode           NVARCHAR(250) NOT NULL,      
                        SortOrder           INT,      
                                                                                          
                        --Create PRIMARY KEY constraint    
                        CONSTRAINT ' + quotename(N'pk_' + @StagingRelationshipTable) + N'     
                            PRIMARY KEY CLUSTERED (ID),    
                        
                        --Create CHECK constraints    
                        CONSTRAINT ' + quotename(N'ck_' + @StagingRelationshipTable + N'_RelationshipType') + N'     
                            CHECK (RelationshipType BETWEEN 1 AND 2),    
                        CONSTRAINT ' + quotename(N'ck_' + @StagingRelationshipTable + N'_ImportStatus_ID') + N'     
                            CHECK (ImportStatus_ID BETWEEN 0 and 3)                            
                    )    
                    ' + @Compress + N';  
                        
                    --Index [Batch_ID] for performance  
                    CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @StagingRelationshipTable + N'_Batch_ID') + N'   
                        ON [stg].' + quotename(@StagingRelationshipTable) + N'(Batch_ID)  
                        ' + @Compress + N';  
					--Index [BatchTag] for performance  
                    CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @StagingRelationshipTable + N'_BatchTag') + N'   
                        ON [stg].' + quotename(@StagingRelationshipTable) + N'(BatchTag)  
                        ' + @Compress + N';  
                    ';  
                       
                 --Execute the dynamic SQL             
        
                EXEC sp_executesql @SQL;  
                  
                EXEC mdm.udpEntityStagingCreateRelationshipStoredProcedure @Entity_ID;  
  
            END; --IF  
  
            --Create the Collection table (CN)  
            SET @SQL = N'  
                CREATE TABLE mdm.' + quotename(@CollectionTable) + N'   
                (  
                    --Identity  
                    Version_ID          INT NOT NULL,   
                    ID                  INT IDENTITY(1, 1) NOT NULL,                      
                    --Status  
                    Status_ID           TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @CollectionTable  + N'_Status_ID') + N' DEFAULT 1,  
                    ValidationStatus_ID TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @CollectionTable  + N'_ValidationStatus_ID') + N' DEFAULT 0,  
                      
                    --Data  
                    [Name]              NVARCHAR(250) NULL,  
                    Code                NVARCHAR(250) NOT NULL,  
                    [Description]       NVARCHAR(500) NULL,  
                    [Owner_ID]          INT NOT NULL,  
                      
                    --Auditing  
                    EnterDTM            DATETIME2(3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @CollectionTable  + N'_EnterDTM') + N' DEFAULT GETUTCDATE(),  
                    EnterUserID         INT NOT NULL,  
                    EnterVersionID      INT NOT NULL,  
                    LastChgDTM          DATETIME2(3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @CollectionTable  + N'_LastChgDTM') + N' DEFAULT GETUTCDATE(),  
                    LastChgUserID       INT NOT NULL,  
                    LastChgVersionID    INT NOT NULL,  
                    LastChgTS           ROWVERSION NOT NULL,  
                    AsOf_ID             INT NULL,  
                    MUID                UNIQUEIDENTIFIER NOT NULL CONSTRAINT ' + quotename(N'df_' + @CollectionTable + N'_MUID') + N' DEFAULT NEWID() ROWGUIDCOL,  
                                                              
                    --Create PRIMARY KEY constraint  
                    CONSTRAINT ' + quotename(N'pk_' + @CollectionTable + N'') + N'   
                        PRIMARY KEY CLUSTERED (Version_ID, ID),  
                                          
                    --Create FOREIGN KEY constraints  
                    CONSTRAINT ' + quotename(N'fk_' + @CollectionTable  + N'_tblModelVersion_Version_ID') + N'  
                        FOREIGN KEY (Version_ID) REFERENCES mdm.tblModelVersion(ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE NO ACTION,  
                    CONSTRAINT ' + quotename(N'fk_' + @CollectionTable  + N'_tblUser_Owner_ID') + N'  
                        FOREIGN KEY ([Owner_ID]) REFERENCES mdm.tblUser(ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE NO ACTION,  
                          
                    --Create CHECK constraints  
                    CONSTRAINT ' + quotename(N'ck_' + @CollectionTable + N'_Status_ID') + N'   
                        CHECK (Status_ID BETWEEN 1 AND 2),  
                    CONSTRAINT ' + quotename(N'ck_' + @CollectionTable + N'_ValidationStatus_ID') + N'   
                        CHECK (ValidationStatus_ID BETWEEN 0 and 5)  
                )  
                ' + @Compress + N';  
                ';  
  
            --Direct assignment of expression > 4000 nchars seems to truncate string. Workaround is to concatenate.  
            SET @SQL = @SQL + N'  
                --Ensure uniqueness of [Code]  
                CREATE UNIQUE NONCLUSTERED INDEX ' + quotename(N'ux_' + @CollectionTable  + N'_Version_ID_Code') + N'   
                    ON mdm.' + quotename(@CollectionTable) + N'(Version_ID, Code)  
                    ' + @Compress + N';  
  
                --Index [Name] for performance  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @CollectionTable + N'_Version_ID_Name') + N'   
                    ON mdm.' + quotename(@CollectionTable) + N'(Version_ID, Name)  
                    ' + @Compress + N';  
                      
                --Ensure uniqueness of [MUID]  
                CREATE UNIQUE NONCLUSTERED INDEX ' + quotename(N'ux_' + @CollectionTable + N'_MUID') + N'  
                    ON mdm.' + quotename(@CollectionTable) + N'(MUID)  
                    ' + @Compress + N';  
  
                --Required for VersionCopy operations  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @CollectionTable  + N'_Version_ID_AsOf_ID') + N'   
                    ON mdm.' + quotename(@CollectionTable) + N'(Version_ID, AsOf_ID)  
                    WHERE [AsOf_ID] IS NOT NULL  
                    ' + @Compress + N';  
                ';  
  
            --Execute the dynamic SQL  
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL;  
  
  
            --Create the Collection Member Table (CM)  
            SET @SQL = N'  
                CREATE TABLE mdm.' + quotename(@CollectionMemberTable) + N'   
                (   
                    --Identity  
                    Version_ID          INT NOT NULL,  
                    ID                  INT IDENTITY(1, 1) NOT NULL,                      
                                          
                    --Status  
                    Status_ID           TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @CollectionMemberTable  + N'_Status_ID') + N' DEFAULT 1,  
                      
                    --Pointers  
                    Parent_CN_ID        INT NOT NULL, --Always points to CN   
                    ChildType_ID        TINYINT NOT NULL,                      
                    Child_EN_ID         INT NULL, --Used when the child is of type EN (ChildType_ID = 1)  
                    Child_HP_ID         INT NULL, --Used when the child is of type HP (ChildType_ID = 2)  
                    Child_CN_ID         INT NULL, --Used when the child is of type CN (ChildType_ID = 3)  
                      
                    --Data  
                    SortOrder           INT NOT NULL,  
                    Weight              DECIMAL(10,3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @CollectionMemberTable  + N'_Weight') + N' DEFAULT 1.0,  
                      
                    --Auditing  
                    EnterDTM            DATETIME2(3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @CollectionMemberTable  + N'_EnterDTM') + N' DEFAULT GETUTCDATE(),  
                    EnterUserID         INT NOT NULL,  
                    EnterVersionID      INT NOT NULL,  
                    LastChgDTM          DATETIME2(3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @CollectionMemberTable  + N'_LastChgDTM') + N' DEFAULT GETUTCDATE(),  
                    LastChgUserID       INT NOT NULL,  
                    LastChgVersionID    INT NOT NULL,  
                    LastChgTS           ROWVERSION NOT NULL,  
                    AsOf_ID             INT NULL,                      
                    MUID                UNIQUEIDENTIFIER NOT NULL CONSTRAINT ' + quotename(N'df_' + @CollectionMemberTable + N'_MUID') + N' DEFAULT NEWID() ROWGUIDCOL,  
  
                    --Create PRIMARY KEY constraint  
                    CONSTRAINT ' + quotename(N'pk_' + @CollectionMemberTable + N'') + N'   
                        PRIMARY KEY NONCLUSTERED (Version_ID, ID)  
                        ' + @Compress + N',  
                                          
                    --Create FOREIGN KEY constraints      
                    CONSTRAINT ' + quotename(N'fk_' + @CollectionMemberTable + N'_tblModelVersion_Version_ID') + N'  
                        FOREIGN KEY (Version_ID) REFERENCES mdm.tblModelVersion(ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE NO ACTION,  
                    CONSTRAINT ' + quotename(N'fk_' + @CollectionMemberTable + N'_' + @CollectionTable + N'_Parent_CN_ID') + N'  
                        FOREIGN KEY (Version_ID, Parent_CN_ID) REFERENCES mdm.' + quotename(@CollectionTable) + N'(Version_ID, ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE CASCADE,  
                    CONSTRAINT ' + quotename(N'fk_' + @CollectionMemberTable + N'_' + @EntityTable + N'_Child_EN_ID') + N'  
                        FOREIGN KEY (Version_ID, Child_EN_ID) REFERENCES mdm.' + quotename(@EntityTable) + N'(Version_ID, ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE CASCADE,  
                    CONSTRAINT ' + quotename(N'fk_' + @CollectionMemberTable + N'_' + @HierarchyParentTable + N'_Child_HP_ID') + N'  
                        FOREIGN KEY (Version_ID, Child_HP_ID) REFERENCES mdm.' + quotename(@HierarchyParentTable) + N'(Version_ID, ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE CASCADE,  
                    CONSTRAINT ' + quotename(N'fk_' + @CollectionMemberTable + N'_' + @CollectionTable + N'_Child_CN_ID') + N'  
                        FOREIGN KEY (Version_ID, Child_CN_ID) REFERENCES mdm.' + quotename(@CollectionTable) + N'(Version_ID, ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE NO ACTION, --Cannot use CASCADE due to chance of cycles  
                      
                    --Create CHECK constraints  
                    CONSTRAINT ' + quotename(N'ck_' + @CollectionMemberTable + N'_Status_ID') + N'   
                        CHECK (Status_ID BETWEEN 1 AND 2),  
                    CONSTRAINT ' + quotename(N'ck_' + @CollectionMemberTable + N'_ChildType_ID') + N'  
                        CHECK (    (ChildType_ID = 1 AND Child_EN_ID IS NOT NULL AND Child_HP_ID IS NULL AND Child_CN_ID IS NULL) OR  
                                (ChildType_ID = 2 AND Child_HP_ID IS NOT NULL AND Child_EN_ID IS NULL AND Child_CN_ID IS NULL) OR  
                                (ChildType_ID = 3 AND Child_CN_ID IS NOT NULL AND Child_EN_ID IS NULL AND Child_HP_ID IS NULL)),  
                    CONSTRAINT ' + quotename(N'ck_' + @CollectionMemberTable + N'_Parent_CN_ID_Child_CN_ID') + N'  
                        CHECK (NOT (ChildType_ID = 3 AND Parent_CN_ID = Child_CN_ID)) --Prevent self-reference  
                )  
                ' + @Compress + N';  
                ';  
  
            --Direct assignment of expression > 4000 nchars seems to truncate string. Workaround is to concatenate.  
            SET @SQL = @SQL + N'  
                --Ensure uniqueness of keyset  
                CREATE UNIQUE CLUSTERED INDEX ' + quotename(N'ux_' + @CollectionMemberTable + N'_Version_ID_Parent_CN_ID_ChildType_ID_Child_CN_ID_Child_HP_ID_Child_EN_ID') + N'  
                    ON mdm.' + quotename(@CollectionMemberTable) + N'(Version_ID, Parent_CN_ID, ChildType_ID, Child_CN_ID, Child_HP_ID, Child_EN_ID)  
                    ' + @Compress + N';  
  
                --Required for foreign key join performance  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @CollectionMemberTable + N'_Version_ID_Parent_CN_ID') + N'  
                    ON mdm.' + quotename(@CollectionMemberTable) + N'(Version_ID, Parent_CN_ID)  
                    ' + @Compress + N';  
                    --No filter on this index since Parent_CN_ID is NOT NULL  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @CollectionMemberTable + N'_Version_ID_Child_EN_ID') + N'  
                    ON mdm.' + quotename(@CollectionMemberTable) + N'(Version_ID, Child_EN_ID)  
                    WHERE [Child_EN_ID] IS NOT NULL  
                    ' + @Compress + N';  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @CollectionMemberTable + N'_Version_ID_Child_HP_ID') + N'  
                    ON mdm.' + quotename(@CollectionMemberTable) + N'(Version_ID, Child_HP_ID)  
                    WHERE [Child_HP_ID] IS NOT NULL  
                    ' + @Compress + N';  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @CollectionMemberTable + N'_Version_ID_Child_CN_ID') + N'  
                    ON mdm.' + quotename(@CollectionMemberTable) + N'(Version_ID, Child_CN_ID)  
                    WHERE [Child_CN_ID] IS NOT NULL  
                    ' + @Compress + N';  
                  
                --Required for VersionCopy operations  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @CollectionMemberTable + N'_Version_ID_AsOf_ID') + N'   
                    ON mdm.' + quotename(@CollectionMemberTable) + N'(Version_ID, AsOf_ID)  
                    WHERE [AsOf_ID] IS NOT NULL  
                    ' + @Compress + N';  
                ';  
  
            --Execute the dynamic SQL  
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL;  
  
  
            --Associate the Member Security table (MS)  
            SET @SQL = N'  
                ALTER TABLE mdm.' + quotename(@SecurityTable) + N' ADD   
                    CONSTRAINT ' + quotename(N'fk_' + @SecurityTable + N'_' + @HierarchyParentTable + N'_Version_ID_HP_ID') + N'  
                    FOREIGN KEY (Version_ID, HP_ID) REFERENCES mdm.' + @HierarchyParentTable + N'(Version_ID, ID)  
                    ON UPDATE NO ACTION   
                    ON DELETE CASCADE;';  
                      
            --Execute the dynamic SQL  
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL;  
              
            --Document the columns we have just physically created:  
  
            --HierarchyParent (HP)  
            INSERT INTO mdm.tblAttribute (Entity_ID,SortOrder,DomainEntity_ID,AttributeType_ID,MemberType_ID,IsSystem,IsReadOnly,IsCode,IsName,[Name],DisplayName,TableColumn,DisplayWidth,DataType_ID,DataTypeInformation,InputMask_ID,EnterUserID,EnterVersionID,LastChgUserID,LastChgVersionID)  
            VALUES  
             (@Entity_ID,1,NULL,3,2,1,1,0,0,N'ID',N'ID',N'ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,2,NULL,3,2,1,1,0,0,N'Version_ID',N'Version_ID',N'Version_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,4,NULL,3,2,1,1,0,0,N'Status_ID',N'Status_ID',N'Status_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,5,NULL,3,2,1,1,0,0,N'ValidationStatus_ID',N'ValidationStatus_ID',N'ValidationStatus_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,6,NULL,3,2,1,1,0,0,N'EnterDTM',N'EnterDTM',N'EnterDTM',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,7,NULL,3,2,1,1,0,0,N'EnterUserID',N'EnterUserID',N'EnterUserID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,8,NULL,3,2,1,1,0,0,N'EnterVersionID',N'EnterVersionID',N'EnterVersionID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,9,NULL,3,2,1,1,0,0,N'LastChgDTM',N'LastChgDTM',N'LastChgDTM',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,10,NULL,3,2,1,1,0,0,N'LastChgUserID',N'LastChgUserID',N'LastChgUserID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,11,NULL,3,2,1,1,0,0,N'LastChgVersionID',N'LastChgVersionID',N'LastChgVersionID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,12,NULL,3,2,1,1,0,0,N'LastChgTS',N'LastChgTS',N'LastChgTS',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,13,NULL,3,2,1,1,0,0,N'Hierarchy_ID',N'Hierarchy_ID',N'Hierarchy_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)      
            ,(@Entity_ID,14,NULL,1,2,1,0,0,1,N'Name',N'Name',N'Name',250,1,250,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,15,NULL,1,2,1,0,1,0,N'Code',N'Code',N'Code',250,1,250,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,16,NULL,3,2,1,1,0,0,N'MUID',N'MUID',N'MUID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,17,NULL,3,2,1,1,0,0,N'AsOf_ID',N'AsOf_ID',N'AsOf_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,18,NULL,3,2,1,0,0,0,N'ChangeTrackingMask',N'ChangeTrackingMask',N'ChangeTrackingMask',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ;  
  
            --Hierarchy (HR)  
            INSERT INTO mdm.tblAttribute (Entity_ID,SortOrder,DomainEntity_ID,AttributeType_ID,MemberType_ID,IsSystem,IsReadOnly,[Name],DisplayName,TableColumn,DisplayWidth,DataType_ID,DataTypeInformation,InputMask_ID,EnterUserID,EnterVersionID,LastChgUserID,LastChgVersionID)  
            VALUES  
             (@Entity_ID, 1,NULL,3,4,1,1,N'ID',N'ID',N'ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 2,NULL,3,4,1,1,N'Version_ID',N'Version_ID',N'Version_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 3,NULL,3,4,1,1,N'Status_ID',N'Status_ID',N'Status_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 4,NULL,3,4,1,1,N'ValidationStatus_ID',N'ValidationStatus_ID',N'ValidationStatus_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 5,NULL,3,4,1,1,N'EnterDTM',N'EnterDTM',N'EnterDTM',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 6,NULL,3,4,1,1,N'EnterUserID',N'EnterUserID',N'EnterUserID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 7,NULL,3,4,1,1,N'EnterVersionID',N'EnterVersionID',N'EnterVersionID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 8,NULL,3,4,1,1,N'LastChgDTM',N'LastChgDTM',N'LastChgDTM',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 9,NULL,3,4,1,1,N'LastChgUserID',N'LastChgUserID',N'LastChgUserID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 10,NULL,3,4,1,1,N'LastChgVersionID',N'LastChgVersionID',N'LastChgVersionID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 11,NULL,3,4,1,1,N'LastChgTS',N'LastChgTS',N'LastChgTS',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 12,NULL,3,4,1,1,N'Hierarchy_ID',N'Hierarchy_ID',N'Hierarchy_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 13,NULL,3,4,1,1,N'Parent_HP_ID',N'Parent_HP_ID',N'Parent_HP_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 14,NULL,3,4,1,1,N'Child_EN_ID',N'Child_EN_ID',N'Child_EN_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 15,NULL,3,4,1,1,N'Child_HP_ID',N'Child_HP_ID',N'Child_HP_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 16,NULL,3,4,1,1,N'ChildType_ID',N'ChildType_ID',N'ChildType_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 17,NULL,3,4,1,1,N'SortOrder',N'SortOrder',N'SortOrder',0,1,NULL,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 18,NULL,1,4,1,1,N'LevelNumber',N'LevelNumber',N'LevelNumber',0,2,NULL,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 20,NULL,3,4,1,1,N'MUID',N'MUID',N'MUID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 21,NULL,3,4,1,1,N'AsOf_ID',N'AsOf_ID',N'AsOf_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ;  
  
            --Collection (CN)  
            INSERT INTO mdm.tblAttribute (Entity_ID,SortOrder,DomainEntity_ID,AttributeType_ID,MemberType_ID,IsSystem,IsReadOnly,IsCode,IsName,[Name],DisplayName,TableColumn,DisplayWidth,DataType_ID,DataTypeInformation,InputMask_ID,EnterUserID,EnterVersionID,LastChgUserID,LastChgVersionID)  
            VALUES  
             (@Entity_ID,1,NULL,3,3,1,1,0,0,N'ID',N'ID',N'ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,2,NULL,3,3,1,1,0,0,N'Version_ID',N'Version_ID',N'Version_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,4,NULL,3,3,1,1,0,0,N'Status_ID',N'Status_ID',N'Status_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,5,NULL,3,3,1,1,0,0,N'ValidationStatus_ID',N'ValidationStatus_ID',N'ValidationStatus_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,6,NULL,3,3,1,1,0,0,N'EnterDTM',N'EnterDTM',N'EnterDTM',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,7,NULL,3,3,1,1,0,0,N'EnterUserID',N'EnterUserID',N'EnterUserID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,8,NULL,3,3,1,1,0,0,N'EnterVersionID',N'EnterVersionID',N'EnterVersionID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,9,NULL,3,3,1,1,0,0,N'LastChgDTM',N'LastChgDTM',N'LastChgDTM',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,10,NULL,3,3,1,1,0,0,N'LastChgUserID',N'LastChgUserID',N'LastChgUserID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,11,NULL,3,3,1,1,0,0,N'LastChgVersionID',N'LastChgVersionID',N'LastChgVersionID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,12,NULL,3,3,1,1,0,0,N'LastChgTS',N'LastChgTS',N'LastChgTS',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,13,NULL,1,3,1,0,0,1,N'Name',N'Name',N'Name',250,1,250,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,14,NULL,1,3,1,0,1,0,N'Code',N'Code',N'Code',250,1,250,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,15,NULL,1,3,1,0,0,0,N'Description',N'Description',N'Description',225,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,16,NULL,1,3,1,0,0,0,N'Owner_ID',N'Owner_ID',N'Owner_ID',100,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,17,NULL,3,3,1,1,0,0,N'MUID',N'MUID',N'MUID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID,18,NULL,3,3,1,1,0,0,N'AsOf_ID',N'AsOf_ID',N'AsOf_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ;  
  
            --CollectionMember (CM)  
            INSERT INTO mdm.tblAttribute (Entity_ID,SortOrder,DomainEntity_ID,AttributeType_ID,MemberType_ID,IsSystem,IsReadOnly,[Name],DisplayName,TableColumn,DisplayWidth,DataType_ID,DataTypeInformation,InputMask_ID,EnterUserID,EnterVersionID,LastChgUserID,LastChgVersionID)  
            VALUES  
             (@Entity_ID, 1,NULL,3,5,1,1,N'ID',N'ID',N'ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 2,NULL,3,5,1,1,N'Version_ID',N'Version_ID',N'Version_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 3,NULL,3,5,1,1,N'Status_ID',N'Status_ID',N'Status_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 5,NULL,3,5,1,1,N'EnterDTM',N'EnterDTM',N'EnterDTM',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 6,NULL,3,5,1,1,N'EnterUserID',N'EnterUserID',N'EnterUserID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 7,NULL,3,5,1,1,N'EnterVersionID',N'EnterVersionID',N'EnterVersionID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 8,NULL,3,5,1,1,N'LastChgDTM',N'LastChgDTM',N'LastChgDTM',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 9,NULL,3,5,1,1,N'LastChgUserID',N'LastChgUserID',N'LastChgUserID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 10,NULL,3,5,1,1,N'LastChgVersionID',N'LastChgVersionID',N'LastChgVersionID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 11,NULL,3,5,1,1,N'LastChgTS',N'LastChgTS',N'LastChgTS',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 13, NULL,3,5,1,1,N'Parent_CN_ID',N'Parent_CN_ID',N'Parent_CN_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 14, NULL,3,5,1,1,N'Child_EN_ID',N'Child_EN_ID',N'Child_EN_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 15, NULL,3,5,1,1,N'Child_HP_ID',N'Child_HP_ID',N'Child_HP_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 16, NULL,3,5,1,1,N'Child_CN_ID',N'Child_CN_ID',N'Child_CN_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 17, NULL,3,5,1,1,N'ChildType_ID',N'ChildType_ID',N'ChildType_ID',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 18, NULL,3,5,1,1,N'SortOrder',N'SortOrder',N'SortOrder',0,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 19, NULL,1,5,1,0,N'Weight',N'Weight',N'Weight',50,1,100,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 20,NULL,3,5,1,1,N'MUID',N'MUID',N'MUID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 21,NULL,3,5,1,1,N'AsOf_ID',N'AsOf_ID',N'AsOf_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ;  
  
        END; --if  
  
        SELECT @HierarchyTable = HierarchyTable FROM mdm.tblEntity WHERE ID = @Entity_ID;  
          
        --Update/Insert Hierarchy details  
        IF @Hierarchy_ID IS NOT NULL BEGIN --Update Hierarchy  
          
            --Update details in Hierarchy table  
            UPDATE mdm.tblHierarchy SET  
                [Name] = ISNULL(@HierarchyName, [Name]),  
                IsMandatory = ISNULL(@IsMandatory, IsMandatory),  
                LastChgDTM = @CurrentDTM,  
                LastChgUserID = @User_ID,  
                LastChgVersionID = @Version_ID  
            WHERE  
                ID = @Hierarchy_ID;  
  
            --Populate output parameters  
            SELECT @Return_MUID = MUID FROM mdm.tblHierarchy WHERE ID = @Hierarchy_ID;  
  
            --Add all leaf nodes if mandatory  
            IF @IsMandatory = 1 BEGIN  
  
                SET @SQL = N'  
                DECLARE @TempTable TABLE (ID INT NOT NULL, Version_ID INT NOT NULL);  
                DECLARE @TempID AS INT, @Version_ID AS INT;  
  
                INSERT INTO @TempTable (ID, Version_ID)  
                SELECT   
                    ID,  
                    Version_ID  
                FROM  
                    mdm.' + quotename(@EntityTable) + N' AS EN                      
                WHERE  
                    EN.Status_ID = 1 AND  
                    EN.ID NOT IN  
                    (  
                        SELECT Child_EN_ID   
                        FROM mdm.' + quotename(@HierarchyTable) + N' AS HR   
                        WHERE    
                            HR.ChildType_ID = 1 AND  
                            HR.Status_ID = 1 AND   
                            HR.Hierarchy_ID = @Hierarchy_ID  
                    )  
                 ORDER BY ID ASC;  
  
                WHILE EXISTS(SELECT 1 FROM @TempTable) BEGIN  
                  
                    SELECT TOP 1 @TempID = ID, @Version_ID = Version_ID FROM @TempTable  ORDER BY ID;  
                                   
                    EXEC mdm.udpHierarchyCreate @User_ID, @Version_ID, @Entity_ID, @Hierarchy_ID, 0, @TempID, 1;  
                                
                    DELETE FROM @TempTable WHERE ID = @TempID AND Version_ID = @Version_ID;  
                  
                END; --while';  
  
                --Execute the dynamic SQL  
                --PRINT(@SQL):  
                EXEC sp_executesql @SQL,   
                N'@User_ID INT, @Entity_ID INT, @Hierarchy_ID INT',   
                @User_ID, @Entity_ID, @Hierarchy_ID;  
  
            END; --if  
  
        END ELSE BEGIN --New Hierarchy  
  
            -- Validate @Name  
            IF NULLIF(@HierarchyName, N'') IS NULL BEGIN  
                RAISERROR('MDSERR100003|The Name is not valid.', 16, 1);  
                RETURN;    
            END;  
  
            --Accept an explicit MUID (for clone operations) or generate a new one  
            SET @Return_MUID = ISNULL(@Return_MUID, NEWID());  
                
            --Insert details into Hierarchy table  
            INSERT INTO mdm.tblHierarchy  
            (  
                 Entity_ID  
                ,[Name]  
                ,IsMandatory  
                ,MUID  
                ,EnterDTM  
                ,EnterUserID  
                ,EnterVersionID  
                ,LastChgDTM  
                ,LastChgUserID  
                ,LastChgVersionID  
            )   
            VALUES   
            (  
                @Entity_ID,  
                @HierarchyName,  
                @IsMandatory,  
                @Return_MUID,  
                @CurrentDTM,  
                @User_ID,  
                @Version_ID,  
                @CurrentDTM,  
                @User_ID,  
                @Version_ID  
            );  
               
            --Save the identity value  
            SET @Hierarchy_ID = SCOPE_IDENTITY();  
  
            /*  
            Copy all the members into the hierarchy if it is a mandatory hierarchy (in case the entity was created   
            without a Hierarchy and then one was added) or another Hierarchy was just added.  
            */  
            IF @IsMandatory = 1 BEGIN  
  
                SELECT @SQL = N'  
                INSERT INTO mdm.' + quotename(@HierarchyTable) + N'   
                (  
                    Version_ID,  
                    Status_ID,  
                    ValidationStatus_ID,  
                    Hierarchy_ID,  
                    Parent_HP_ID,  
                    ChildType_ID,                      
                    Child_EN_ID,  
                    SortOrder,  
                    EnterUserID,  
                    EnterVersionID,  
                    LastChgUserID,  
                    LastChgVersionID  
                )  
                SELECT  
                    E.Version_ID,  
                    1,  
                    0,  
                    @Hierarchy_ID,  
                    NULL,    --Parent_HP_ID  
                    1,       --ChildType_ID = EN                      
                    E.ID,    --Child_EN_ID  
                    E.ID,    --SortOrder  
                    @User_ID,  
                    @Version_ID,  
                    @User_ID,  
                    @Version_ID  
                FROM mdm.' + quotename(@EntityTable) + N' AS E   
                INNER JOIN mdm.tblModelVersion AS V   
                    ON E.Version_ID = V.ID   
                WHERE V.Status_ID <> 3;';  
  
                --Execute the dynamic SQL  
                --PRINT(@SQL);  
                EXEC sp_executesql @SQL,   
                    N'@User_ID INT, @Version_ID INT, @Hierarchy_ID INT',   
                    @User_ID, @Version_ID, @Hierarchy_ID;  
  
            END; --if  
  
             --Create related metadata member  
            DECLARE @HierarchyMetadataCode NVARCHAR(200) -- We will build out hierarchy metadata codes as entityid_E_hierarchyId to ensure uniqueness  
            DECLARE @IsSystemEntity INT   
              
            SET @HierarchyMetadataCode = CONVERT(NVARCHAR(20), @Entity_ID) + N'_E_' + CONVERT(NVARCHAR(20), @Hierarchy_ID);  
            -- Set IsSystemModel that indicates if the Model is a Metadata Model.  
            SELECT @IsSystemEntity = IsSystem FROM mdm.tblEntity WHERE ID=@Entity_ID;  
  
            IF (@IsSystemEntity = 0)   
                EXEC mdm.udpUserDefinedMetadataSave N'Hierarchy', @Return_MUID, @HierarchyName, @HierarchyMetadataCode, @User_ID;  
          
        END; --if  
  
        --Recreate the views  
        EXEC mdm.udpCreateViews @Model_ID = @Model_ID;  
        EXEC mdm.udpCreateEntityStagingErrorDetailViews @Entity_ID = @Entity_ID;  
          
        --Recreate leaf staging SProc when HP and CM tables are added.    
        EXEC mdm.udpEntityStagingCreateLeafStoredProcedure @Entity_ID;  
      
        --Return values  
        SET @Return_ID = @Hierarchy_ID;  
         
        --Commit only if we are not nested  
        IF @TranCounter = 0 COMMIT TRANSACTION;  
        RETURN(0);  
  
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
  
        IF @TranCounter = 0 ROLLBACK TRANSACTION;  
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
