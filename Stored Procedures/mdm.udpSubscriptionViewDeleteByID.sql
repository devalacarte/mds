SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpSubscriptionViewDeleteByID 1, 0;  
*/  
CREATE PROCEDURE [mdm].[udpSubscriptionViewDeleteByID]  
(  
    @ID	INT,  
    @DeleteView bit = 0  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    ----Test for invalid parameters  
    IF (@ID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM mdm.tblSubscriptionView  WHERE ID = @ID)   
        OR @ID IS NULL ) --Invalid ID  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
          
        DECLARE @ViewName NVARCHAR(50),  
                @SQL	  NVARCHAR(MAX)  
                  
        -- Get the name of the view  
        SELECT @ViewName = V.[Name]  
        FROM mdm.tblSubscriptionView V  
        WHERE V.ID = @ID  
          
        SET @SQL = CAST('' AS NVARCHAR(max));  
  
        IF (@ViewName IS NOT NULL)  
         BEGIN  
            SET @SQL =  N'IF EXISTS(SELECT 1 FROM sys.views WHERE [name] = N''' + @ViewName + N''' AND [schema_id] = SCHEMA_ID(''mdm''))   
                DROP VIEW mdm.' + QuoteName(@ViewName) + N';';  
              
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL;  
  
        END; --while  
  
        -- Delete view if flag set true  
        IF (@DeleteView = 1)  
            DELETE FROM mdm.tblSubscriptionView  WHERE ID = @ID;  
                  
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
END;
GO
