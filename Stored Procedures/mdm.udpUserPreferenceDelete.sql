SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
exec mdm.udpUserPreferenceDelete 1, 'Model'  
*/  
CREATE PROCEDURE [mdm].[udpUserPreferenceDelete]  
(  
    @User_ID			INT,  
    @PreferenceName		NVARCHAR(100)  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    BEGIN TRY  
  
        DELETE FROM mdm.tblUserPreference  
        WHERE   
            [User_ID] = @User_ID AND  
            PreferenceName = @PreferenceName   
            ;  
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
  
        --IF @TranCounter = 0 ROLLBACK TRANSACTION;  
        --ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
  
        --On error, return NULL results  
        --SELECT @Return_ID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
