SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
When called from within a CATCH block, gets info about the error that can be   
then used to re-raise the error from within the CATCH block. If the original error   
number is a system error (not a custom MDS error) then the system error  
number will be added to the beginning of the error message with a "SYSERR" prefix  
to distinguish it from the "MDSERR" prefix used for custom errors. Otherwise, the  
original error number would be lost because when the error message is re-raised,  
error number 50000 is used.  
  
Example:  
    BEGIN TRY  
        DECLARE @temp INT = 1/0; -- Causes divide by zero error  
    END TRY  
    BEGIN CATCH  
        DECLARE  
            @ErrorMessage NVARCHAR(4000),  
            @ErrorSeverity INT,  
            @ErrorState INT;  
  
        EXEC mdm.udpGetErrorInfo  
            @ErrorMessage = @ErrorMessage OUTPUT,  
            @ErrorSeverity = @ErrorSeverity OUTPUT,  
            @ErrorState = @ErrorState OUTPUT;  
        
        RAISERROR (@ErrorMessage,  @ErrorSeverity, @ErrorState); -- Re-raise the error, with the original error number at the beginning of the error message.  
        -- Yields:  
        --      "Msg 50000, Level 16, State 1, Line 15  
        --      SYSERR8134|Divide by zero error encountered."  
    END CATCH  
*/  
CREATE PROCEDURE [mdm].[udpGetErrorInfo]  
(  
    @ErrorMessage NVARCHAR(4000) = NULL OUTPUT,  
    @ErrorSeverity INT = NULL OUTPUT,  
    @ErrorState INT = NULL OUTPUT,  
    @ErrorNumber INT = NULL OUTPUT,  
    @ErrorLine INT = NULL OUTPUT,  
    @ErrorProcedure NVARCHAR(126) = NULL OUTPUT  
)  
AS  
BEGIN  
    SELECT  
        @ErrorMessage = ERROR_MESSAGE(),  
        @ErrorSeverity = ERROR_SEVERITY(),  
        @ErrorState = ERROR_STATE(),  
        @ErrorNumber = ERROR_NUMBER(), -- Note that @@Error will not work here as a replacement for ERROR_NUMBER().  
        @ErrorLine = ERROR_LINE(),  
        @ErrorProcedure = ERROR_PROCEDURE();  
          
    -- If a system error occurred, preserve the original error number by adding it to the front of the error message.  
    IF @ErrorNumber < 50000  
    BEGIN  
        SET @ErrorMessage = N'SYSERR' + COALESCE(CONVERT(NVARCHAR, @ErrorNumber), N'') + N'|' + COALESCE(@ErrorMessage, N'');  
    END;  
END;
GO
