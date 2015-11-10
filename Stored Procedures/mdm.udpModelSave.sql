SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    --Create new Model  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpModelSave 1, NULL, 'test', 1, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblModel WHERE ID = @Return_ID;  
  
    --Update existing Entity  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpModelSave 1, 100, 'test1',  @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblModel WHERE ID = @Return_ID;  
  
    --Invalid parameters  
    EXEC mdm.udpModelSave 99999, NULL, 'test11';  
    EXEC mdm.udpModelSave 99999, 1, 'test11';  
    EXEC mdm.udpModelSave 1, 99999, 'test11';  
*/  
CREATE PROCEDURE [mdm].[udpModelSave]  
(  
    @User_ID		INT,  
    @Model_ID		INT = NULL,  
    @ModelName		NVARCHAR(50),  
    @IsSystem		BIT = 0,  
    @Return_ID		INT = NULL OUTPUT,  
    @Return_MUID	UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @TempDescription	NVARCHAR(250),  
            @CurrentDTM			DATETIME2(3);  
  
    --Initialize output parameters and local variables  
    SELECT   
        @ModelName = NULLIF(LTRIM(RTRIM(@ModelName)), N''),  
        @Return_ID = NULL,   
        @CurrentDTM = GETUTCDATE(),  
        @IsSystem = ISNULL(@IsSystem,0);  
  
    --Test for invalid parameters  
    IF (@Model_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModel WHERE ID = @Model_ID)) --Invalid Model_ID  
        OR NOT EXISTS(SELECT ID FROM mdm.tblUser WHERE ID = @User_ID) --Invalid @User_ID  
    BEGIN  
        --On error, return NULL results  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
  
    DECLARE @ModelNameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @ModelName, @ModelNameHasReservedCharacters OUTPUT;  
    IF @ModelNameHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100054|The model cannot be created because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        IF @Model_ID IS NOT NULL BEGIN --Update Model  
  
                --First delete existing views since we will need to rebuild them after  
                EXEC mdm.udpDeleteViews @Model_ID;  
  
                --Update details in Model table  
                UPDATE mdm.tblModel SET  
                    [Name] = ISNULL(@ModelName, [Name]),  
                    LastChgUserID = @User_ID,  
                    LastChgDTM = @CurrentDTM  
                WHERE  
                    ID = @Model_ID;  
  
                --Populate output parameters  
                SELECT @Return_MUID = MUID FROM mdm.tblModel WHERE ID = @Model_ID;  
  
        END ELSE BEGIN --New Model  
  
            --Accept an explicit MUID (for clone operations) or generate a new one  
            SET @Return_MUID =  ISNULL(@Return_MUID, NEWID());  
  
            --Insert details into Model table  
            INSERT INTO mdm.tblModel  
            (  
                [Name],   
                MUID,   
                IsSystem,  
                EnterUserID,  
                LastChgUserID  
            ) VALUES (  
                @ModelName,   
                @Return_MUID,   
                @IsSystem,  
                @User_ID,  
                @User_ID  
            );  
  
            --Save the identity value  
            SET @Model_ID = SCOPE_IDENTITY();  
  
            --Create the initial version  
            SET @TempDescription = LEFT(N'Version 1 for Model: ' + @ModelName, 250);  
            EXEC mdm.udpVersionSave @User_ID, @Model_ID, NULL, 0, 1, N'VERSION_1', @TempDescription, NULL;  
              
            DECLARE @ModelMetadataCode NVARCHAR(250);  
            SET @ModelMetadataCode = CONVERT(NVARCHAR(20), @Model_ID);  
            --Create related metadata member  
            IF (@IsSystem = 0) EXEC mdm.udpUserDefinedMetadataSave N'Model', @Return_MUID, @ModelName, @ModelMetadataCode , @User_ID  
      
            --Assign update privileges to the user  
            EXEC mdm.udpSecurityPrivilegesSave @User_ID, @User_ID, 1, NULL, N'User', NULL, 1, 2, @Model_ID, @Model_ID, @ModelName, Null;  
  
        END; --if  
      
        --Recreate the views  
        EXEC mdm.udpCreateViews @Model_ID;  
  
        --Return values  
        SET @Return_ID = @Model_ID;  
  
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
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
