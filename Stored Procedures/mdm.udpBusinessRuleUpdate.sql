SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleUpdate]  
(  
    @User_ID                INT = NULL,   
    @Name                   NVARCHAR(50) = NULL,   
    @Description            NVARCHAR(255) = NULL,   
    @RuleConditionText      NVARCHAR(MAX) = NULL,  
    @RuleActionText         NVARCHAR(MAX) = NULL,  
    @RuleConditionSQL       NVARCHAR(MAX) = NULL,  
    @RuleType               INT = NULL, -- 1 = AttributeMember  
    @RuleSubType            INT = NULL, -- 1 = Leaf, 2 = Consolidated  
    @Priority               INT = NULL,  
    @NotificationGroupMuid  UNIQUEIDENTIFIER = NULL,  
    @NotificationUserMuid   UNIQUEIDENTIFIER = NULL,  
    @LastChanged            DATETIME2(3) = NULL,  
	@Status_ID			    INT = NULL,  
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
  
    -- made sure a MUID of an existing row was given  
    IF (@MUID IS NULL OR (SELECT COUNT(*) FROM mdm.tblBRBusinessRule WHERE MUID = @MUID) = 0) BEGIN  
        SET @MUID = NULL;  
	    RAISERROR('MDSERR400001|The Update operation failed. The MUID was not found.', 16, 1);  
        RETURN;  
    END    
  
    -- make sure the rule has not changed since the LastChanged date (if given)  
    IF (@LastChanged IS NOT NULL AND @LastChanged < (SELECT LastChgDTM FROM mdm.tblBRBusinessRule WHERE MUID = @MUID)) BEGIN  
        SET @MUID = NULL;  
	    RAISERROR('MDSERR400014|The business rule cannot be updated. It has been changed by another user.', 16, 1);  
        RETURN;  
    END            
   
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
      
    -- find Action_ID  
    DECLARE @Action_ID INT SET @Action_ID = 3 -- 3 = Change  
    IF @Status_ID IS NOT NULL BEGIN  
        DECLARE @CurrentStatus_ID INT SET @CurrentStatus_ID = (SELECT Status_ID FROM mdm.tblBRBusinessRule WHERE MUID = @MUID)   
        IF (@CurrentStatus_ID NOT IN (2,5) AND @Status_ID IN (2,5)) SET @Action_ID = 5 -- 5 = Exclude  
        ELSE IF (@CurrentStatus_ID IN (2,5) AND @Status_ID IN (1,3)) SET @Action_ID = 2 -- 2 = Activate  
    END  
          
    -- update row  
    UPDATE mdm.tblBRBusinessRule  
    SET  
        [Name] = @Name,   
        [Description] = @Description,  
        RuleConditionText = @RuleConditionText,  
        RuleActionText = @RuleActionText,  
        RuleConditionSQL = @RuleConditionSQL,  
        ForeignType_ID = @ForeignType_ID,  
        Foreign_ID = @Entity_ID,  
        Status_ID = mdm.udfBusinessRuleGetNewStatusID(@Action_ID, Status_ID),   
        Priority = @Priority,  
        NotificationGroupID = @NotificationGroup_ID,              
        NotificationUserID = @NotificationUser_ID,              
        LastChgDTM = GETUTCDATE(),  
        LastChgUserID = @User_ID  
    WHERE  
        MUID = @MUID  
  
    -- set output params  
    IF @@ERROR = 0 BEGIN  
        SET @ID = (SELECT ID FROM mdm.tblBRItem WHERE MUID = @MUID)  
    END ELSE BEGIN  
        SET @MUID = NULL;  
    END  
  
    SET NOCOUNT OFF  
END --proc
GO
