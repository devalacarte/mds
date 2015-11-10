SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpSystemEventSave 2, 1, N'ValidateModel', 2;  
    SELECT * FROM mdm.tblEvent;  
*/  
CREATE PROCEDURE [mdm].[udpSystemEventSave]  
(  
    @User_ID		INT,  
    @Version_ID		INT,  
    @EventName		NVARCHAR(100),  
    @EventStatus_ID	TINYINT  
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
      
        DECLARE @UpdateCount INT; --Instead of doing a complex IF EXISTS(), just try UPDATE and check if any rows were affected  
        UPDATE mdm.tblEvent SET  
            EventStatus_ID = ISNULL(@EventStatus_ID, EventStatus_ID),  
            LastChgUserID = @User_ID,  
            LastChgDTM = GETUTCDATE()  
        WHERE   
            EventName = @EventName AND   
            (  
                (@Version_ID IS NULL) --Show all rows  
                OR (@Version_ID = 0 AND Version_ID IS NULL) --Show just the rows with NULL Version_ID  
                OR (Version_ID = @Version_ID) --Show just the rows with the specified Version_ID  
            );  
        SET @UpdateCount = @@ROWCOUNT; --This statement must be IMMEDIATELY after UPDATE clause  
                  
        IF @UpdateCount = 0 BEGIN --If no rows were updated, INSERT the value instead  
  
            INSERT INTO mdm.tblEvent  
            (  
                Version_ID,  
                EventName,  
                EventStatus_ID,  
                EnterUserID,  
                LastChgUserID  
            )  
            VALUES  
            (  
                NULLIF(@Version_ID, 0), --0 is used as a magic token to represent 'row has not Version context'  
                @EventName,  
                @EventStatus_ID,  
                @User_ID,  
                @User_ID		  
            );  
              
        END; --if  
  
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
        --SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
