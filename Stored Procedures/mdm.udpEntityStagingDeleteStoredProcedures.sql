SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpEntityStagingDeleteStoredProcedures]  
(    
    @Entity_ID INT,  
    @ProcedureType INT  
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
    
        DECLARE @SQL                            NVARCHAR(MAX),  
                @IsFlat                         BIT,  
                @LeafSproc                      sysname,  
                @ConsolidatedSproc              sysname,  
                @RelationshipSproc              sysname,  
                -- Types of staging procedures to delete.      
                @AllTypes                       INT = 0,    
                @Leaf                           INT = 1,      
                @Consolidated                   INT = 2,  
                @ConsolidatedAndRelationship    INT = 3,      
                @Relationship                   INT = 4;   
  
        --Set variables.    
        SET @SQL = N'';  
          
        SELECT  
            @IsFlat = IsFlat,        
            @LeafSproc = N'stg.[udp_' + StagingBase + N'_Leaf]',  
            @ConsolidatedSproc = N'stg.[udp_' + StagingBase + N'_Consolidated]',  
            @RelationshipSproc = N'stg.[udp_' + StagingBase + N'_Relationship]'  
        FROM     
            mdm.tblEntity WHERE ID = @Entity_ID;  
                      
        IF @ProcedureType = @Leaf OR @ProcedureType = @AllTypes  
        BEGIN  
            --Drop Leaf Entity Based Staging Procedure  
            SET @SQL = @SQL + N'   
          
            IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @LeafSproc + N''') AND type in (N''P'', N''PC''))  
            DROP PROCEDURE ' + @LeafSproc + N';'   
  
        END; -- IF  
          
          
        --Drop Consolidated Entity Based Staging Procedure if the entity in not flat  
        IF @IsFlat = 0 BEGIN  
            IF @ProcedureType IN (@AllTypes, @Consolidated, @ConsolidatedAndRelationship)   
            BEGIN   
                --Drop Consolidated Staging Procedure.  
                SET @SQL = @SQL + N'   
                IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @ConsolidatedSproc + N''') AND type in (N''P'', N''PC''))  
                DROP PROCEDURE ' + @ConsolidatedSproc + N';'  
            END; --IF  
           
            IF @ProcedureType IN (@AllTypes, @ConsolidatedAndRelationship, @Relationship)  
            BEGIN  
                -- Drop Relationship Staging Procedure.  
                SET @SQL = @SQL + N'   
                IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'''+ @RelationshipSproc + N''') AND type in (N''P'', N''PC''))  
                DROP PROCEDURE ' + @RelationshipSproc + N';'  
            END; --IF  
        END --IF   
  
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
