SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpEntityStagingUpdateTableColumns 31;  
*/  
CREATE PROCEDURE [mdm].[udpEntityStagingUpdateTableColumns]  
(  
    @Entity_ID          INT   
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;    
    
    DECLARE  
        @IsFlat                     INT = 0,   
        @Attribute_ID               INT = NULL,  
        @AttributeType_ID           INT,    
        @DataType_ID                TINYINT = NULL,  
        @DataTypeInformation        INT = NULL,  
        @SQL                        NVARCHAR(MAX) = N'',  
        @StagingLeafTable           sysname,  
        @StagingConsolidatedTable   sysname,  
        @StagingRelationshipTable   sysname,  
        @StagingBase                NVARCHAR(50),    
        @AttributeType_FreeForm     INT = 1,    
        @AttributeType_DBA          INT = 2,    
        @AttributeDataType_Text     INT = 1,    
        @AttributeDataType_Number   INT = 2,    
        @AttributeDataType_DateTime INT = 3,    
        @AttributeDataType_Link     INT = 6,    
        @Compress                   NVARCHAR(MAX) = N'',  
        @TranCommitted              INT = 0, -- 0: Not committed, 1: Committed.    
        @AllTypes                   INT = 0,  
        @IsSystem                   INT;   
    
                 
    -- Validate @Entity_ID    
    DECLARE @IsValidParam BIT;    
    SET @IsValidParam = 1;    
    EXECUTE @IsValidParam = mdm.udpIDParameterCheck @Entity_ID, 5, NULL, NULL, 1;    
    IF (@IsValidParam = 0)    
    BEGIN    
        RAISERROR('MDSERR310048|Error while updating staging table columns. Invalid Entity ID.', 16, 1);  
        RETURN;    
    END; --if    
      
    SELECT   
        @IsSystem = IsSystem   
    FROM   
        mdm.tblEntity  
    WHERE   
        ID = @Entity_ID;  
             
    IF (@IsSystem = 1)    
    BEGIN    
        RAISERROR('MDSERR310049|Error while updating staging table columns. System entities cannot be updated.', 16, 1);  
        RETURN;      
    END; --if  
  
    --Start transaction, being careful to check if we are nested    
    DECLARE @TranCounter INT;     
    SET @TranCounter = @@TRANCOUNT;    
    IF @TranCounter > 0 SAVE TRANSACTION TX;    
    ELSE BEGIN TRANSACTION;    
    
    BEGIN TRY    
        --Get the appropriate Staging table name       
  
        SELECT  
            @IsFlat = IsFlat,    
            @StagingLeafTable = StagingLeafName,  
            @StagingConsolidatedTable = StagingConsolidatedName,  
            @StagingRelationshipTable = StagingRelationshipName,   
            @StagingBase = StagingBase  
        FROM  
            [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Entity_ID;  
          
        IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'stg.' + quotename(@StagingLeafTable) + '') AND type in (N'U')) BEGIN  
            --Drop existing, non-required columns from the entity staging table.  
            SELECT  
                @SQL = @SQL + CHAR(10) + CHAR(13)+ N'ALTER TABLE stg.' + quotename(@StagingLeafTable) + N' DROP COLUMN ' + quotename(COLUMN_NAME) + N'; '  
            FROM INFORMATION_SCHEMA.COLUMNS  
            WHERE   
                TABLE_CATALOG = DB_NAME() AND  
                TABLE_NAME = @StagingLeafTable AND  
                COLUMN_NAME NOT IN (N'ID', N'ImportType', N'ImportStatus_ID', N'Batch_ID', N'BatchTag', N'Name', N'Code', N'NewCode', N'ErrorCode') --Never drop these required columns.  
              
            --Execute the dynamic SQL  
            --PRINT(@SQL);    
            EXEC sp_executesql @SQL;  
            SET @SQL = N'';  
    
        END  
        ELSE BEGIN  
            --Create the Entity Staging table in the staging schema    
            SET @SQL = N'    
                CREATE TABLE [stg].' + quotename(@StagingLeafTable) + N'    
                (    
                    --Identity    
                    ID                  INT IDENTITY (1, 1) NOT NULL,  
                      
                    --Import Specific  
                    ImportType          TINYINT NOT NULL,  
  
                    --Status    
                    ImportStatus_ID     TINYINT NOT NULL CONSTRAINT ' + quotename(N'df_' + @StagingLeafTable  + N'_ImportStatus_ID') + N' DEFAULT 0,   
    
                    --Info  
                    Batch_ID            INT NULL,  
                    BatchTag            NVARCHAR(50) NULL,  
                    --Error Code  
                    ErrorCode           INT,  
                    Code                NVARCHAR(250) NULL,  
                    [Name]              NVARCHAR(250) NULL,    
                    NewCode             NVARCHAR(250) NULL,      
                                                                                                        
                    --Create PRIMARY KEY constraint    
                    CONSTRAINT ' + quotename(N'pk_' + @StagingLeafTable) + N'     
                        PRIMARY KEY CLUSTERED (ID),    
                    
                    --Create CHECK constraints    
                    CONSTRAINT ' + quotename(N'ck_' + @StagingLeafTable + N'_ImportType') + N'     
                        CHECK (ImportType BETWEEN 0 AND 6),    
                          
                    CONSTRAINT ' + quotename(N'ck_' + @StagingLeafTable + N'_ImportStatus_ID') + N'     
                        CHECK (ImportStatus_ID BETWEEN 0 and 3)     
                )    
                ' + @Compress + N';  
                  
                --Index [Batch_ID] for performance  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @StagingLeafTable + N'_Batch_ID') + N'   
                    ON [stg].' + quotename(@StagingLeafTable) + N'(Batch_ID)  
                    ' + @Compress + N';  
                                      
                --Index [BatchTag] for performance  
                CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @StagingLeafTable + N'_BatchTag') + N'   
                    ON [stg].' + quotename(@StagingLeafTable) + N'(BatchTag)  
                    ' + @Compress + N';  
  
                ';    
   
            --Execute the dynamic SQL    
            --PRINT(@SQL);    
            EXEC sp_executesql @SQL;    
  
            SET @SQL = N'';  
        END  
  
        --Add columns to the entity staging table based on current set of non-system attributes.          
        SELECT  
            @SQL = @SQL + CHAR(10) + CHAR(13)+ N'ALTER TABLE stg.' + quotename(@StagingLeafTable) + N' ADD ' + quotename(att.Attribute_Name) + N' ' +  
            CASE  
                WHEN att.Attribute_Type_ID = @AttributeType_FreeForm THEN  
                    CASE  
                        WHEN att.Attribute_DataType_ID = @AttributeDataType_Text OR att.Attribute_DataType_ID = @AttributeDataType_Link THEN  
                            CASE  
                                WHEN att.Attribute_DataType_Information < 1 THEN N'NVARCHAR(1) NULL;'  
                                WHEN att.Attribute_DataType_Information > 4000 THEN N'NVARCHAR(4000) NULL;'--Arbitrary limit  
                                ELSE + N'NVARCHAR(' + CONVERT(NVARCHAR(30), att.Attribute_DataType_Information ) + N') NULL;'  
                            END  
                        WHEN att.Attribute_DataType_ID = @AttributeDataType_Number THEN --DECIMAL(38, N)  
                            CASE  
                                WHEN att.Attribute_DataType_Information < 0 THEN N'DECIMAL(38, 0) NULL;'--DECIMAL(38, 0) is minimum precision allowed by SQL  
                                WHEN att.Attribute_DataType_Information > 38 THEN N'DECIMAL(38, 38) NULL;'--DECIMAL(38, 38) is maximum precision allowed by SQL    
                                ELSE +  N'DECIMAL(38, ' + CONVERT(NVARCHAR(2), Attribute_DataType_Information) + N') NULL;'  
                            END  
                        WHEN att.Attribute_DataType_ID = @AttributeDataType_DateTime THEN  
                            N'DATETIME2(3) NULL;'  
                        WHEN att.Attribute_DataType_ID = 7 THEN --INTEGER   
                            N'INTEGER NULL;'  
                    END  
                ELSE --DBA/FILE   
                    N'NVARCHAR(250) NULL;'  
                END  
        FROM  
            mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES att  
        WHERE  
            att.Entity_ID = @Entity_ID AND  
            att.Attribute_MemberType_ID = 1 AND  
            att.Attribute_IsSystem = 0  
  
        --Execute the dynamic SQL  
        --PRINT @SQL    
        EXEC sp_executesql @SQL;    
        SET @SQL = N'';  
  
        IF @IsFlat = 0 BEGIN              
            IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'stg.' + quotename(@StagingConsolidatedTable) + '') AND type in (N'U')) BEGIN  
                --Drop existing, non-required columns from the entity staging table.  
                SELECT  
                    @SQL = @SQL + CHAR(10) + CHAR(13)+ N'ALTER TABLE stg.' + quotename(@StagingConsolidatedTable) + N' DROP COLUMN ' + quotename(COLUMN_NAME) + N'; '  
                FROM INFORMATION_SCHEMA.COLUMNS  
                WHERE   
                    TABLE_CATALOG = DB_NAME() AND  
                    TABLE_NAME = @StagingConsolidatedTable AND  
                    COLUMN_NAME NOT IN (N'ID', N'ImportType', N'ImportStatus_ID', N'Batch_ID', N'BatchTag', N'HierarchyName', N'Name', N'Code', N'NewCode', N'ErrorCode') --Never drop these required columns.  
                  
                --Execute the dynamic SQL  
                EXEC sp_executesql @SQL;    
                SET @SQL = N'';  
                  
            END  
            ELSE BEGIN  
                --Create the Consolidated Staging table (_Consolidated) in Staging (stg) Schema.  
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
                SET @SQL = N'';  
                  
                --Create the Hierarchy Relationship Staging table (_Relationship) in Staging (stg) Schema  
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
                      
                    ';  
                       
                 --Execute the dynamic SQL             
        
                EXEC sp_executesql @SQL;  
       
                SET @SQL = N'';  
            END -- IF  
              
            --Add columns to the entity staging table based on current set of non-system attributes.          
            SELECT  
                @SQL = @SQL + CHAR(10) + CHAR(13)+ N'ALTER TABLE stg.' + quotename(@StagingConsolidatedTable) + N' ADD ' + quotename(att.Attribute_Name) + N' ' +  
                CASE  
                    WHEN att.Attribute_Type_ID = @AttributeType_FreeForm THEN  
                        CASE  
                            WHEN att.Attribute_DataType_ID = @AttributeDataType_Text OR att.Attribute_DataType_ID = @AttributeDataType_Link THEN  
                                CASE  
                                    WHEN att.Attribute_DataType_Information < 1 THEN N'NVARCHAR(1) NULL;'  
                                    WHEN att.Attribute_DataType_Information > 4000 THEN N'NVARCHAR(4000) NULL;'--Arbitrary limit  
                                    ELSE + N'NVARCHAR(' + CONVERT(NVARCHAR(30), att.Attribute_DataType_Information ) + N') NULL;'  
                                END  
                            WHEN att.Attribute_DataType_ID = @AttributeDataType_Number THEN --DECIMAL(38, N)  
                                CASE  
                                    WHEN att.Attribute_DataType_Information < 0 THEN N'DECIMAL(38, 0) NULL;'--DECIMAL(38, 0) is minimum precision allowed by SQL  
                                    WHEN att.Attribute_DataType_Information > 38 THEN N'DECIMAL(38, 38) NULL;'--DECIMAL(38, 38) is maximum precision allowed by SQL    
                                    ELSE +  N'DECIMAL(38, ' + CONVERT(NVARCHAR(2), Attribute_DataType_Information) + N') NULL;'  
                                END  
                            WHEN att.Attribute_DataType_ID = @AttributeDataType_DateTime THEN  
                                N'DATETIME2(3) NULL;'  
                            WHEN att.Attribute_DataType_ID = 7 THEN --INTEGER   
                                N'INTEGER NULL;'  
                        END  
                    ELSE --DBA/FILE   
                        N'NVARCHAR(250) NULL;'  
                    END  
            FROM  
                mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES att  
            WHERE  
                att.Entity_ID = @Entity_ID AND  
                att.Attribute_MemberType_ID = 2 AND  
                att.Attribute_IsSystem = 0  
  
            --Execute the dynamic SQL  
            --PRINT @SQL    
            EXEC sp_executesql @SQL;    
            SET @SQL = N'';  
  
        END  
          
         -- Create the appropriate member staging stored procedure.  
        EXEC mdm.udpEntityStagingCreateLeafStoredProcedure @Entity_ID  
  
        IF @IsFlat = 0 BEGIN  
            EXEC mdm.udpEntityStagingCreateConsolidatedStoredProcedure @Entity_ID  
            EXEC mdm.udpEntityStagingCreateRelationshipStoredProcedure @Entity_ID  
        END  
          
        --Commit only if we are not nested    
        IF @TranCounter = 0 COMMIT TRANSACTION;  
          
        SET @TranCommitted = 1;  
  
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
           
        --Throw the error again so the calling procedure can use it    
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);    
            
        RETURN(1);    
    
    END CATCH;    
  
    SET NOCOUNT OFF;    
END;
GO
