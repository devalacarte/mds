SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    DECLARE @Attribute_ID INT;  
    SET @Attribute_ID = 891;  
    EXEC mdm.udpAttributeDelete @Attribute_ID, 1;  
    SELECT * FROM mdm.tblAttribute WHERE ID = @Attribute_ID;  
  
MDM Errors that this proc may throw:  
100022 - when an attempt is made to delete a system attribute.  
*/  
CREATE PROCEDURE [mdm].[udpAttributeDelete]  
(  
    @Attribute_ID       INTEGER,  
    @MemberType_ID      TINYINT,  
    @CreateViewsInd     BIT = NULL --1=Create,0=DoNot Create  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
      
    DECLARE @IsValidParam       BIT = 1,              
            @SQL                NVARCHAR(MAX) = N'',  
            @TableName          sysname,  
            @AttributeName      NVARCHAR(250),  
            @TableColumn        sysname,  
            @ForeignTableName   sysname,  
            @Model_ID           INT,  
            @Entity_ID          INT,  
            @AttributeType_ID   INT,  
            @DomainEntity_ID    INT,  
            @IsSystem           BIT,  
            @AttributeMUID      UNIQUEIDENTIFIER,  
            @idx                sysname,   
            @fk                 sysname,  
            @StagingBase        NVARCHAR(60),  
            @StagingTableName   sysname,  
            @TranCommitted      INT = 0; -- 0: Not committed, 1: Committed.      
              
    --Valid MemberType_ID values are 1,2, 3     
    EXECUTE @IsValidParam = mdm.udpIDParameterCheck @MemberType_ID, NULL, 1, 3, 1;  
    IF (@IsValidParam = 0) BEGIN  
        RAISERROR('MDSERR100002|The Member Type is not valid.', 16, 1);  
        RETURN;            
    END; --if  
      
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;  
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
          
        SET @CreateViewsInd = ISNULL(@CreateViewsInd, 1);  
  
        SELECT   
            @Model_ID = e.Model_ID,  
            @Entity_ID = e.ID,  
            @AttributeName = a.[Name],  
            @DomainEntity_ID = a.DomainEntity_ID,  
            @TableColumn = a.TableColumn,   
            @AttributeType_ID = a.AttributeType_ID,  
            @AttributeMUID = a.MUID,  
            @IsSystem = a.IsSystem       
        FROM mdm.tblEntity AS e  
        INNER JOIN mdm.tblAttribute AS a ON (e.ID = a.Entity_ID)  
        WHERE a.ID = @Attribute_ID;  
          
        IF @IsSystem = 1  
        BEGIN  
            RAISERROR('MDSERR100022|A system attribute cannot be deleted.', 16, 1);  
            RETURN;    
         END; --if  
                           
        --Get the Table Name.  
        SET @TableName = mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID);      
          
        --Get the Staging Table Name and Staging Base.   
        SELECT @StagingTableName = Entity_StagingTableName, @StagingBase = Entity_StagingBase FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Attribute_ID = @Attribute_ID;  
          
        IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[mdm].' + quotename(@TableName)) AND [name] = @TableColumn) BEGIN          
                      
            --Check for an attribute type of DBA      
            IF (@AttributeType_ID = 2) BEGIN   
                          
                --Get The Table Name of the table this attribute is a domain-based list for  
                SET @ForeignTableName = mdm.udfTableNameGetByID(@DomainEntity_ID, 1);  
                  
                --Create the index and constraints for this attribute column  
                SET @idx = N'ix_' + @TableName + N'_Version_ID_' + @TableColumn;  
                SET @fk = N'fk_' + @TableName + N'_' + @ForeignTableName + N'_Version_ID_' + @TableColumn;  
                  
            --Check for a file link  attribute                   
            END ELSE IF (@AttributeType_ID = 4) BEGIN  
              
                SET @ForeignTableName = N'tblFile';  
                SET @idx = N'ix_' + @TableName + N'_' + @TableColumn;  
                SET @fk = N'fk_' + @TableName + N'_' + @ForeignTableName + N'_' + @TableColumn;  
                  
            END; --if  
              
            --Drop FK index  
            IF @idx IS NOT NULL AND EXISTS(SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[mdm].' + quotename(@TableName)) AND name = @idx) BEGIN   
                SET @SQL = @SQL + N'  
                DROP INDEX [mdm].' + quotename(@TableName) + N'.' + quotename(@idx) + N';';  
            END; --if  
              
            --Drop FK constraint  
            IF @fk IS NOT NULL AND EXISTS(SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[mdm].' + @fk) AND parent_object_id = OBJECT_ID(N'[mdm].' + quotename(@TableName))) BEGIN  
                SET @SQL = @SQL + N'  
                ALTER TABLE [mdm].' + quotename(@TableName) + N' DROP CONSTRAINT ' + quotename(@fk) + N';';  
            END; --if  
              
            --Drop column  
            SET @SQL = @SQL + N'  
                ALTER TABLE mdm.' + quotename(@TableName) + N' DROP COLUMN ' + quotename(@TableColumn) + N';';  
  
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL;  
        END; --if  
  
        --Remove attribute group detail entry  
        DELETE FROM mdm.tblAttributeGroupDetail WHERE Attribute_ID = @Attribute_ID;  
          
        --Delete the security around the attribute  
        DECLARE    @Object_ID INT = mdm.udfSecurityObjectIDGetByCode(N'DIMATT');  
        EXEC mdm.udpSecurityPrivilegesDelete NULL, NULL, @Object_ID, @Attribute_ID;  
  
        --Delete the attribute record   
        DELETE FROM mdm.tblAttribute WHERE ID = @Attribute_ID;  
  
        --Delete user-defined metadata  
        EXEC mdm.udpUserDefinedMetadataDelete @Object_Type = N'Attribute', @Object_ID = @AttributeMUID;  
          
        IF @CreateViewsInd = 1 EXEC mdm.udpCreateViews @Model_ID, @Entity_ID;  
                  
        --Delete the column from the staging table.    
        IF LEN(COALESCE(@StagingTableName, N'')) > 0 AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'stg.' + quotename(@StagingTableName)) AND type in (N'U'))     
        BEGIN                    
            SET @SQL = N'ALTER TABLE stg.' + quotename(@StagingTableName) + N' DROP COLUMN ' + quotename(@AttributeName);  
            --Execute the dynamic SQL    
            EXEC sp_executesql @SQL;       
        END; -- IF   
              
        --Commit only if we are not nested  
        IF @TranCounter = 0   
        BEGIN  
            COMMIT TRANSACTION;  
            SET @TranCommitted = 1;  
        END; -- IF  
          
        -- Recreate the staging stored procedure.  
        IF @MemberType_ID = 1  
        BEGIN  
            EXEC mdm.udpEntityStagingCreateLeafStoredProcedure @Entity_ID   
        END -- IF  
        ELSE IF @MemberType_ID = 2 BEGIN  
            EXEC mdm.udpEntityStagingCreateConsolidatedStoredProcedure @Entity_ID  
        END -- IF  
  
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
  
        --On error, return NULL results  
        --SELECT @Return_ID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
