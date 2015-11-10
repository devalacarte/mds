SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpEntityDelete 1;  
    select * from mdm.tblEntity;  
*/  
CREATE PROCEDURE [mdm].[udpEntityDelete]  
(  
    @Entity_ID		INTEGER,  
    @CreateViewsInd	BIT = NULL --1=Create,0=DoNot Create  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        DECLARE @SQL       	NVARCHAR(MAX),  
                @IsSystem				BIT,  
                @Model_ID				INT,  
                @Entity_MUID			UNIQUEIDENTIFIER;  
  
        SET @CreateViewsInd = ISNULL(@CreateViewsInd, 1);  
  
        SELECT   
        @IsSystem = IsSystem  
        , @Model_ID = Model_ID  
        , @Entity_MUID = MUID		   
        FROM mdm.tblEntity  
        WHERE ID = @Entity_ID;  
  
        --Check for system entity. If system entity, prevent deletion by raising error.         
        IF(@IsSystem = 1)  
        BEGIN  
            RAISERROR('MDSERR100042|A system entity cannot be deleted.', 16, 1);  
        END;  
  
  
    --Delete the views  
    EXEC mdm.udpDeleteEntityStagingErrorDetailViews @Entity_ID;  
    EXEC mdm.udpDeleteViews @Model_ID;  
  
        --Delete all the entity related data  
        DECLARE	@Object_ID	INT;  
        SET @Object_ID = mdm.udfSecurityObjectIDGetByCode(N'DIMENT');  
          
  
    --Delete the subscription views associated with the entity  
    EXEC mdm.udpSubscriptionViewsDelete   
        @Model_ID               = NULL,  
        @Version_ID             = NULL,  
        @Entity_ID	            = @Entity_ID,  
        @DerivedHierarchy_ID    = NULL;  
  
        --Delete the security maps  
        --EXEC mdm.udpHierarchyMapDelete @Entity_ID = @Entity_ID;  
        --DELETE hmq   
        --FROM mdm.tblHierarchyMapQueue hmq  
        --INNER JOIN mdm.tblHierarchy h  
        --    ON h.ID = hmq.Hierarchy_ID   
        --    AND hmq.HierarchyType_ID = 0 -- explicit hierarchies only  
        --    AND h.Entity_ID =@Entity_ID  
          
    DELETE FROM mdm.tblSecurityRoleAccessMember WHERE Entity_ID =@Entity_ID;  
  
        DECLARE @TempTable TABLE (  
            RowNumber INT IDENTITY (1, 1) PRIMARY KEY CLUSTERED NOT NULL   
            , Attribute_ID INT NOT NULL  
            , Entity_ID INT NOT NULL  
            , MemberType_ID INT NOT NULL);  
          
          
        --Get all related Domain Entity into temp table  
        INSERT INTO @TempTable   
        SELECT ID, Entity_ID, MemberType_ID FROM mdm.tblAttribute   
        WHERE DomainEntity_ID = @Entity_ID;  
          
        DECLARE @TempAttribute_ID INT;  
        DECLARE @TempEntity_ID INT;  
        DECLARE @TempMemberType_ID INT;  
        DECLARE @Counter INT = 1;   
        DECLARE @MaxCounter INT = (SELECT MAX(RowNumber) FROM @TempTable);  
      
        --Delete all related data for the Entity being referenced by the Domain Entity records  
        -- and delete the domain Entity attribute record  
        WHILE @Counter <= @MaxCounter  
            BEGIN  
            SELECT @TempEntity_ID = Entity_ID,  
                @TempAttribute_ID = Attribute_ID,  
                @TempMemberType_ID = MemberType_ID   
            FROM @TempTable WHERE [RowNumber] = @Counter ;  
              
            --Delete any annotations for the entity.  
            DELETE ta  
            FROM mdm.tblTransactionAnnotation ta  
            INNER JOIN mdm.tblTransaction t  
                ON t.ID = ta.Transaction_ID  
            WHERE t.Entity_ID = @TempEntity_ID;  
  
            --Delete the transaction table for the Entity being referenced by the Domain Entity  
            DELETE FROM mdm.tblTransaction WHERE Entity_ID = @TempEntity_ID;  
  
            --Delete related meta data tables for the Entity being referenced by the Domain Entity  
            EXEC mdm.udpEntityMetaTablesDelete @TempEntity_ID;  
  
            --Delete related hierarchy table for the Entity being referenced by the Domain Entity  
            DELETE FROM mdm.tblHierarchy WHERE Entity_ID = @TempEntity_ID;  
          
            --Delete the attribute for the Domain Entity record  
            EXEC mdm.udpAttributeDelete @TempAttribute_ID, @TempMemberType_ID, @CreateViewsInd;  
  
            SET @Counter = @Counter+1  
  
        END; --while  
          
        --Delete the related transaction annotation records  
        DELETE ta  
            FROM mdm.tblTransactionAnnotation ta  
            INNER JOIN mdm.tblTransaction t  
                ON t.ID = ta.Transaction_ID  
            WHERE t.Entity_ID = @Entity_ID  
                  
        --Delete the transaction table first  
        DELETE FROM mdm.tblTransaction WHERE Entity_ID = @Entity_ID;  
  
        --Delete related meta data tables referencing the Entity including staging tables.  
        EXEC mdm.udpEntityMetaTablesDelete @Entity_ID;  
  
        DECLARE @DeletedChildObjects TABLE   
        (     
             MUID       UNIQUEIDENTIFIER PRIMARY KEY  
            ,Object_Type NVARCHAR(50)  
        );  
  
        --Delete the hierarchy referencing the Entity  
        DELETE FROM mdm.tblHierarchy   
        OUTPUT deleted.MUID, N'Hierarchy'  
        INTO @DeletedChildObjects  
        WHERE Entity_ID = @Entity_ID;  
          
        --Delete the tblAttributeGroupDetail records before we can delete  
        --the tblAttributeGroup records  
        DELETE FROM mdm.tblAttributeGroupDetail   
        FROM mdm.tblAttributeGroupDetail gt  
                INNER JOIN mdm.tblAttributeGroup g  
                 ON gt.AttributeGroup_ID = g.ID   
                WHERE g.Entity_ID = @Entity_ID;  
  
        --Delete the tblAttributeGroup records that reference the Entity  
        DELETE FROM mdm.tblAttributeGroup   
        OUTPUT deleted.MUID, N'AttributeGroup'  
        INTO @DeletedChildObjects  
        WHERE Entity_ID = @Entity_ID;  
  
        --Delete the attribute for the entity  
        DELETE FROM mdm.tblAttribute   
        OUTPUT deleted.MUID, N'Attribute'  
        INTO @DeletedChildObjects  
        WHERE Entity_ID = @Entity_ID;  
  
        --Delete from the recordcount table if any exists  
        DELETE FROM mdm.tblUserMemberCount WHERE Entity_ID = @Entity_ID;  
          
        --Delete Entity Based Staging Stored Procedures.  
        --Delete all types (0). Delete Leaf staging SProc. Then, if the entity is not flat delete Parent and Relation staging SProcs.  
        Exec mdm.udpEntityStagingDeleteStoredProcedures @Entity_ID, 0     
          
        --Delete the record(s) for the entity from staging batch table.  
        DELETE FROM mdm.tblStgBatch WHERE Entity_ID = @Entity_ID;  
  
        --Delete code generation information  
        DELETE FROM mdm.tblCodeGenInfo WHERE EntityId = @Entity_ID;  
          
        DELETE FROM mdm.tblEntity WHERE ID = @Entity_ID;  
        EXEC mdm.udpSecurityPrivilegesDelete NULL, NULL, @Object_ID, @Entity_ID;  
  
        SELECT	@Object_ID = mdm.udfSecurityObjectIDGetByCode(N'DIMATT');  
        DELETE sa  
        FROM mdm.tblSecurityRoleAccess sa  
        INNER JOIN mdm.tblAttribute a  
        ON   
            sa.Securable_ID = a.ID  
            AND a.Entity_ID = @Entity_ID  
        WHERE	  
            sa.[Object_ID] = @Object_ID   
      
        DELETE FROM mdm.tblValidationLog WHERE Entity_ID = @Entity_ID;  
          
        --Delete associated user-defined metadata if the entity doesn't belong to a system model (metadata).  
        IF EXISTS(SELECT 1 FROM mdm.tblModel WHERE ID = @Model_ID AND IsSystem = 0) BEGIN  
            EXEC mdm.udpUserDefinedMetadataDelete @Object_Type = N'Entity', @Object_ID = @Entity_MUID  
  
            DECLARE   
                 @DeletedMuid UNIQUEIDENTIFIER  
                ,@Object_Type NVARCHAR(50);  
  
            -- Delete the child object metadata.  
            WHILE EXISTS (SELECT 1 FROM @DeletedChildObjects)  
            BEGIN  
                SELECT TOP 1  
                     @DeletedMuid = MUID  
                    ,@Object_Type = Object_Type  
                FROM @DeletedChildObjects;  
  
                DELETE FROM @DeletedChildObjects WHERE MUID = @DeletedMuid;  
  
                EXEC mdm.udpUserDefinedMetadataDelete @Object_Type = @Object_Type, @Object_ID = @DeletedMuid;  
            END;  
        END; -- if  
                          
        --Create Views  
        IF @CreateViewsInd = 1 EXEC mdm.udpCreateViews @Model_ID;  
  
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
        --SELECT @Return_ID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
