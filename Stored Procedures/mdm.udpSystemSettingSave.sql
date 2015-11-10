SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpSystemSettingSave 1,'SiteTitle','MDS (Master Data Services)',1,'Site Title','The title of the application that shows up in the title bar of browser';  
    EXEC mdm.udpSystemSettingSave 1,'eDMAdminEmailAddress','test1@mdm.com',null,null,null;  
  
    select * from mdm.tblSystemSetting;  
    SELECT * FROM msdb.dbo.sysmail_account WHERE [name] = N'MDM_Email_Account';  
*/  
CREATE PROCEDURE [mdm].[udpSystemSettingSave]  
(  
    @User_ID            INT,  
    @SettingName		NVARCHAR(100),  
    @SettingValue		NVARCHAR(max),  
    @IsVisible			BIT = NULL,  
    @DisplayName		NVARCHAR(100) = NULL,  
    @Description		NVARCHAR(250) = NULL  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE  
        @ID INT,  
        @SettingType_ID TINYINT,  
        @DataType_ID TINYINT,  
        @MinValue NVARCHAR(200),  
        @MaxValue NVARCHAR(200),  
        @ListCode NVARCHAR(50),  
        @ExistingSettingValue NVARCHAR(max),  
        @ErrorMsg NVARCHAR(250),  
        @NumericSettingValue FLOAT,  
        @RebuildViews BIT  
          
    SELECT  
        @ID = ID,  
        @ExistingSettingValue = SettingValue,  
        @SettingType_ID = SettingType_ID,  
        @DataType_ID = DataType_ID,  
        @MinValue = MinValue,  
        @MaxValue = MaxValue,  
        @ListCode = ListCode  
    FROM mdm.tblSystemSetting  
    WHERE SettingName = @SettingName  
  
    DECLARE @SettingValueHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @SettingValue, @SettingValueHasReservedCharacters OUTPUT;  
  
    DECLARE @DisplayNameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @DisplayName, @DisplayNameHasReservedCharacters OUTPUT;  
  
    DECLARE @DescriptionHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @Description, @DescriptionHasReservedCharacters OUTPUT;  
  
    IF @SettingValueHasReservedCharacters = 1 OR @DisplayNameHasReservedCharacters = 1 OR @DescriptionHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100057|The system setting cannot be updated because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    IF @ID IS NOT NULL BEGIN  
        --Start transaction, being careful to check if we are nested  
        DECLARE @TranCounter INT;   
        SET @TranCounter = @@TRANCOUNT;  
        IF @TranCounter > 0 SAVE TRANSACTION TX;  
        ELSE BEGIN TRANSACTION;  
  
        BEGIN TRY		  
  
            SET @RebuildViews = 0  
  
            --Validate setting value.  
            IF @SettingType_ID = 2   
            BEGIN  
                IF ISNUMERIC(@SettingValue) = 0   
                    RAISERROR('MDSERR200043|The system setting cannot be saved. The setting value must be a number.', 16, 1);  
                ELSE  
                    IF mdm.udfIsValidListOptionID(@ListCode, CAST(@SettingValue AS INT), NULL) = 0   
                    BEGIN  
                        RAISERROR('MDSERR200042|The system setting cannot be saved. The setting is not a valid value.', 16, 1);  
                    END; --if					  
            END   
            ELSE BEGIN  
                IF @DataType_ID = 2 BEGIN  
                    IF @SettingValue IS NOT NULL BEGIN  
                        IF ISNUMERIC(@SettingValue) = 0 BEGIN  
                            RAISERROR('MDSERR200043|The system setting cannot be saved. The setting value must be a number.', 16, 1);  
                        END ELSE BEGIN  
                            SET @NumericSettingValue = CAST(@SettingValue AS FLOAT)  
                            IF ISNUMERIC(@MinValue) = 1 AND @NumericSettingValue < CAST(@MinValue AS FLOAT) BEGIN  
                                    RAISERROR('MDSERR200044|The system setting cannot be saved. The setting value cannot be less than the minimum value allowed.', 16, 1);  
                            END; --if  
  
                            IF ISNUMERIC(@MaxValue) = 1 AND @NumericSettingValue > CAST(@MaxValue AS FLOAT) BEGIN  
                                    RAISERROR('MDSERR200045|The system setting cannot be saved. The setting value cannot be greater than the maximum value allowed.', 16, 1);  
                            END; --if  
                        END; --if  
                    END; --if  
                END; --if  
            END; --if  
          
            --Update the value  
            UPDATE mdm.tblSystemSetting SET   
                SettingValue = ISNULL(@SettingValue, N''),  
  
                IsVisible = ISNULL(@IsVisible, IsVisible),  
                DisplayName = ISNULL(@DisplayName, DisplayName),  
                [Description] = ISNULL(@Description, [Description]),  
  
                LastChgUserID = @User_ID,  
                LastChgDTM = GETUTCDATE()  
            WHERE   
                SettingName = @SettingName;  
  
            --Rebuild the views if necessary  
            IF @RebuildViews = 1 EXEC mdm.udpCreateAllViews;  
              
            --Commit only if we are not nested  
            IF @TranCounter = 0 COMMIT TRANSACTION;  
  
        END TRY  
  
        BEGIN CATCH  
            IF @TranCounter = 0 ROLLBACK TRANSACTION;  
            ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
            DECLARE @ErrorNumber INT;  
  
            SELECT   
                @ErrorNumber = ERROR_NUMBER();  
  
            IF (@ErrorNumber = 200042)  
                RAISERROR('MDSERR200042|The system setting cannot be saved. The setting is not a valid value.', 16, 1);  
            ELSE IF (@ErrorNumber = 200043)  
                RAISERROR('MDSERR200043|The system setting cannot be saved. The setting value must be a number.', 16, 1);  
            ELSE IF (@ErrorNumber = 200044)  
                RAISERROR('MDSERR200044|The system setting cannot be saved. The setting value cannot be less than the minimum value allowed.', 16, 1);  
            ELSE IF (@ErrorNumber = 200045)  
                RAISERROR('MDSERR200045|The system setting cannot be saved. The setting value cannot be greater than the maximum value allowed.', 16, 1);  
            ELSE  
                RAISERROR('MDSERR200046|The system setting cannot be saved.', 16, 1);  
  
            RETURN  
  
        END CATCH;  
                          
    END ELSE BEGIN  
        RAISERROR('MDSERR200041|The system setting cannot be saved. The setting name is not valid.', 16, 1);  
        RETURN		  
    END; --if  
  
    RETURN(0);  
  
    SET NOCOUNT OFF;  
END; --proc
GO
