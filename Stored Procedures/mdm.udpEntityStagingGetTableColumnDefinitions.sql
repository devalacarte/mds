SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Returns two result sets:  
    1) Returns the entity IsFlat and EntityStagingTable name.  
    2) Returns an empty resultset that is used to create an empty DataTable for bulk copy operations, using SqlBulkCopy class, for the leaf or consolidated table.  
    3) Returns an empty resultset that is used to create an empty DataTable for bulk copy operations, using SqlBulkCopy class, for the relationship table.  
  
    EXEC mdm.udpEntityStagingGetTableColumnDefinitions 31, 1;  
    EXEC mdm.udpEntityStagingGetTableColumnDefinitions 31, 2;  
*/  
  
CREATE PROCEDURE [mdm].[udpEntityStagingGetTableColumnDefinitions]  
(  
    @Entity_ID                INT,   
    @MemberType_ID            INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;    
    
    DECLARE   
        @SQL                        NVARCHAR(MAX) = N'',  
        @StagingTableName           sysname,   
        @StagingLeafTable           sysname,  
        @StagingConsolidatedTable   sysname,  
        @StagingRelationshipTable   sysname,  
        @StagingBase                NVARCHAR(50);  
                         
    --Invalid @MemberType_ID    
    IF @MemberType_ID NOT IN (1, 2) --Invalid MemberType    
    BEGIN    
        RAISERROR('MDSERR310044|Error while getting staging table column definitions.  Invalid Member Type.', 16, 1);  
        RETURN;    
    END; --if    
    
    --Invalid @MemberType_ID for THIS entity    
    IF @MemberType_ID = 2     
    BEGIN    
        IF EXISTS(SELECT 1 FROM mdm.tblEntity WHERE ID = @Entity_ID AND IsFlat = 1)--Invalid MemberType    
        BEGIN    
            RAISERROR('MDSERR310045|Error while getting staging table column definitions. Invalid Member Type for this entity.', 16, 1);  
            RETURN;    
        END;    
    END; --if    
    
   
    -- Validate @Entity_ID    
    DECLARE @IsValidParam BIT;    
    SET @IsValidParam = 1;    
    EXECUTE @IsValidParam = mdm.udpIDParameterCheck @Entity_ID, 5, NULL, NULL, 1;    
    IF (@IsValidParam = 0)    
    BEGIN    
        RAISERROR('MDSERR310046|Error while getting staging table column definitions. Invalid Entity ID.', 16, 1);  
        RETURN;    
    END; --if  
      
    BEGIN TRY  
        --Get the appropriate Staging table name       
        SELECT  
            @StagingLeafTable = StagingLeafName,  
            @StagingConsolidatedTable = StagingConsolidatedName,  
            @StagingRelationshipTable = StagingRelationshipName,   
            @StagingBase = StagingBase  
        FROM  
            [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Entity_ID;  
  
        IF @MemberType_ID = 1  
            SET @StagingTableName = @StagingLeafTable  
        ELSE  
            SET @StagingTableName = @StagingConsolidatedTable  
              
        -- Check if staging table exists when StagingBase is specified (when the entity is not a system entity).  
        IF  COALESCE(@StagingBase, N'') <> N'' AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'stg.' + quotename(@StagingTableName) + '') AND type in (N'U')) BEGIN  
            SELECT  
                @SQL = @SQL + N', ' + quotename(att.Attribute_Name)   
            FROM  
                mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES att  
            WHERE  
                att.Entity_ID = @Entity_ID AND  
                att.Attribute_MemberType_ID = @MemberType_ID AND  
                (att.Attribute_IsSystem = 0 OR   
                 att.Attribute_IsCode = 1 OR   
                 att.Attribute_IsName = 1)  
  
            SELECT   
                 N'stg.' + quotename(@StagingTableName) AS EntityStagingTableName  
                ,N'stg.' + quotename(@StagingRelationshipTable) AS EntityStagingRelationshipTableName  
  
            IF @MemberType_ID = 2  
                SET @SQL += N', HierarchyName'  
                  
            SELECT @SQL = N'SELECT ImportType, Batch_ID, BatchTag ' + @SQL + N' FROM stg.' + quotename(@StagingTableName) + N' WHERE 1 = 0';  
            --PRINT @SQL;  
            EXEC sp_executesql @SQL;  
            SET @SQL = N'';  
              
            SELECT @SQL = N'SELECT RelationshipType, Batch_ID, BatchTag, HierarchyName, ParentCode, ChildCode, SortOrder FROM stg.' + quotename(@StagingRelationshipTable) + N' WHERE 1 = 0';  
            EXEC sp_executesql @SQL;  
            SET @SQL = N'';  
  
        END  
        ELSE BEGIN  
            RAISERROR('MDSERR310047|Error while getting staging table column definitions. Entity staging table does not exist.', 16, 1);  
            RETURN;    
        END  
  
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
    
        --Throw the error again so the calling procedure can use it    
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);    
            
        RETURN(1);    
    
    END CATCH;    
  
    SET NOCOUNT OFF;    
END;
GO
