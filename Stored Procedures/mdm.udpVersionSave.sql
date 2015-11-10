SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    --Create Version  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpVersionSave 1, 7, NULL, 0, 1, N'VERSION_1', N'blah', 14, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblModelVersion WHERE ID = @Return_ID;  
  
    --Update existing Version  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpVersionSave 1, 7, 20, NULL, NULL, 'Version 3 [TEST]', 'Product Model model - scenario 2 [TEST]', 14, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblModelVersion WHERE ID = @Return_ID;  
  
    --Update existing Version, change status  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpVersionSave 1, 7, 20, NULL, 1, NULL, NULL, 14, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblModelVersion WHERE ID = @Return_ID;  
  
    --Update existing Version, clear VersionFlag  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpVersionSave 1, 7, 20, NULL, NULL, 'Version 3 [TEST]', 'Product Model model - scenario 2 [TEST]', 0, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblModelVersion WHERE ID = @Return_ID;  
*/  
CREATE PROCEDURE [mdm].[udpVersionSave]  
(  
    @User_ID			INT,  
    @Model_ID			INT,  
    @Version_ID			INT = NULL,  
    @CurrentVersion_ID  INT = NULL,  
    @Status_ID			INT = NULL,  
    @Name				NVARCHAR(50) = NULL,  
    @Description		NVARCHAR(500) = NULL,  
    @VersionFlag_ID		INT = NULL,  
    @Return_ID			INT = NULL OUTPUT,  
    @Return_MUID		UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
            @CurrentVersionID INT,  
            @CurrentDTM	DATETIME2(3),  
            @ErrorMsg NVARCHAR(MAX),  
            @IsValidated BIT;  
  
    --Initialize output parameters and local variables  
    SELECT  
        @Name = LTRIM(RTRIM(@Name)),   
        @Description = LTRIM(RTRIM(@Description)),  
        @Return_ID = NULL,   
        @CurrentDTM = GETUTCDATE()--,  
        --@VersionFlag_ID = NULLIF(@VersionFlag_ID, 0); --0 is a magic number  
  
    --Test for invalid parameters  
    IF (@Status_ID < 1 OR @Status_ID > 3)  
        OR (NOT EXISTS(SELECT ID FROM mdm.tblModel WHERE ID = @Model_ID)) --Invalid Model_ID  
        OR (@Version_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModelVersion WHERE ID = @Version_ID)) --Invalid Model_ID  
        --OR (@VersionFlag_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModelVersionFlag WHERE ID = @VersionFlag_ID)) --Invalid VersionFlag_ID  
        OR NOT EXISTS(SELECT ID FROM mdm.tblUser WHERE ID = @User_ID) --Invalid @User_ID  
    BEGIN  
        --On error, return NULL results  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
  
  
    --Determine if the current version status is committed.  
    IF EXISTS(SELECT 1 FROM mdm.tblModelVersion WHERE ID = @Version_ID AND Status_ID = 3)   
    BEGIN  
        -- The current status is committed.  Cannot change status.  
        IF @Status_ID IS NOT NULL AND ISNULL(@Status_ID, 0) <> 3  
            BEGIN  
                --On error, return NULL results  
                SELECT @Return_ID = NULL, @Return_MUID = NULL;  
                RAISERROR('MDSERR200064|The version cannot be saved. The status of committed versions cannot be changed.', 16, 1);  
                RETURN;  
            END  
    END  
    ELSE   
    BEGIN  
        IF ISNULL(@VersionFlag_ID, 0) <> 0  
            BEGIN  
                -- Current status is not committed.    
                --Verify VersionFlag is valid  
                IF EXISTS(SELECT 1 FROM mdm.tblModelVersionFlag WHERE ID = @VersionFlag_ID AND CommittedOnly_ID = 1) AND (@Status_ID <> 3)   
                    BEGIN  
                        --On error, return NULL results  
                        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
                        RAISERROR('MDSERR200065|The version cannot be saved. The version is not committed and the version flag can be used for committed versions only.', 16, 1);  
                        RETURN;  
                    END  
  
                --If trying to commit the version, make sure the version has been validated     
                IF ISNULL(@Status_ID, 0) = 3  
                    BEGIN  
                       EXECUTE mdm.udpVersionValidationStatusGet @Version_ID, @IsValidated OUTPUT  
                       IF @IsValidated <> 1  
                        BEGIN  
                            --On error, return NULL results  
                            SELECT @Return_ID = NULL, @Return_MUID = NULL;  
                            RAISERROR('MDSERR200071|The version cannot be saved because it has not been validated.', 16, 1);  
                            RETURN;  
                        END  
                    END  
            END  
    END  
  
    DECLARE @NameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @Name, @NameHasReservedCharacters OUTPUT;  
    IF @NameHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100055|The version cannot be created because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    DECLARE @DescriptionHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @Description, @DescriptionHasReservedCharacters OUTPUT;  
    IF @DescriptionHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100055|The version cannot be created because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        -- If VersionFlag is associated with another version, remove it from that version.  
        IF (EXISTS (SELECT 1 FROM mdm.tblModelVersion WHERE VersionFlag_ID = @VersionFlag_ID AND (@Version_ID IS NULL OR ID <> @Version_ID)))  
            BEGIN  
                UPDATE mdm.tblModelVersion   
                SET VersionFlag_ID = NULL   
                WHERE VersionFlag_ID = @VersionFlag_ID  
                AND ID <> @Version_ID  
            END  
                      
        IF (@Version_ID IS NOT NULL) BEGIN --Update Version  
            --Capture the prior status to determine if a version status change notification needs to be sent.  
            DECLARE @PriorStatus_ID INT = (SELECT Status_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID);  
              
            --Update details in the Version table  
                UPDATE mdm.tblModelVersion   
                SET  
                     Status_ID = ISNULL(@Status_ID, Status_ID)  
                    ,[Name] = ISNULL(@Name, [Name])  
                    ,[Description] = ISNULL(@Description, [Description])  
                    ,VersionFlag_ID = @VersionFlag_ID  
                    ,LastChgDTM = @CurrentDTM  
                    ,LastChgUserID = @User_ID  
                WHERE  
                    ID = @Version_ID;  
  
            IF (@Status_ID IS NOT NULL) BEGIN  
                IF (@Status_ID <> @PriorStatus_ID) BEGIN  
                    -- Create a version status change notification  
                 EXEC mdm.udpNotificationCreateVersionStatusChange @User_ID=@User_ID, @Version_ID=@Version_ID, @PriorStatus_ID=@PriorStatus_ID;  
                END  
            END  
              
            --Populate output parameters  
            SELECT @Return_MUID = MUID FROM mdm.tblModelVersion WHERE ID = @Version_ID;  
  
            --Archive validation log issues  
            IF @Status_ID = 3 BEGIN  
      
                INSERT INTO mdm.tblValidationLogHistory  
                SELECT	ID  
                    ,Status_ID  
                    ,Version_ID  
                    ,Hierarchy_ID  
                    ,Entity_ID  
                    ,Member_ID  
                    ,MemberCode  
                    ,MemberType_ID  
                    ,[Description]  
                    ,BRBusinessRule_ID  
                    ,BRItem_ID  
                    ,NotificationStatus_ID  
                    ,EnterDTM  
                    ,EnterUserID  
                    ,LastChgDTM  
                    ,LastChgUserID  
                FROM	mdm.tblValidationLog  
                WHERE	Version_ID = @Version_ID;  
  
                EXEC mdm.udpValidationLogClear @Version_ID;  
      
            END; --if  
          
        END ELSE BEGIN --New Version  
  
            --Accept an explicit MUID (for clone operations) or generate a new one  
            SET @Return_MUID = ISNULL(@Return_MUID, NEWID());  
  
            --Insert details into Version table  
            INSERT INTO mdm.tblModelVersion  
            (  
                [Model_ID],  
                [Status_ID] ,  
                [Display_ID],  
                [Name],  
                [Description],  
                [VersionFlag_ID],  
                [AsOfVersion_ID],  
                [MUID],  
                [EnterDTM],  
                [EnterUserID],  
                [LastChgDTM],  
                [LastChgUserID]  
            )   
            SELECT  
                @Model_ID,  
                @Status_ID,  
                ISNULL(MAX(Display_ID), 0) + 1,  
                @Name,  
                @Description,  
                @VersionFlag_ID,  
                NULLIF(@CurrentVersion_ID, 0),  
                @Return_MUID,  
                @CurrentDTM,  
                @User_ID,  
                @CurrentDTM,  
                @User_ID  
            FROM   
                mdm.tblModelVersion   
            WHERE   
                Model_ID = @Model_ID;  
  
            --Save the identity value  
            SET @Version_ID = SCOPE_IDENTITY();  
  
        END --if  
  
        --Return values  
        SET @Return_ID = @Version_ID;  
  
        --Commit only if we are not nested  
        IF @TranCounter = 0 COMMIT TRANSACTION;  
  
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
  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
