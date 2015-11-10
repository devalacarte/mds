SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpEntityHierarchyDelete 1, 4, 15;  
    SELECT * FROM mdm.tblAttribute;  
*/  
CREATE PROCEDURE [mdm].[udpEntityHierarchyDelete]  
(  
    @User_ID      INT,  
    @Hierarchy_ID INT,  
    @Entity_ID      INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
      
          
    IF NOT EXISTS(SELECT 1 from mdm.tblHierarchy WHERE Entity_ID = @Entity_ID and ID = @Hierarchy_ID)   
    BEGIN  
        RETURN  
    END  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        DECLARE @HierarchyParentTable       sysname,  
                @HierarchyTable             sysname,  
                @CollectionMemberTable      sysname,  
                @CollectionTable            sysname,  
                @StagingConsolidatedTable   sysname,  
                @StagingRelationshipTable   sysname,  
                @StagingBase                NVARCHAR(60),  
                @SQL                        NVARCHAR(MAX),  
                @Version_ID                 INT,  
                @ConstraintName             sysname,  
                @TempID                     INTEGER,  
                @TempTableName              sysname,  
                @HierarchyMUID              UNIQUEIDENTIFIER,  
                @Model_ID                   INT,  
                @ConsolidatedAndRelationship    INT = 3;  
                  
        DECLARE    @TableFKConstraints      TABLE  
                (   [ID] [INT] IDENTITY (1, 1) Primary KEY CLUSTERED NOT NULL,  
                    TableName               sysname,  
                    ConstraintName          sysname);  
                      
        --Get the latest version  
        SELECT @Version_ID = MAX(mv.ID)  
        FROM mdm.tblModelVersion AS mv  
        INNER JOIN mdm.tblEntity AS e ON (e.Model_ID = mv.Model_ID)  
        WHERE e.ID = @Entity_ID;  
  
        --Get the table name  
        SELECT    
            @HierarchyParentTable = HierarchyParentTableName,  
            @HierarchyTable = HierarchyTableName,  
            @CollectionTable = CollectionTableName,  
            @CollectionMemberTable = CollectionMemberTableName,  
            @StagingConsolidatedTable = StagingConsolidatedName,  
            @StagingRelationshipTable = StagingRelationshipName,   
            @StagingBase = StagingBase,  
            @Model_ID = Model_ID  
        FROM  
            [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Entity_ID;  
                           
  
        --delete any transactions and annotations  
        DELETE ta  
        FROM mdm.tblTransactionAnnotation ta  
        INNER JOIN mdm.tblTransaction t  
            ON t.ID = ta.Transaction_ID  
        WHERE t.Entity_ID = @Entity_ID  
        AND t.Hierarchy_ID = @Hierarchy_ID  
          
        DELETE   
        FROM mdm.tblTransaction   
        WHERE Entity_ID = @Entity_ID  
        AND Hierarchy_ID = @Hierarchy_ID  
  
        --Get the MUID  
        SELECT @HierarchyMUID = MUID from mdm.tblHierarchy WHERE ID = @Hierarchy_ID;  
  
        --Delete the security maps  
        --EXEC mdm.udpHierarchyMapDelete @Hierarchy_ID = @Hierarchy_ID, @HierarchyType_ID = 0;  
  
        --Delete any security assignments  
        DECLARE     @Object_ID    INT;  
        SELECT      @Object_ID = mdm.udfSecurityObjectIDGetByCode(N'HIRSTD');  
        EXEC mdm.udpSecurityPrivilegesDelete NULL, NULL, @Object_ID, @Hierarchy_ID;  
        DELETE FROM mdm.tblSecurityRoleAccessMember WHERE HierarchyType_ID = 0 AND Hierarchy_ID = @Hierarchy_ID;  
  
        --Check to see if this is the last hierarchy for entity if so delete tables, views, and update mdm.tblentity  
        --Per check above we know the hierarchy belongs to the entity.  
        IF (SELECT COUNT(*) FROM mdm.tblHierarchy WHERE Entity_ID = @Entity_ID) = 1 BEGIN  
  
                --Drop the FK from the HP - Really only need the one to the MS table but going to drop them all  
                INSERT INTO @TableFKConstraints  
                            SELECT  schema_name(schema_id) + '.[' + object_name(parent_object_id)+ ']',  
                                    s.[name]  
                            FROM sys.foreign_keys s  
                            WHERE referenced_object_id = object_id('mdm.' + '[' + @HierarchyParentTable + ']');  
                -- Delete all the constraints first  
                DECLARE @Counter INT = 1 ;  
                DECLARE @MaxCounter INT = (SELECT MAX(ID) FROM @TableFKConstraints);  
                SET @Counter =1;  
                SET @SQL = '';  
                WHILE @Counter <= @MaxCounter  
                BEGIN  
                    SELECT @TempID = ID, @TempTableName = TableName, @ConstraintName = ConstraintName   
                        FROM @TableFKConstraints WHERE ID = @Counter;  
  
                    SET @SQL = @SQL + N'ALTER TABLE ' + @TempTableName +   
                                ' DROP CONSTRAINT ' + @ConstraintName + N';'  
  
                    SET @Counter = @Counter +1;  
                END  
                EXEC sp_executesql @SQL;  
                  
                --Drop tables  
                SET @SQL = N'  
                    DROP TABLE mdm.' + quotename(@CollectionMemberTable) + N';  
                    DROP TABLE mdm.' + quotename(@HierarchyTable) + N';  
                    DROP TABLE mdm.' + quotename(@HierarchyParentTable) + N';  
                    DROP TABLE mdm.' + quotename(@CollectionTable) + N';';  
                EXEC sp_executesql @SQL;  
                  
                --If @StagingBase is specified, drop entity based staging tables and delete staging Sprocs.  
                IF COALESCE(@StagingBase, N'') <> N'' BEGIN  
  
                    SET @SQL = N'    
                        DROP TABLE stg.' + quotename(@StagingConsolidatedTable) + N';      
                        DROP TABLE stg.' + quotename(@StagingRelationshipTable) + N';';    
                            
                    EXEC sp_executesql @SQL;  
                      
                    --Delete Staging Sprocs  
                    Exec mdm.udpEntityStagingDeleteStoredProcedures @Entity_ID, @ConsolidatedAndRelationship -- Drop consolidated and relationship Sprocs.   
                      
                END; --IF  
                  
                --Delete views  
                EXEC mdm.udpDeleteViews @Entity_ID, 3;  
  
                --Delete attributes  
                DELETE FROM mdm.tblAttribute WHERE Entity_ID = @Entity_ID AND MemberType_ID <> 1;  
  
                --Update entity  
                UPDATE  
                    mdm.tblEntity  
                SET  
                    IsFlat = 1,  
                    --Unassign table names  
                    HierarchyTable = NULL,  
                    HierarchyParentTable = NULL,  
                    CollectionTable = NULL,  
                    CollectionMemberTable = NULL,  
                    --Audit changes  
                    LastChgDTM = GETUTCDATE(),  
                    LastChgUserID = @User_ID,  
                    LastChgVersionID = @Version_ID  
                WHERE  
                    ID = @Entity_ID;  
                  
                --Recreate leaf staging SProc when HP table is deleted.  
                Exec mdm.udpEntityStagingCreateLeafStoredProcedure @Entity_ID = @Entity_ID;  
                      
                --Recreate views for the now-flattened entity  
                EXEC mdm.udpCreateViews @Model_ID = @Model_ID, @NewItem = @Entity_ID;  
                EXEC mdm.udpCreateEntityStagingErrorDetailViews @Entity_ID = @Entity_ID;  
                              
                --Put a msg onto the SB queue to process member security  
                EXEC mdm.udpSecurityMemberQueueSave   
                    @Role_ID    = NULL,-- update member count cache for all users  
                    @Version_ID = @Version_ID,   
                    @Entity_ID  = @Entity_ID;  
  
        END ELSE BEGIN   
  
            --Delete The Records  
            SET @SQL = N'  
                DELETE FROM mdm.' + quotename(@CollectionMemberTable) + N'   
                WHERE ID IN (  
                    SELECT CMT.ID FROM mdm.' + quotename(@CollectionMemberTable) + N' AS CMT' + N'               
                    WHERE EXISTS (  
                        SELECT 1 FROM mdm.' + quotename(@HierarchyTable) + N' AS HRT   
                        WHERE HRT.Hierarchy_ID = @Hierarchy_ID   
                            AND CMT.ChildType_ID = HRT.ChildType_ID  
                            AND ((CMT.ChildType_ID = 1 AND CMT.Child_EN_ID = HRT.Child_EN_ID)  
                                OR (CMT.ChildType_ID = 2 AND CMT.Child_HP_ID = HRT.Child_HP_ID))  
                    ) AND NOT EXISTS (  
                        SELECT 1 FROM mdm.' + quotename(@HierarchyTable) + N' AS HRT2  
                        WHERE HRT2.Hierarchy_ID <> @Hierarchy_ID  
                            AND CMT.ChildType_ID = HRT2.ChildType_ID  
                            AND ((CMT.ChildType_ID = 1 AND CMT.Child_EN_ID = HRT2.Child_EN_ID)  
                                OR (CMT.ChildType_ID = 2 AND CMT.Child_HP_ID = HRT2.Child_HP_ID))  
                    ));  
                DELETE FROM mdm.' + quotename(@HierarchyTable) + N'   
                    WHERE Hierarchy_ID = @Hierarchy_ID;  
                DELETE FROM mdm.' + quotename(@HierarchyParentTable) + N'   
                    WHERE Hierarchy_ID = @Hierarchy_ID;';  
  
            EXEC sp_executesql @SQL, N'@Hierarchy_ID INT', @Hierarchy_ID;  
  
        END; --if  
  
        --Delete the hierarchy record  
        DELETE FROM mdm.tblHierarchy WHERE ID = @Hierarchy_ID;  
  
        --Delete associated user-defined metadata  
        EXEC mdm.udpUserDefinedMetadataDelete @Object_Type = N'Hierarchy', @Object_ID = @HierarchyMUID  
  
        SELECT COUNT(*) AS HierarchyCount FROM mdm.tblHierarchy WHERE Entity_ID = @Entity_ID;  
  
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
  
        --On error, return NULL results  
        SELECT NULL AS HierarchyCount;  
        RETURN(1);  
  
    END CATCH;  
  
  
    SET NOCOUNT OFF;  
END; --proc
GO
