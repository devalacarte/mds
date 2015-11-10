SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
exec mdm.udpUserPreferenceSave 1, 'Model', 7  
exec mdm.udpUserPreferenceSave 1, 'Entity', 32  
exec mdm.udpUserPreferenceSave 1, 'Version', 20  
exec mdm.udpUserPreferenceSave 1, 'MemberType', 1  
exec mdm.udpUserPreferenceSave 1, 'DBADisplayType', 1  
exec mdm.udpUserPreferenceSave 1, 'User-Defined 1', 'ABCDEFGH1234567890'  
*/  
CREATE PROCEDURE [mdm].[udpUserPreferenceSave]  
(  
    @User_ID			INT,  
    @PreferenceName		NVARCHAR(100),  
    @PreferenceValue	NVARCHAR(MAX)  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    BEGIN TRY  
  
        IF EXISTS(SELECT 1 FROM mdm.tblUserPreference WHERE PreferenceName = @PreferenceName AND User_ID = @User_ID) BEGIN  
  
            UPDATE mdm.tblUserPreference SET   
                PreferenceName = ISNULL(@PreferenceName,PreferenceName),  
                PreferenceValue = ISNULL(@PreferenceValue,PreferenceValue),  
                LastChgUserID = @User_ID,  
                LastChgDTM = GETUTCDATE()  
            WHERE   
                PreferenceName = @PreferenceName AND   
                [User_ID] = @User_ID;  
  
        END	ELSE BEGIN  
  
            INSERT INTO mdm.tblUserPreference(  
                [User_ID],  
                PreferenceName,  
                PreferenceValue,  
                EnterUserID,  
                EnterDTM,  
                LastChgUserID,  
                LastChgDTM  
            ) VALUES (  
                @User_ID,  
                @PreferenceName,  
                @PreferenceValue,  
                @User_ID,  
                GETUTCDATE(),  
                @User_ID,  
                GETUTCDATE()			  
            );  
        END; --if  
  
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
