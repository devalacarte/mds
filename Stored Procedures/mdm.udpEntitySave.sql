SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    --Create new Entity  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpEntitySave 1, NULL, 2, 'Test11', 0, 0, N'', NULL, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblEntity WHERE ID = @Return_ID;  
  
    --Create new Entity with code gen turned ON  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpEntitySave 1, NULL, 2, 'Test11', 0, 0, N'', 100, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblEntity WHERE ID = @Return_ID;  
  
    --Update existing Entity  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpEntitySave 1, 42, 2, 'TST7', 0, 0, N'', 100, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblEntity WHERE ID = @Return_ID;  
  
    --Invalid parameters  
    EXEC mdm.udpEntitySave 99999, 1, 1, 'TST7';  
    EXEC mdm.udpEntitySave 99999, 1, 1, 'TST7';  
    EXEC mdm.udpEntitySave 1, 99999, 1, 'Test5';  
*/  
CREATE PROCEDURE [mdm].[udpEntitySave]  
(  
    @User_ID        INT,  
    @Entity_ID      INT = NULL,  
    @Model_ID       INT,  
    @EntityName     NVARCHAR(50),  
    @IsSystem       BIT = 0,  
    @StagingBase    NVARCHAR(60) = N'',  
    @CodeGenSeed    INT = NULL,  
    @Return_ID      INT = NULL OUTPUT,  
    @Return_MUID    UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @SQL                        NVARCHAR(MAX),  
            @Version_ID                 INT,  
            @CurrentDTM                 DATETIME2(3),  
            @EntityTable                sysname,  
            @SecurityTable              sysname,  
            @StagingTable               sysname,   
            @Compress                   NVARCHAR(MAX) = N'',  
            @NewEntity                  INT, -- 0: update, 1: new entity  
            @TranCommitted              INT = 0, -- 0: Not committed, 1: Committed.  
            @IsFlat                     BIT,  
  
            -- This pseudo-constant is for use in string concatenation operations to prevent string truncation. When concatenating two or more strings,  
            -- if none of the strings is an NVARCHAR(MAX) or an NVARCHAR constant that is longer than 4,000 characters, then the resulting string   
            -- will be silently truncated to 4,000 characters. Concatenating with this empty NVARCHAR(MAX), is sufficient to prevent truncation.  
            -- See http://connect.microsoft.com/SQLServer/feedback/details/283368/nvarchar-max-concatenation-yields-silent-truncation.  
            @TruncationGuard            NVARCHAR(MAX) = N'',  
                                      
            @LeafSproc                  sysname,  
            @ConsolidatedSproc          sysname,  
            @RelationshipSproc          sysname,  
            @RelationshipStagingTable   sysname,  
            @LeafStagingTable           sysname,  
            @ConsolidatedStagingTable   sysname,     
            @MemberErrorViewName        sysname,    
            @RelationErrorViewName      sysname,    
            @CurrentStagingBase         NVARCHAR(60) = N'';  
              
    --Initialize output parameters and local variables  
           
    SELECT   
        @EntityName = NULLIF(LTRIM(RTRIM(@EntityName)), N''),   
        @Return_ID = NULL,   
        @CurrentDTM = GETUTCDATE();  
  
    --Get the latest Model Version  
    SELECT @Version_ID = MAX(v.ID)  
    FROM mdm.tblModel AS m   
    INNER JOIN mdm.tblModelVersion AS v ON (m.ID = v.Model_ID)  
    WHERE m.ID = @Model_ID;  
  
    --Test for invalid parameters  
    IF (@Version_ID IS NULL) --Invalid @Version_ID (via invalid @Model_ID)  
        OR (@Entity_ID IS NULL AND @EntityName IS NULL) --@EntityName cannot be NULL for inserts  
        OR (@Entity_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblEntity WHERE Model_ID = @Model_ID AND ID = @Entity_ID)) --Invalid @Entity_ID (or wrong @Model_ID)  
        OR NOT EXISTS(SELECT ID FROM mdm.tblUser WHERE ID = @User_ID) --Invalid @User_ID  
    BEGIN  
        SELECT @Entity_ID = NULL, @Return_MUID = NULL, @EntityName = NULL;  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
  
    DECLARE @EntityNameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @EntityName, @EntityNameHasReservedCharacters OUTPUT;  
    IF @EntityNameHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100048|The entity cannot be created because the entity name contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    DECLARE @StagingBaseHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @StagingBase, @StagingBaseHasReservedCharacters OUTPUT;  
    IF @StagingBaseHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100049|The entity cannot be created because the name of the staging tables contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
              
        -- Replace spaces with underscores since spaces are not allowed.  
        SET @StagingBase = REPLACE(LTRIM(RTRIM(@StagingBase)), N' ', N'_');      
                      
        --Update/Insert Entity details  
        IF @Entity_ID IS NOT NULL   
        BEGIN --Update Entity  
              
            SET @NewEntity = 0;   
              
            --Don't bother doing anything if the @EntityName is NULL  
            IF @EntityName IS NOT NULL BEGIN  
              
                --Update details in Entity table  
                UPDATE mdm.tblEntity SET  
                    [Name] = @EntityName,   
                    LastChgDTM = @CurrentDTM,  
                    LastChgUserID = @User_ID,  
                    LastChgVersionID = @Version_ID  
                WHERE  
                    ID = @Entity_ID;  
  
                DECLARE @CodeGenEnabled BIT = 0;  
                EXEC @CodeGenEnabled = mdm.udpIsCodeGenEnabled @Entity_ID;  
  
                --If the user did not send in a code gen seed we might need to turn code gen off  
                IF @CodeGenSeed IS NULL  
                    BEGIN  
                        --If code gen is enabled on this entity turn it off  
                        IF @CodeGenEnabled = 1  
                            BEGIN  
                                DELETE FROM mdm.tblCodeGenInfo   
                                WHERE EntityId = @Entity_ID;  
                            END  
                    END  
                ELSE  
                    BEGIN  
                        --If code gen is already enabled on this entity just update the seed  
                        IF @CodeGenEnabled = 1  
                            BEGIN  
                                UPDATE mdm.tblCodeGenInfo  
                                SET Seed = @CodeGenSeed  
                                WHERE EntityId = @Entity_ID;  
                            END  
                        --If code gen needs to be enabled  
                        ELSE  
                            BEGIN  
                                --Turn it on  
                                DECLARE @ExistingMaxValue BIGINT = NULL;  
                                EXEC @ExistingMaxValue = mdm.udpGetMaxCodeValue @Entity_ID = @Entity_ID;  
                                INSERT INTO mdm.tblCodeGenInfo (EntityId, Seed, LargestCodeValue)  
                                VALUES (@Entity_ID, @CodeGenSeed, @ExistingMaxValue);  
                            END  
                    END  
                      
                --If StagingBase is specified, check if it is changed.  
                IF COALESCE(@StagingBase, N'') <> N'' BEGIN                      
                    SELECT  
                        @IsFlat = IsFlat,         
                        @LeafSproc = N'[stg].' + QUOTENAME(N'udp_' + StagingBase + N'_Leaf'),   
                        @ConsolidatedSproc = N'[stg].' + QUOTENAME(N'udp_' + StagingBase + N'_Consolidated'),  
                        @RelationshipSproc = N'[stg].' + QUOTENAME(N'udp_' + StagingBase + N'_Relationship'),    
                        @LeafStagingTable = N'[stg].' + QUOTENAME(StagingBase + N'_Leaf'),     
                        @ConsolidatedStagingTable = N'[stg].' + QUOTENAME(StagingBase + N'_Consolidated'),  
                        @RelationshipStagingTable = N'[stg].' + QUOTENAME(StagingBase + N'_Relationship'),    
                        @MemberErrorViewName = N'[stg].' + QUOTENAME(N'viw_' + StagingBase + N'_MemberErrorDetails'),    
                        @RelationErrorViewName = N'[stg].' + QUOTENAME(N'viw_' + StagingBase + N'_RelationshipErrorDetails'),    
                        @CurrentStagingBase = StagingBase  
                    FROM     
                        mdm.tblEntity WHERE ID = @Entity_ID;  
                      
                    -- When the entity is a system entity @CurrentStagingBase is NULL.   
                    -- In this case the user cannot change the StagingBase.                                                                                      
                    IF COALESCE(@CurrentStagingBase, N'') <> N'' AND @CurrentStagingBase <> @StagingBase   
                    BEGIN  
                        --If the specified StagingBase is not unique, get the unique name from the first 50 characters of @StagingBase.  
                        IF EXISTS (SELECT 1 FROM mdm.tblEntity WHERE StagingBase = @StagingBase) BEGIN  
                            SELECT @StagingBase = mdm.udfUniqueStagingBaseGet(LEFT(@StagingBase, 50))  
                        END; --IF  
                          
                        -- Update StagingBase  
                        UPDATE mdm.tblEntity SET  
                        StagingBase = @StagingBase   
                        WHERE  
                        ID = @Entity_ID;  
                          
                        -- Update staging table names and staging stored procedure names.  
                                                      
                        SET @SQL += @TruncationGuard + N'   
                        -- Change leaf staging table name.      
                        IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @LeafStagingTable + N''') AND type = (N''U''))    
                        EXEC sp_rename N''' + @LeafStagingTable + N''',N''[stg].' + QUOTENAME(@StagingBase + N'_Leaf') + N'''  
                          
                        -- Change leaf staging stored procedure name.  
                        IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @LeafSproc + N''') AND type in (N''P'', N''PC''))  
                        EXEC sp_rename N''' + @LeafSproc + N''',N''[stg].' + QUOTENAME(N'udp_' + @StagingBase + N'_Leaf') + N'''  
                          
                        -- Change staging view name  
                        IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @MemberErrorViewName + N''') AND type in (N''V''))  
                        EXEC sp_rename N''' + @MemberErrorViewName + N''',N''[stg].' + QUOTENAME(N'viw_' + @StagingBase + N'_MemberErrorDetails') + N''''  
   
                        IF (@IsFlat = 0) BEGIN  
                            SET @SQL += @TruncationGuard + N'  
                            -- Change consolidated staging table name.     
                            IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N''' + @ConsolidatedStagingTable + N''') AND type = (N''U''))  
                            EXEC sp_rename N''' + @ConsolidatedStagingTable + N''',N''[stg].' + QUOTENAME(@StagingBase + N'_Consolidated') + N'''  
                              
                            IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N''' + @RelationshipStagingTable + N''') AND type = (N''U''))  
                            EXEC sp_rename N''' + @RelationshipStagingTable + N''',N''[stg].' + QUOTENAME(@StagingBase + N'_Relationship') + N'''  
  
                            -- Change consolidated staging stored procedure name.    
                            IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @ConsolidatedSproc + N''') AND type in (N''P'', N''PC''))  
                            EXEC sp_rename N''' + @ConsolidatedSproc + N''',N''[stg].' + QUOTENAME(N'udp_' + @StagingBase + N'_Consolidated') + N'''  
                              
                            IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @RelationshipSproc + N''') AND type in (N''P'', N''PC''))  
                            EXEC sp_rename N''' + @RelationshipSproc + N''',N''[stg].' + QUOTENAME(N'udp_' + @StagingBase + N'_Relationship') + N'''  
                              
                            IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @RelationErrorViewName + N''') AND type = N''V'')  
                            EXEC sp_rename N''' + @RelationErrorViewName + N''',N''[stg].' + QUOTENAME(N'viw_' + @StagingBase + N'_RelationshipErrorDetails') + N''''  
   
                        END; --IF       
                          
                        EXEC sp_executesql @SQL;                        
                    END; --IF  
                END; --IF   
            END; --if  
              
            --Populate output parameters  
            SELECT @Return_MUID = MUID FROM mdm.tblEntity WHERE ID = @Entity_ID;  
  
        END   
        ELSE   
        BEGIN --New Entity  
              
            SET @NewEntity = 1;  
              
            --Accept an explicit MUID (for clone operations) or generate a new one  
            SET @Return_MUID = ISNULL(@Return_MUID, NEWID());  
              
            IF @IsSystem = 1 BEGIN  
                SET @StagingBase = NULL; -- When the entity is a system entity set NULL to StagingBase.  
            END  
            ELSE BEGIN  
                --If the StagingBase is not specified, get the unique name.  
                IF COALESCE(@StagingBase, N'') = N'' BEGIN  
                    -- Replace spaces with underscores since spaces are not allowed.  
                    SET @StagingBase = REPLACE(@EntityName, N' ', N'_');      
                    SELECT @StagingBase = mdm.udfUniqueStagingBaseGet(@StagingBase)  
                END  
                ELSE BEGIN                  
                    --If the specified StagingBase is not unique, get the unique name from the first 50 characters of @StagingBase.  
                    IF EXISTS (SELECT 1 FROM mdm.tblEntity WHERE StagingBase = @StagingBase) BEGIN  
                        SELECT @StagingBase = mdm.udfUniqueStagingBaseGet(LEFT(@StagingBase, 50))  
                    END --IF  
                END --IF   
                  
                SET @StagingTable = @StagingBase + N'_Leaf';                        
            END;--IF  
                          
            --Insert details into Entity table  
            INSERT INTO mdm.tblEntity  
            (  
                Model_ID,   
                [Name],  
                EntityTable,  
                SecurityTable,  
                IsBase,   
                IsFlat,  
                IsSystem,  
                MUID,  
                EnterDTM,  
                EnterUserID,  
                EnterVersionID,  
                LastChgDTM,  
                LastChgUserID,  
                LastChgVersionID,  
                StagingBase    
            ) VALUES (  
                @Model_ID,   
                @EntityName,  
                NEWID(), --Temporary TableName values which we will update in the next step  
                NEWID(),  
                0, --IsBase  
                1, --Entities are always flat when we first create them  
                @IsSystem,  
                @Return_MUID,  
                @CurrentDTM,  
                @User_ID,  
                @Version_ID,  
                @CurrentDTM,  
                @User_ID,  
                @Version_ID,  
                @StagingBase   
            );              
  
            --Save the identity value  
            SET @Entity_ID =  SCOPE_IDENTITY();  
  
            --If the user provided a seed value then we need to turn on code gen  
            IF @CodeGenSeed IS NOT NULL  
                BEGIN  
                    --Insert a row into the code gen info table to track numeric codes  
                    INSERT INTO mdm.tblCodeGenInfo  
                    (  
                        EntityId,  
                        Seed  
                    )  
                    VALUES  
                    (  
                        @Entity_ID,  
                        @CodeGenSeed  
                    );  
                END;  
  
            --Generate table names  
            WITH cte(prefix) AS (SELECT N'tbl_' + CONVERT(sysname, @Model_ID) + N'_' + CONVERT(sysname, @Entity_ID))  
            SELECT  
                @EntityTable = prefix + N'_EN',  
                @SecurityTable = prefix + N'_MS'  
            FROM cte;  
              
            --Store table names  
            UPDATE mdm.tblEntity SET  
                EntityTable = @EntityTable,   
                SecurityTable = @SecurityTable  
            WHERE ID = @Entity_ID;  
  
            --Create the Entity (EN) table  
            SET @SQL = @TruncationGuard + N'  
                CREATE TABLE mdm.' + quotename(@EntityTable) + N'  
                (  
                    --Identity  
                    Version_ID          INT NOT NULL,  
                    ID                  INT IDENTITY (1, 1) NOT NULL,  
  
                    --Status  
                    Status_ID           TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @EntityTable + N'_Status_ID') + N' DEFAULT 1,  
                    ValidationStatus_ID TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @EntityTable  + N'_ValidationStatus_ID') + N' DEFAULT 0,  
                      
                    --Info  
                    [Name]              NVARCHAR(250) NULL,  
                    Code                NVARCHAR(250) NOT NULL,  
                      
                    --Change Tracking                      
                    ChangeTrackingMask  INT NOT NULL CONSTRAINT ' + quotename(N'df_' + @EntityTable  + N'_ChangeTrackingMask') + N' DEFAULT 0,  
                      
                    --Auditing  
                    EnterDTM            DATETIME2(3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @EntityTable  + N'_EnterDTM') + N' DEFAULT GETUTCDATE(),  
                    EnterUserID         INT NOT NULL,  
                    EnterVersionID      INT NOT NULL,  
                    LastChgDTM          DATETIME2(3) NOT NULL CONSTRAINT ' + quotename(N'df_' + @EntityTable  + N'_LastChgDTM') + N' DEFAULT GETUTCDATE(),  
                    LastChgUserID       INT NOT NULL,  
                    LastChgVersionID    INT NOT NULL,  
                    LastChgTS           ROWVERSION NOT NULL,  
                    AsOf_ID             INT NULL,  
                    MUID                UNIQUEIDENTIFIER NOT NULL CONSTRAINT ' + quotename(N'df_' + @EntityTable + N'_MUID') + N' DEFAULT NEWID() ROWGUIDCOL,  
                                                              
                    --Create PRIMARY KEY constraint  
                    CONSTRAINT ' + quotename(N'pk_' + @EntityTable) + N'   
                        PRIMARY KEY CLUSTERED (Version_ID, ID),  
  
                    --Create FOREIGN KEY contraints  
                    CONSTRAINT ' + quotename(N'fk_' + @EntityTable + N'_tblModelVersion_Version_ID') + N'  
                        FOREIGN KEY (Version_ID) REFERENCES mdm.tblModelVersion(ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE NO ACTION,  
                  
                    --Create CHECK constraints  
                    CONSTRAINT ' + quotename(N'ck_' + @EntityTable + N'_Status_ID') + N'   
                        CHECK (Status_ID BETWEEN 1 AND 2),  
                    CONSTRAINT ' + quotename(N'ck_' + @EntityTable + N'_ValidationStatus_ID') + N'   
                        CHECK (ValidationStatus_ID BETWEEN 0 and 5)  
                )  
                ' + @Compress + N'  
  
                --Ensure uniqueness of [Code]  
                CREATE UNIQUE NONCLUSTERED INDEX ' + quotename(N'ux_' + @EntityTable + N'_Version_ID_Code') + N'   
                    ON mdm.' + quotename(@EntityTable) + N'(Version_ID, Code)  
                    ' + @Compress + N';  
                      
                --Index [Name] for performance  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @EntityTable + N'_Version_ID_Name') + N'   
                    ON mdm.' + quotename(@EntityTable) + N'(Version_ID, Name)  
                    ' + @Compress + N';  
  
                --Index [LastChgDTM] for performance  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @EntityTable + N'_Version_ID_LastChgDTM') + N'   
                    ON mdm.' + quotename(@EntityTable) + N'(Version_ID, LastChgDTM)  
                    ' + @Compress + N';  
  
                --Ensure uniqueness of [MUID]  
                CREATE UNIQUE NONCLUSTERED INDEX ' + quotename(N'ux_' + @EntityTable + N'_MUID') + N'  
                    ON mdm.' + quotename(@EntityTable) + N'(MUID)  
                    ' + @Compress + N';  
  
                --Required for VersionCopy operations  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @EntityTable + N'_Version_ID_AsOf_ID') + N'   
                    ON mdm.' + quotename(@EntityTable) + N'(Version_ID, AsOf_ID)  
                    WHERE [AsOf_ID] IS NOT NULL  
                    ' + @Compress + N';  
                ';  
  
            --Execute the dynamic SQL  
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL;  
  
            --If StagingBase is specified create the Entity Staging (_Leaf) table in the staging schema    
            IF COALESCE(@StagingBase, N'') <> N'' BEGIN  
                SET @SQL = N'    
                    CREATE TABLE [stg].' + quotename(@StagingTable) + N'    
                    (    
                        --Identity    
                        ID                  INT IDENTITY (1, 1) NOT NULL,  
                          
                        --Import Specific  
                        ImportType          TINYINT NOT NULL,  
  
                        --Status    
                        ImportStatus_ID     TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @StagingTable  + N'_ImportStatus_ID') + N' DEFAULT 0,   
        
                        --Info  
                        Batch_ID            INT NULL,  
                        BatchTag            NVARCHAR(50) NULL,  
                        --Error Code  
                        ErrorCode           INT,  
                        Code                NVARCHAR(250) NULL,  
                        [Name]              NVARCHAR(250) NULL,    
                        NewCode             NVARCHAR(250) NULL,      
                                                                                                            
                        --Create PRIMARY KEY constraint    
                        CONSTRAINT ' + quotename(N'pk_' + @StagingTable) + N'     
                            PRIMARY KEY CLUSTERED (ID),    
                        
                        --Create CHECK constraints    
                        CONSTRAINT ' + quotename(N'ck_' + @StagingTable + N'_ImportType') + N'     
                            CHECK (ImportType BETWEEN 0 AND 6),    
                              
                        CONSTRAINT ' + quotename(N'ck_' + @StagingTable + N'_ImportStatus_ID') + N'     
                            CHECK (ImportStatus_ID BETWEEN 0 and 3)     
                    )    
                    ' + @Compress + N';  
                      
                    --Index [Batch_ID] for performance  
                    CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @StagingTable + N'_Batch_ID') + N'   
                        ON [stg].' + quotename(@StagingTable) + N'(Batch_ID)  
                        ' + @Compress + N';  
                      
                    --Index [BatchTag] for performance  
                    CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @StagingTable + N'_BatchTag') + N'   
                        ON [stg].' + quotename(@StagingTable) + N'(BatchTag)  
                        ' + @Compress + N';      
                    ';    
       
                --Execute the dynamic SQL    
                --PRINT(@SQL);    
                EXEC sp_executesql @SQL;    
  
            END; --IF  
              
            --Create the Member Security (MS) table  
            --There is no IDENTITY() column since this table gets bulk- deleted & inserted frequently   
            --so key space might be a problem in the long term  
            SET @SQL = N'  
                CREATE TABLE mdm.' + quotename(@SecurityTable) + N'  
                (  
                    Version_ID          INT NOT NULL,  
                    SecurityRole_ID     INT NOT NULL,   
                    MemberType_ID       TINYINT NOT NULL,  
                    EN_ID               INT NULL,  
                    HP_ID               INT NULL,  
                    Privilege_ID        TINYINT NOT NULL,  
  
                    --Create FOREIGN KEY contraints  
                    CONSTRAINT ' + quotename(N'fk_' + @SecurityTable + N'_' + @EntityTable + N'_Version_ID_EN_ID') + N'  
                        FOREIGN KEY (Version_ID, EN_ID) REFERENCES mdm.' + @EntityTable + N'(Version_ID, ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE CASCADE,  
                    CONSTRAINT ' + quotename(N'fk_' + @SecurityTable + N'_tblSecurityRole_SecurityRole_ID') + N'  
                        FOREIGN KEY (SecurityRole_ID) REFERENCES mdm.tblSecurityRole(ID)  
                        ON UPDATE NO ACTION   
                        ON DELETE CASCADE,  
                  
                    --Create CHECK constraints  
                    CONSTRAINT ' + quotename(N'ck_' + @SecurityTable + N'_MemberType_ID') + N'   
                        CHECK ((MemberType_ID = 1 AND EN_ID IS NOT NULL AND HP_ID IS NULL) OR  
                                (MemberType_ID = 2 AND HP_ID IS NOT NULL AND EN_ID IS NULL)),  
                    CONSTRAINT ' + quotename(N'fk_' + @SecurityTable + N'_Privilege_ID') + N'  
                        CHECK (Privilege_ID BETWEEN 1 AND 3)  
                )  
                ' + @Compress + N';  
                ';  
                
            --Direct assignment of expression > 4000 nchars seems to truncate string. Workaround is to concatenate.  
            SET @SQL = @SQL + N'      
                --Create unique index to improve MERGE performance during population  
                CREATE UNIQUE CLUSTERED INDEX ' + quotename(N'ux_' + @SecurityTable + N'_Version_ID_SecurityRole_ID_MemberType_ID_EN_ID_HP_ID') + N'  
                    ON mdm.' + quotename(@SecurityTable) + N'(Version_ID, SecurityRole_ID, MemberType_ID, EN_ID, HP_ID)  
                    ' + @Compress + N';  
                      
                --Index foreign key columns for performance  
                CREATE UNIQUE NONCLUSTERED INDEX ' + quotename(N'ux_' + @SecurityTable + N'_Version_ID_EN_ID_SecurityRole_ID') + N'  
                    ON mdm.' + quotename(@SecurityTable) + N'(Version_ID, EN_ID, SecurityRole_ID)  
                    WHERE [EN_ID] IS NOT NULL --UNIQUE index required to permit duplicate nodes iff EN_ID==NULL  
                    ' + @Compress + N';  
                      
                CREATE UNIQUE NONCLUSTERED INDEX ' + quotename(N'ux_' + @SecurityTable + N'_Version_ID_HP_ID_SecurityRole_ID') + N'  
                    ON mdm.' + quotename(@SecurityTable) + N'(Version_ID, HP_ID, SecurityRole_ID)  
                    WHERE [HP_ID] IS NOT NULL --UNIQUE index required to permit duplicate nodes iff HP_ID==NULL  
                    ' + @Compress + N';  
                      
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @SecurityTable + N'_SecurityRole_ID') + N'   
                    ON mdm.' + quotename(@SecurityTable) + N'(SecurityRole_ID)  
                    ' + @Compress + N';  
                ';  
  
            --Execute the dynamic SQL  
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL;  
                 
            --Add default columns to Attribute table  
            INSERT INTO mdm.tblAttribute (Entity_ID,SortOrder,DomainEntity_ID,AttributeType_ID,MemberType_ID,IsSystem,IsReadOnly,IsCode,IsName,[Name],DisplayName,TableColumn,DisplayWidth,DataType_ID,DataTypeInformation,InputMask_ID,EnterUserID,EnterVersionID,LastChgUserID,LastChgVersionID)  
            VALUES  
             (@Entity_ID, 1, NULL, 3, 1, 1, 1, 0, 0, N'ID',N'ID',N'ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 2, NULL, 3, 1, 1, 1, 0, 0, N'Version_ID',N'Version_ID',N'Version_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 4, NULL, 3, 1, 1, 1, 0, 0, N'Status_ID',N'Status_ID',N'Status_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 5, NULL, 3, 1, 1, 1, 0, 0, N'ValidationStatus_ID',N'ValidationStatus_ID',N'ValidationStatus_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 6, NULL, 3, 1, 1, 1, 0, 0, N'EnterDTM',N'EnterDTM',N'EnterDTM',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 7, NULL, 3, 1, 1, 1, 0, 0, N'EnterUserID',N'EnterUserID',N'EnterUserID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 8, NULL, 3, 1, 1, 1, 0, 0, N'EnterVersionID',N'EnterVersionID',N'EnterVersionID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 9, NULL, 3, 1, 1, 1, 0, 0, N'LastChgDTM',N'LastChgDTM',N'LastChgDTM',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 10, NULL, 3, 1, 1, 1, 0, 0, N'LastChgUserID',N'LastChgUserID',N'LastChgUserID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 11, NULL, 3, 1, 1, 1, 0, 0, N'LastChgVersionID',N'LastChgVersionID',N'LastChgVersionID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 12, NULL, 3, 1, 1, 1, 0, 0, N'LastChgTS',N'LastChgTS',N'LastChgTS',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 13, NULL, 1, 1, 1, 0, 0, 1, N'Name',N'Name',N'Name',250,1,250,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 14, NULL, 1, 1, 1, 0, 1, 0, N'Code',N'Code',N'Code',250,1,250,1,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 15, NULL, 3, 1, 1, 1, 0, 0, N'MUID',N'MUID',N'MUID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 16, NULL, 3, 1, 1, 1, 0, 0, N'AsOf_ID',N'AsOf_ID',N'AsOf_ID',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ,(@Entity_ID, 17, NULL, 3, 1, 1, 0, 0, 0, N'ChangeTrackingMask',N'ChangeTrackingMask',N'ChangeTrackingMask',0,0,NULL,0,@User_ID,@Version_ID,@User_ID,@Version_ID)  
            ;  
  
            --Create related metadata member for entity  
            IF EXISTS(SELECT 1 FROM mdm.tblModel WHERE ID = @Model_ID AND IsSystem = 0) BEGIN  
                  
                DECLARE @EntityMetadataCode NVARCHAR(250), @AttributeMetadataCode NVARCHAR(250), @ReturnAttr_MUID UNIQUEIDENTIFIER;  
  
                --We will build out entity metadata codes as {ModelID_EntityId} to ensure uniqueness  
                SET @EntityMetadataCode = CONVERT(NVARCHAR(30), @Model_ID) + N'_' + CONVERT(NVARCHAR(20), @Entity_ID);   
                EXEC mdm.udpUserDefinedMetadataSave N'Entity', @Return_MUID, @EntityName, @EntityMetadataCode, @User_ID;  
  
                --Write out Name and Code attributes since they are not done separately through an attribute call  
                IF (@IsSystem = 0) BEGIN  
  
                    --Create related metadata members for Name  
                    SET @AttributeMetadataCode = CONVERT(NVARCHAR(30), @Model_ID) + N'_' + CONVERT(NVARCHAR(30), @Entity_ID) + N'_Name_1';  
                    SELECT @ReturnAttr_MUID = MUID FROM mdm.tblAttribute WHERE IsName = 1 AND MemberType_ID = 1 AND Entity_ID = @Entity_ID;  
                    EXEC mdm.udpUserDefinedMetadataSave N'Attribute', @ReturnAttr_MUID, N'Name', @AttributeMetadataCode, @User_ID;  
  
                    --Create related metadata members for Code  
                    SET @AttributeMetadataCode = CONVERT(NVARCHAR(30), @Model_ID) + N'_' + CONVERT(NVARCHAR(30), @Entity_ID) + N'_Code_1';  
                    SELECT @ReturnAttr_MUID = MUID FROM mdm.tblAttribute WHERE IsCode = 1 AND MemberType_ID = 1 AND Entity_ID = @Entity_ID;  
                    EXEC mdm.udpUserDefinedMetadataSave N'Attribute', @ReturnAttr_MUID, N'Code', @AttributeMetadataCode, @User_ID;  
  
                END; --if          
            END; --if  
        END; --if  
  
        --Recreate the views  
        EXEC mdm.udpCreateViews @Model_ID, @Entity_ID;  
        EXEC mdm.udpCreateEntityStagingErrorDetailViews @Entity_ID;  
  
        --Return values  
        SET @Return_ID = @Entity_ID;  
        SELECT   
            @Entity_ID AS ID,   
            @EntityName AS CurrentName;   
  
        --Commit only if we are not nested  
        IF @TranCounter = 0   
        BEGIN  
            COMMIT TRANSACTION;  
            --Set @TranCommitted as 1 (committed).  
            SET @TranCommitted = 1;  
        END -- IF  
  
        IF @NewEntity = 1   
        BEGIN  
            -- Create the leaf member staging stored procedure.  
            -- This should be done after the transaction is committed and the staging table is created.   
            EXEC mdm.udpEntityStagingCreateLeafStoredProcedure @Entity_ID  
        END; -- IF  
          
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
  
        IF @TranCommitted = 0 -- Don't rollback when the transaction has been committed.  
        BEGIN  
            IF @TranCounter = 0 ROLLBACK TRANSACTION;    
            ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;    
        END; -- IF  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
