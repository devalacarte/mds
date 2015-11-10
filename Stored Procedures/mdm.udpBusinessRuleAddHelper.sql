SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Performs operations common to the BR Add and Update operations  
  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleAddHelper]  
(  
    @RuleName               NVARCHAR(50) = NULL,   
    @Rule_MUID              UNIQUEIDENTIFIER = NULL,   
    @RuleType               INT = NULL,  
    @RuleSubType            INT = NULL,  
    @NotificationGroupMuid  UNIQUEIDENTIFIER = NULL,  
    @NotificationUserMuid   UNIQUEIDENTIFIER = NULL,  
    @Entity_ID              INT OUTPUT, /* output only */  
    @Entity_MUID            UNIQUEIDENTIFIER = NULL OUTPUT, -- if Entity_MUID is not provided, then it will be looked up by Entity_Name and Model_Name/MUID   
    @Entity_Name            NVARCHAR(50) = NULL OUTPUT, /* input (optional) and output */  
    @Model_MUID             UNIQUEIDENTIFIER = NULL OUTPUT, /* input (optional) and output */  
    @Model_Name             NVARCHAR(50) = NULL OUTPUT, /* input (optional) and output */  
    @ForeignType_ID         INT OUTPUT,  
    @NotificationGroup_ID   INT OUTPUT,  
    @NotificationUser_ID    INT OUTPUT,      
    @Failed                 BIT OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET @Failed = 1  
  
    -- get ForeignType_ID  
    SET @ForeignType_ID = (  
        SELECT TOP 1 ID   
        FROM mdm.tblListRelationship  
        WHERE   
            Parent_ID = @RuleType AND  
            Child_ID = @RuleSubType AND  
            ListRelationshipType_ID = 1) -- 1 = ID of mdm.tblListRelationshipType row where Name = "BRType"  
    IF @ForeignType_ID IS NULL BEGIN  
        RAISERROR('MDSERR400008|The MemberType is not valid for the rule.', 16, 1);  
        RETURN;  
    END  
  
    -- get Foreign_ID (Entity ID)  
    DECLARE @EmptyMuid UNIQUEIDENTIFIER SET @EmptyMuid = CONVERT(UNIQUEIDENTIFIER, 0x0);  
    IF @Entity_MUID = @EmptyMuid BEGIN -- convert empty identifier to null  
        SET @Entity_MUID = NULL  
    END  
    IF LEN(@Entity_Name) = 0 BEGIN -- convert empty string to null  
        SET @Entity_Name = NULL  
    END  
    IF @Model_MUID = @EmptyMuid BEGIN -- convert empty identifier to null  
        SET @Model_MUID = NULL  
    END  
    IF LEN(@Model_Name) = 0 BEGIN -- convert empty string to null  
        SET @Model_Name = NULL  
    END  
    SET @Entity_ID = NULL; -- set entity id to null, in case the below query has no matches  
    SELECT TOP 1   
        @Entity_ID = ID,  
        @Entity_MUID = MUID,  
        @Entity_Name = [Name],  
        @Model_MUID = Model_MUID,  
        @Model_Name = Model_Name  
    FROM mdm.viw_SYSTEM_SCHEMA_ENTITY   
    WHERE   
        (MUID = @Entity_MUID OR                                 -- apply the match criteria  ...  
          ([Name] = @Entity_Name AND                            -- *  
            (Model_MUID = @Model_MUID OR                        -- *  
             Model_Name = @Model_Name))) AND                    -- *  
        (@Entity_MUID IS NULL OR MUID = @Entity_MUID) AND       -- ... to include screening out name/muids mismatches  
        (@Entity_Name IS NULL OR [Name] = @Entity_Name) AND     -- *  
        (@Model_MUID IS NULL OR Model_MUID = @Model_MUID) AND   -- *  
        (@Model_Name IS NULL OR Model_Name = @Model_Name)       -- *  
    ORDER BY Model_Name  
      
    IF @Entity_ID IS NULL BEGIN  
        RAISERROR('MDSERR400009|The entity reference is not valid. The entity was not found.', 16, 1);  
        RETURN;  
    END  
  
    DECLARE @OldRuleName NVARCHAR(50) SET @OldRuleName = (SELECT [Name] FROM mdm.tblBRBusinessRule WHERE MUID = @Rule_MUID)  
    IF @OldRuleName IS NULL OR @OldRuleName <> @RuleName BEGIN  
        -- ensure rule Name is not empty  
        IF @RuleName IS NULL OR len(@RuleName) = 0 BEGIN  
            RAISERROR('MDSERR400010|Business rule name is required.', 16, 1);  
            RETURN;  
        END  
  
        -- check for rule Name conflict  
        IF EXISTS(  
            SELECT *   
            FROM mdm.tblBRBusinessRule   
            WHERE   
                [Name] = @RuleName AND  
                Foreign_ID = @Entity_ID AND  
                ForeignType_ID = @ForeignType_ID) BEGIN  
            RAISERROR('MDSERR400011|A business rule with that name already exists for the entity and member type.', 16, 1);  
            RETURN;  
        END             
    END  
      
    -- get notification id  
    IF @NotificationGroupMuid IS NOT NULL AND @NotificationUserMuid IS NOT NULL BEGIN  
        RAISERROR('MDSERR400036|Specify either a user, a group, or neither, but not both', 16, 1);  
        RETURN;     
    END  
    SET @NotificationGroup_ID = NULL  
    SET @NotificationUser_ID = NULL   
    IF @NotificationGroupMuid IS NOT NULL BEGIN  
        SELECT @NotificationGroup_ID = ID  
        FROM mdm.tblUserGroup  
        WHERE MUID = @NotificationGroupMuid  
        IF @NotificationGroup_ID IS NULL BEGIN  
            RAISERROR('MDSERR500025|The principal ID for the user or group is not valid.', 16, 1);  
            RETURN;     
        END  
    END  
    IF @NotificationUserMuid IS NOT NULL BEGIN  
        DECLARE @FunctionExplorer INT = 1;  
        SELECT @NotificationUser_ID = ID  
        FROM mdm.tblUser  
        WHERE MUID = @NotificationUserMuid  
        IF   
            @NotificationUser_ID IS NULL OR                                                                                    -- Ensure the user exists and can see members subject to the business rule by checking:  
            @RuleSubType NOT IN (SELECT ID FROM mdm.udfSecurityUserMemberTypeList (@NotificationUser_ID, NULL, @Entity_ID)) OR -- 1. Entity Member Type permission, and  
            @FunctionExplorer NOT IN (SELECT Function_ID FROM mdm.udfSecurityUserFunctionList (@NotificationUser_ID)) BEGIN    -- 2. Explorer function  
            RAISERROR('MDSERR120000|The user is not valid or has insufficient permissions.', 16, 1);  
            RETURN;               
        END  
    END  
          
    SET @Failed = 0  
  
END --proc
GO
