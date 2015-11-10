SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpTransactionAnnotationSave]  
(  
   @User_ID				INT,  
   @Transaction_ID		INT,  
   @Comment				NVARCHAR(500),  
   @Return_ID			INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @ID AS INT,  
            @CurrentDTM AS DATETIME2(3);  
  
    --Initialize local variables  
    SELECT   
        @CurrentDTM = GETUTCDATE();  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION AnnotationSave;   
          
    BEGIN TRY  
  
    --Test for invalid parameters  
        IF NOT EXISTS(SELECT ID FROM mdm.tblUser WHERE ID = @User_ID) --Invalid @User_ID  
        BEGIN  
            RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
            RETURN(1);  
        END; --if  
  
        BEGIN  
            --Insert the Annotation comment  
            INSERT INTO mdm.tblTransactionAnnotation(  
                 [Transaction_ID]  
                ,[EnterDTM]  
                ,[EnterUserID]  
                ,[LastChgDTM]  
                ,[LastChgUserID]  
                ,[Comment]  
            ) SELECT   
                @Transaction_ID,  
                @CurrentDTM,  
                @User_ID,  
                @CurrentDTM,  
                @User_ID,  
                @Comment  
  
            --Save the identity value  
            SET @ID = SCOPE_IDENTITY();  
  
            --Return values  
            SET @Return_ID = @ID;  
              
            --Commit only if we are not nested  
            IF @TranCounter = 0 COMMIT TRANSACTION AnnotationSave;  
            RETURN(0);  
        END;  
          
    END TRY  
    --Handle exceptions  
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
  
        --Rollback appropriate transaction   
        IF @TranCounter = 0 ROLLBACK TRANSACTION AnnotationSave;  
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);		  
  
        --On error, return NULL results  
        SELECT @Return_ID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
