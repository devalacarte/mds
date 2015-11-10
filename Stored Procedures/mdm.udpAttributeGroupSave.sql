SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    --Create Attribute Group  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpAttributeGroupSave 1,NULL,1,1,'Group 2',NULL,0,0,0,@Return_ID OUTPUT,@Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblAttributeGroup WHERE ID = @Return_ID;  
  
    --Update Aattribute Group  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    EXEC mdm.udpAttributeGroupSave 1,NULL,1,1,'Group 2',NULL,0,0,@Return_ID OUTPUT,@Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblAttributeGroup WHERE ID = @Return_ID;  
*/  
CREATE PROCEDURE [mdm].[udpAttributeGroupSave]  
(  
    @User_ID            INT,  
    @ID                    INT = NULL,  
    @Entity_ID            INT,  
    @MemberType_ID        TINYINT = NULL,  
    @Name                NVARCHAR(50),  
    @SortOrder            INT = NULL,  
    @FreezeNameCode        BIT = 0,  
    @IsSystem            BIT = 0,    
    @Return_ID            INT = NULL OUTPUT,  
    @Return_MUID        UNIQUEIDENTIFIER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @Version_ID AS INT,  
            @Model_ID AS INT,  
            @CurrentDTM AS DATETIME2(3);  
  
    --Initialize output parameters and local variables  
    SELECT   
        @Name = NULLIF(LTRIM(RTRIM(@Name)), N''), --Convert empty @Name to NULL  
        @FreezeNameCode = ISNULL(@FreezeNameCode, 0), --Convert NULL @FreezeNameCode to 0  
        @IsSystem = ISNULL(@IsSystem, 0), --Convert NULL @IsSystem to 0  
        @Return_ID = NULL,   
        @CurrentDTM = GETUTCDATE();  
  
    DECLARE @NameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @Name, @NameHasReservedCharacters OUTPUT;  
    IF @NameHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100050|The attribute group cannot be created because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    BEGIN TRY  
  
        --Get the Latest Version  
        SELECT   
            @Version_ID = MAX(mv.ID),  
            @Model_ID   = MAX(mv.Model_ID)  
        FROM  mdm.tblModelVersion AS mv  
        INNER JOIN mdm.tblEntity AS e ON (mv.Model_ID = e.Model_ID)  
        WHERE e.ID = @Entity_ID;  
  
        --Test for invalid parameters  
        IF (@Entity_ID IS NULL OR @User_ID IS NULL OR @Version_ID IS NULL)  
            OR (@ID IS NULL AND (@MemberType_ID IS NULL OR @Name IS NULL OR (@MemberType_ID < 1 OR @MemberType_ID > 3))) --INSERT: Requires these params to be populated  
            OR (@ID IS NOT NULL AND @MemberType_ID IS NOT NULL AND (@MemberType_ID < 1 OR @MemberType_ID > 3)) --UPDATE: Invalid @MemberType_ID  
            OR (@SortOrder IS NOT NULL AND @SortOrder < 0) --Invalid @SortOrder  
            OR (@ID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM mdm.tblAttributeGroup WHERE ID = @ID)) --UPDATE: Invalid @ID  
            OR NOT EXISTS(SELECT 1 FROM mdm.tblUser WHERE ID = @User_ID) --Invalid @User_ID  
        BEGIN  
            RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
            RETURN(1);  
        END; --if  
  
        --Update/Insert Attribute Group details  
        IF (@ID IS NOT NULL) BEGIN --Update Attribute Group  
  
            UPDATE mdm.tblAttributeGroup SET  
                [Name] = ISNULL(@Name, [Name]),  
                SortOrder = ISNULL(@SortOrder, SortOrder),  
                FreezeNameCode = ISNULL(@FreezeNameCode, FreezeNameCode),  
                LastChgDTM = @CurrentDTM,  
                LastChgUserID = @User_ID,  
                LastChgVersionID = @Version_ID  
            WHERE  
                ID = @ID;  
  
            --Populate output parameters  
            SELECT @Return_MUID = MUID FROM mdm.tblAttributeGroup WHERE ID = @ID;  
  
        END ELSE BEGIN --New Attribute Group  
  
            --Accept an explicit MUID (for clone operations) or generate a new one  
            SET @Return_MUID = ISNULL(@Return_MUID, NEWID());  
  
            INSERT INTO mdm.tblAttributeGroup  
            (  
                 [Entity_ID]  
                ,[MemberType_ID]  
                ,[Name]  
                ,[SortOrder]  
                ,FreezeNameCode  
                ,[IsSystem]  
                ,[MUID]  
                ,[EnterDTM]  
                ,[EnterUserID]  
                ,[EnterVersionID]  
                ,[LastChgDTM]  
                ,[LastChgUserID]  
                ,[LastChgVersionID]  
            )   
            SELECT   
                @Entity_ID,  
                @MemberType_ID,           
                @Name,  
                ISNULL(MAX(SortOrder), 0) + 1,   
                @FreezeNameCode,  
                @IsSystem,  
                @Return_MUID,  
                @CurrentDTM,  
                @User_ID,  
                @Version_ID,  
                @CurrentDTM,  
                @User_ID,  
                @Version_ID  
            FROM  
                mdm.tblAttributeGroup  
            WHERE  
                Entity_ID = @Entity_ID;  
  
            --Save the identity value  
            SET @ID = SCOPE_IDENTITY();  
  
            --Create related metadata member  
            DECLARE @AttributeGroupMetadataCode NVARCHAR(200) -- We will build out attribute group metadata codes as entityid_attributegroupid to ensure uniqueness  
            SET @AttributeGroupMetadataCode = CONVERT(NVARCHAR(199), @Entity_ID) + N'_' + CONVERT(NVARCHAR(199), @ID)  
          
            IF (@IsSystem = 0)   
                EXEC mdm.udpUserDefinedMetadataSave N'AttributeGroup', @Return_MUID, @Name, @AttributeGroupMetadataCode, @User_ID  
  
            -- Allow the creating user to see the new Attribute Group  
            EXEC mdm.udpSecurityPrivilegesSave   
                @SystemUser_ID = 1,  
                @Principal_ID = @User_ID,  
                @PrincipalType_ID = 1, -- User  
                @RoleAccess_ID = NULL,  
                @Object_ID = 5, --AttributeGroup,  
                @Privilege_ID = 2, -- Update  
                @Model_ID = @Model_ID,   
                @Securable_ID = @ID,   
                @Securable_Name = @Name;  
              
        END; --if  
  
        --Return values  
        SET @Return_ID = @ID;  
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
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);          
  
        --On error, return NULL results  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
