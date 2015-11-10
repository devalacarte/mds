SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpModelVersionFlagSave 1  
    EXEC mdm.udpModelVersionFlagSave '1', '7', '1', 'Version 3', 'Chuck test version', '1', @Return = ''  
*/  
CREATE PROCEDURE [mdm].[udpModelVersionFlagSave]  
(  
    @User_ID            INT,  
    @ID 				INT = NULL,  
    @Model_ID 			INT,  
    @Status_ID 			TINYINT,  
    @Name 				NVARCHAR(50),  
    @Description 		NVARCHAR(500),  
    @CommittedOnly_ID 	TINYINT,  
    @Return_ID			INT = NULL OUTPUT,  
    @Return_MUID		UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @NameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @Name, @NameHasReservedCharacters OUTPUT;  
    IF @NameHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100056|The version flag cannot be created because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    DECLARE @DescriptionHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @Description, @DescriptionHasReservedCharacters OUTPUT;  
    IF @DescriptionHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100056|The version flag cannot be created because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    IF NOT EXISTS(SELECT ID FROM mdm.tblModelVersionFlag WHERE ID = @ID) BEGIN  
  
        --Accept an explicit MUID (for clone operations) or generate a new one  
        SET @Return_MUID =  ISNULL(@Return_MUID, NEWID());  
  
        INSERT INTO mdm.[tblModelVersionFlag] (  
            Model_ID,  
            Status_ID,  
            [Name],  
            [Description],  
            CommittedOnly_ID,  
            MUID,   
            EnterDTM,  
            EnterUserID,  
            LastChgDTM,  
            LastChgUserID  
        ) VALUES (  
            @Model_ID,  
            @Status_ID,  
            @Name,  
            @Description,  
            @CommittedOnly_ID,  
            @Return_MUID,  
            GETUTCDATE(),  
            @User_ID,  
            GETUTCDATE(),  
            @User_ID  
        );		  
  
        --Save the identity value  
        SET @Return_ID = SCOPE_IDENTITY();  
  
    END	ELSE BEGIN  
  
        IF @CommittedOnly_ID = 1 BEGIN  
            DECLARE @VersionStatusCommitted INT = 3;  
            -- Ensure the version flag is not already being used on an uncommitted version  
            IF EXISTS (SELECT ID FROM mdm.tblModelVersion WHERE VersionFlag_ID = @ID AND Status_ID <> @VersionStatusCommitted) BEGIN  
                RAISERROR('MDSERR200084|The version flag cannot be changed to committed only. It is referenced by a non-committed version.', 16, 1);  
                RETURN;          
            END;  
        END;   
          
        UPDATE mdm.[tblModelVersionFlag] SET  
            Status_ID = ISNULL(@Status_ID, Status_ID),  
            [Name] = ISNULL(@Name, [Name]),  
            [Description] = ISNULL(@Description, [Description]),  
            CommittedOnly_ID = ISNULL(@CommittedOnly_ID,CommittedOnly_ID),  
            LastChgDTM = GETUTCDATE(),  
            LastChgUserID = @User_ID  
        WHERE  
            ID = @ID;  
  
        --Populate output parameters  
        SELECT @Return_MUID = MUID FROM mdm.[tblModelVersionFlag] WHERE ID = @ID;  
  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
