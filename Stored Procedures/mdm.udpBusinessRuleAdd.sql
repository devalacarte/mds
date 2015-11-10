SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleAdd]  
(  
    @User_ID                INT = NULL,   
    @Name                   NVARCHAR(50) = NULL,   
    @Description            NVARCHAR(255) = NULL,   
    @RuleConditionText      NVARCHAR(max) = NULL,  
    @RuleActionText         NVARCHAR(max) = NULL,  
    @RuleConditionSQL       NVARCHAR(max) = NULL,  
    @RuleType               INT = NULL, -- 1 = AttributeMember  
    @RuleSubType            INT = NULL, -- 1 = Leaf, 2 = Consolidated  
    @Priority               INT = NULL,  
    @NotificationGroupMuid  UNIQUEIDENTIFIER = NULL,  
    @NotificationUserMuid   UNIQUEIDENTIFIER = NULL,  
    @LastChanged            DATETIME2(3) = NULL,  
    @Entity_MUID            UNIQUEIDENTIFIER = NULL OUTPUT,   
    @Entity_Name            NVARCHAR(50) = NULL OUTPUT,  
    @Model_MUID             UNIQUEIDENTIFIER = NULL OUTPUT,   
    @Model_Name             NVARCHAR(50) = NULL OUTPUT,   
    @MUID                   UNIQUEIDENTIFIER = NULL OUTPUT, /*Input (Clone only) and output*/  
    @ID                     INT = NULL OUTPUT /*Output only*/  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    SET @ID = 0;  
      
    -- check to see if a MUID of an existing row was given  
    IF (@MUID IS NOT NULL AND (SELECT COUNT(*) FROM mdm.tblBRBusinessRule WHERE MUID = @MUID) > 0) BEGIN  
        -- call update  
	    EXEC mdm.udpBusinessRuleUpdate   
            @User_ID,   
            @Name,   
            @Description,   
            @RuleConditionText,  
            @RuleActionText,  
            @RuleConditionSQL,  
            @RuleType,  
            @RuleSubType,   
            @Priority,  
            @NotificationGroupMuid,  
            @NotificationUserMuid,  
            @LastChanged,  
            NULL,  
            @Entity_MUID OUTPUT,   
            @Entity_Name OUTPUT,  
            @Model_MUID OUTPUT,  
            @Model_Name OUTPUT,  
            @MUID OUTPUT,   
            @ID OUTPUT;  
    END ELSE BEGIN  
  
        -- trim whitespace from nvarchars  
        SET @Name = LTRIM(RTRIM(@Name))  
        SET @Description = LTRIM(RTRIM(@Description))  
        SET @RuleConditionText = LTRIM(RTRIM(@RuleConditionText))  
        SET @RuleActionText = LTRIM(RTRIM(@RuleActionText))  
        SET @RuleConditionSQL = LTRIM(RTRIM(@RuleConditionSQL))  
  
        -- lookup Entity_ID and ForeignType_ID  
        DECLARE @ForeignType_ID INT,  
                @Entity_ID INT,  
                @NotificationGroup_ID INT,  
                @NotificationUser_ID INT,  
                @Failed BIT   
                  
        EXEC mdm.udpBusinessRuleAddHelper @Name, @MUID, @RuleType, @RuleSubType, @NotificationGroupMuid, @NotificationUserMuid, @Entity_ID OUTPUT, @Entity_MUID OUTPUT, @Entity_Name OUTPUT, @Model_MUID OUTPUT, @Model_Name OUTPUT, @ForeignType_ID OUTPUT, @NotificationGroup_ID OUTPUT, @NotificationUser_ID OUTPUT, @Failed OUTPUT   
        IF @Failed = 1 BEGIN  
            RETURN;  
        END  
  
        SET @MUID = ISNULL(@MUID, NEWID());  
          
        -- add row  
        INSERT INTO mdm.tblBRBusinessRule(  
            MUID,  
            [Name],   
            [Description],  
            RuleConditionText,  
            RuleActionText,  
            RuleConditionSQL,  
            ForeignType_ID,  
            Foreign_ID,  
            Status_ID,  
            Priority,  
            NotificationGroupID,              
            NotificationUserID,              
            EnterDTM,  
            EnterUserID,  
            LastChgDTM,  
            LastChgUserID  
        ) VALUES (  
            @MUID,  
            @Name,   
            @Description,  
            @RuleConditionText,  
            @RuleActionText,  
            @RuleConditionSQL,  
            @ForeignType_ID,  
            @Entity_ID,  
            mdm.udfBusinessRuleGetNewStatusID(1, 0), -- 1 = enum ActionType.Create  
            @Priority,  
            @NotificationGroup_ID,  
            @NotificationUser_ID,  
            GETUTCDATE(),  
            @User_ID,  
            GETUTCDATE(),  
            @User_ID  
        );  
  
        -- set output params  
        IF @@ERROR = 0 BEGIN  
            SET @ID = SCOPE_IDENTITY();  
        END ELSE BEGIN  
            SET @MUID = NULL;-- ensure MUID is set back to NULL if there was an error  
        END  
  
    END  
  
    SET NOCOUNT OFF  
END --proc
GO
