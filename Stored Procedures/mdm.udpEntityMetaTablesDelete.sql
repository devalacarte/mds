SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpEntityMetaTablesDelete 1;  
    select * from mdm.tblEntity;  
  
/******************************************************************************  
*  
** Desc:  The stored procedure will delete the following associated meta data tables  
          for an Entity:  
            
          _EN   
          _HP  
          _HR  
          _CM  
          _CN  
  
** Processing Steps:  
        1.  The existence of each table will be check first  
        2.  If the table exists, the drop statement will be executed.  
**  
** Parameters: @Entity_ID    INTEGER  
**  
** Restart:  
        Restart at the beginning. No code modifications required.          
**  
** Tables Used:  
**        tbl_Modelxx_Entityzz_EN  (where xx is the model Id and zz is the Entity Id)  
**        tbl_Modelxx_Entityzz_HP  
**        tbl_Modelxx_Entityzz_HR  
**        tbl_Modelxx_Entityzz_CM  
**        tbl_Modelxx_Entityzz_CN  
**  
** Return values:  
        = 0 Success  
        = 1 Failure  
**  
** Called By:      
        udpEntityDelete  
**  
** Calls:  
        None  
**   
*******************************************************************************/  
*/  
                  
CREATE PROCEDURE [mdm].[udpEntityMetaTablesDelete]  
(  
    @Entity_ID        INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        DECLARE @SQL                        NVARCHAR(MAX),  
                @IsFlat                     BIT,  
                @EntityTable                sysname,  
                @SecurityTable              sysname,  
                @HierarchyTable             sysname,  
                @HierarchyParentTable       sysname,  
                @CollectionTable            sysname,  
                @CollectionMemberTable      sysname,  
                @LeafStagingTable           sysname,  
                @ConsolidatedStagingTable   sysname,  
                @RelationshipStagingTable   sysname,    
                @ConstraintName             sysname,  
                @TempID                     INTEGER,  
                @TempTableName              sysname;  
  
        DECLARE    @TableFKConstraints      TABLE  
                    ([ID] [INT] IDENTITY (1, 1) Primary KEY CLUSTERED NOT NULL,  
                    TableName               sysname,  
                    ConstraintName            sysname);  
  
            --Set variables.  
            SET @SQL = N'';  
  
            SELECT   
                @EntityTable = 'mdm.[' + EntityTable + ']',  
                @SecurityTable = 'mdm.[' + SecurityTable + ']',  
                @IsFlat = IsFlat,  
                @HierarchyTable = 'mdm.[' + HierarchyTable + ']',  
                @HierarchyParentTable = 'mdm.[' +HierarchyParentTable + ']',  
                @CollectionTable = 'mdm.[' +CollectionTable + ']',  
                @CollectionMemberTable = 'mdm.[' +CollectionMemberTable + ']'  
            FROM   
                mdm.tblEntity WHERE ID = @Entity_ID;  
                  
            --Get staging table names.      
            SELECT      
                @LeafStagingTable = CASE WHEN StagingLeafTable IS NULL THEN N''   
                                        ELSE 'stg.[' + StagingLeafTable + ']'  
                                    END,    
                @ConsolidatedStagingTable = CASE WHEN StagingConsolidatedTable IS NULL THEN N''   
                                                ELSE 'stg.[' + StagingConsolidatedTable + ']'  
                                            END,                            
                @RelationshipStagingTable = CASE WHEN StagingRelationshipTable IS NULL THEN N''   
                                                ELSE 'stg.[' + StagingRelationshipTable + ']'  
                                            END  
            FROM   
                mdm.viw_SYSTEM_SCHEMA_ENTITY WHERE ID = @Entity_ID;  
      
            -- Get all the foreign key constraints for the entity table - EN  
            INSERT INTO @TableFKConstraints  
                            SELECT  schema_name(schema_id) + '.[' + object_name(parent_object_id) + ']',  
                                    s.[name]  
                            FROM sys.foreign_keys s  
                            WHERE referenced_object_id = object_id(@EntityTable);  
              
            -- Get all the foreign key constraints for the secutity table - MS  
            INSERT INTO @TableFKConstraints  
                            SELECT  schema_name(schema_id) + '.[' + object_name(parent_object_id) + ']',  
                                    s.[name]  
                            FROM sys.foreign_keys s  
                            WHERE referenced_object_id = object_id(@SecurityTable);  
  
            -- Get all the foreign key constraints for the hierarchy table - HR  
            INSERT INTO @TableFKConstraints  
                            SELECT  schema_name(schema_id) + '.[' + object_name(parent_object_id)+ ']',  
                                    s.[name]  
                            FROM sys.foreign_keys s  
                            WHERE referenced_object_id = object_id(@HierarchyTable);  
  
            -- Get all the foreign key constraints for the hierarchy parent table - HP  
            INSERT INTO @TableFKConstraints  
                            SELECT  schema_name(schema_id) + '.[' + object_name(parent_object_id)+ ']',  
                                    s.[name]  
                            FROM sys.foreign_keys s  
                            WHERE referenced_object_id = object_id(@HierarchyParentTable);  
               
            -- Get all the foreign key constraints for the collection table - CN  
            INSERT INTO @TableFKConstraints  
                            SELECT  schema_name(schema_id) + '.[' + object_name(parent_object_id)+ ']',  
                                    s.[name]  
                            FROM sys.foreign_keys s  
                            WHERE referenced_object_id = object_id(@CollectionTable);  
  
            -- Get all the foreign key constraints for the collection member table - CM  
            INSERT INTO @TableFKConstraints  
                            SELECT  schema_name(schema_id) + '.[' + object_name(parent_object_id)+ ']',  
                                    s.[name]  
                            FROM sys.foreign_keys s  
                            WHERE referenced_object_id = object_id(@CollectionMemberTable);  
  
            -- Delete all the constraints first  
            DECLARE @Counter INT = 1 ;  
            DECLARE @MaxCounter INT = (SELECT MAX(ID) FROM @TableFKConstraints);  
            SET @Counter =1;  
            WHILE @Counter <= @MaxCounter  
            BEGIN  
                SELECT @TempID = ID, @TempTableName = TableName, @ConstraintName = ConstraintName   
                    FROM @TableFKConstraints WHERE ID = @Counter;  
  
                SET @SQL = @SQL + N'ALTER TABLE ' + @TempTableName +   
                            ' DROP CONSTRAINT ' + @ConstraintName + N';'  
  
                SET @Counter = @Counter +1;  
            END  
  
            --Drop the related entity table  
            --Delete @LeafStagingTable for Entity Based Staging  
            SET @SQL = @SQL + N'  
                IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @EntityTable + N''') AND type = (N''U''))  
                    DROP TABLE ' + @EntityTable + N';  
                IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @SecurityTable + N''') AND type = (N''U''))  
                    DROP TABLE ' + @SecurityTable + N';  
                IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @LeafStagingTable + N''') AND type = (N''U''))    
                    DROP TABLE ' + @LeafStagingTable + N';'   
      
            -- Drop the related hierarchy, hierarchy parent, collection and collection member tables if the Entity is not flat  
            -- Drop the related HierarchyParent table for Entity Based Staging     
  
            IF (@IsFlat = 0) BEGIN   
                SET @SQL = @SQL + N'  
                    IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N''' + @ConsolidatedStagingTable + N''') AND type = (N''U''))  
                        DROP TABLE ' + @ConsolidatedStagingTable + N';      
                    IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N''' + @RelationshipStagingTable + N''') AND type = (N''U''))  
                        DROP TABLE ' + @RelationshipStagingTable + N';      
                    IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N''' + @HierarchyTable + N''') AND type = (N''U''))  
                        DROP TABLE ' + @HierarchyTable + N';  
                    IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N''' + @HierarchyParentTable + N''') AND type = (N''U''))  
                        DROP TABLE ' +  @HierarchyParentTable + N';  
                    IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N''' + @CollectionTable + N''') AND type = (N''U''))  
                        DROP TABLE ' + @CollectionTable + N';  
                    IF  EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N''' + @CollectionMemberTable + N''') AND type = (N''U''))  
                        DROP TABLE ' + @CollectionMemberTable + N';'  
                                  
            END;  
        EXEC sp_executesql @SQL;  
  
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
  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
