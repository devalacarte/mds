SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    Wrapper for mdm.udpAttributeSave  
  
    --Create DBA attribute  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER, @DomainEntity_ID INT;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
  
    EXEC mdm.udpAttributeSaveByMUID   
        1,   
        NULL,'Product',   
        NULL,'Product',   
        1,   
        NULL,'TestDBA',   
        NULL,   
        100,   
        NULL,'Class',  
        NULL,  
        NULL,  
        NULL,  
        NULL,  
        @Return_ID OUTPUT,  
        @Return_MUID OUTPUT;  
  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblAttribute WHERE ID = @Return_ID;  
    SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE = Attribute_ID = @Return_ID;  
  
    --Create DBA attribute  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER, @DomainEntity_ID INT;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
  
    EXEC mdm.udpAttributeSaveByMUID   
        1,   
        NULL,NULL,   
        '6DE6088A-701D-47A8-A1C9-CB5E5B960C2E',NULL,   
        1,   
        NULL,'TestDBA2',   
        NULL,   
        100,   
        '483F2A98-0DA3-4313-AB45-94DEECA7BD7F',NULL,  
        NULL,  
        NULL,  
        NULL,  
        NULL,  
        @Return_ID OUTPUT,  
        @Return_MUID OUTPUT;  
  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblAttribute WHERE ID = @Return_ID;  
    SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Attribute_ID = @Return_ID;  
  
*/  
CREATE PROCEDURE [mdm].[udpAttributeSaveByMUID]  
(  
    @User_ID						INT,  
    @Model_MUID						UNIQUEIDENTIFIER,  
    @Model_Name						NVARCHAR(50) = NULL,  
    @Entity_MUID					UNIQUEIDENTIFIER,   
    @Entity_Name					NVARCHAR(50),  
    @MemberType_ID					TINYINT,  
    @Attribute_MUID					UNIQUEIDENTIFIER = NULL,  
    @Name							NVARCHAR(50),  
    @AttributeType_ID				INT,  
    @DisplayWidth					INT,   
    @DomainEntity_MUID				UNIQUEIDENTIFIER = NULL,  
    @DomainEntity_Name				NVARCHAR(50) = NULL,  
    @DataType_ID					TINYINT = NULL,  
    @DataTypeInformation			INT = NULL,  
    @InputMask_Name					NVARCHAR(250) = NULL,  
    @ChangeTrackingGroup			INT = 0,  
    @SortOrder                      INT = NULL,  
    @Return_DidNameChange			BIT = NULL OUTPUT,  
    @Return_SubscriptionViewExists	BIT = NULL OUTPUT,  
    @Return_ID						INT = NULL OUTPUT,  
    @Return_MUID					UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    /*  
    Mode		@Attribute_MUID		@Return_MUID  
    --------    ------------------  ------------------  
    Create		Empty Guid or null	Empty Guid or null  
    Clone		Empty Guid or null	Guid	  
    Update		Guid				n/a  
    */  
    DECLARE @Attribute_ID INT,  
            @Entity_ID INT,  
            @Model_ID INT,  
            @DomainEntity_ID INT,  
            @InputMask_ID INT,  
            @CurrentName sysname,  
            @Ret INT;  
              
  
  
    IF (@Model_Name IS NOT NULL OR @Model_MUID IS NOT NULL) AND (@Entity_Name IS NOT NULL)   
    BEGIN  
        SELECT @Model_ID = ID FROM mdm.tblModel WHERE   
        ( (@Model_MUID IS NULL OR MUID = @Model_MUID)  AND ( @Model_Name IS NULL OR [Name] =@Model_Name))   
  
        IF (@Model_ID IS NULL) --Invalid Model_MUID  
        BEGIN  
            RAISERROR('MDSERR200013|The attribute cannot be saved. The model ID is not valid.', 16, 1);  
            RETURN;  
        END  
  
        SELECT @Entity_ID = ID FROM mdm.tblEntity WHERE [Name] = @Entity_Name AND Model_ID = @Model_ID;  
  
        IF (@Entity_ID IS NULL) --Invalid Entity_MUID  
        BEGIN  
            RAISERROR('MDSERR200014|The attribute cannot be saved. The entity ID is not valid.', 16, 1);  
            RETURN;  
        END  
    END  
    ELSE  
    BEGIN  
        SELECT @Entity_ID = ID, @Model_ID = Model_ID FROM mdm.tblEntity WHERE MUID = @Entity_MUID;  
  
        IF (@Entity_ID IS NULL) --Invalid Entity_MUID  
        BEGIN  
            RAISERROR('MDSERR200014|The attribute cannot be saved. The entity ID is not valid.', 16, 1);  
            RETURN;  
        END;  
    END  
  
    SELECT @DomainEntity_ID = ID FROM mdm.tblEntity WHERE (MUID = @DomainEntity_MUID) OR (Model_ID = @Model_ID AND Name = @DomainEntity_Name);  
  
    IF (@InputMask_Name IS NULL)  
    BEGIN  
        SET @InputMask_ID = NULL  
    END  
    ELSE  
    BEGIN  
        SET @InputMask_ID = ISNULL((SELECT OptionID FROM mdm.tblList WHERE ListCode = CAST(N'lstInputMask' AS NVARCHAR(50)) AND ListOption = @InputMask_Name), -1);  
  
    IF (@InputMask_ID < 0)  
  
    BEGIN  
        RAISERROR('MDSERR200085|The attribute cannot be saved. The input mask is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    END  
    SELECT @Name = NULLIF(LTRIM(RTRIM(@Name)), N'');  
      
    IF (@Attribute_MUID IS NOT NULL AND CAST(@Attribute_MUID  AS BINARY)<> 0x0)  
    BEGIN  
        -- Update Mode  
        SELECT @Attribute_ID = ID, @CurrentName = [Name] from mdm.tblAttribute WHERE MUID = @Attribute_MUID AND Entity_ID = @Entity_ID;  
  
        IF @Attribute_ID IS NULL   
        BEGIN  
            RAISERROR('MDSERR200016|The attribute cannot be saved. The attribute ID is not valid.', 16, 1);  
            RETURN;  
        END;  
    END;  
  
    IF @AttributeType_ID = 4 --Handle special case for File Attribute Type   
        SET @DomainEntity_ID = -1  
    ELSE IF @AttributeType_ID = 3 --System attribute  
        -- Saving a system attribute that is not part of the existing entity member attributes is not supported.  
        IF NOT EXISTS (  
            SELECT 1   
            FROM mdm.tblAttribute   
            WHERE Entity_ID = @Entity_ID   
            AND MemberType_ID = @MemberType_ID   
            AND IsSystem = 1  
            AND [Name] = @Name  
            )  
        BEGIN  
            RAISERROR('MDSERR200074|Creating system attributes is not supported.', 16, 1);  
            RETURN;  
        END;  
  
    -- Return indicating whether the attribute name was updated.  This is used in the API to determine if business rules should be refreshed.   
    -- Adding a new attribute (@CurrentName is NULL in that case) is not a name change.   
    IF @CurrentName IS NULL OR (LTRIM(RTRIM(@CurrentName)) =  LTRIM(RTRIM(ISNULL(@Name, @CurrentName))))  
        SET @Return_DidNameChange = 0;  
    ELSE  
        SET @Return_DidNameChange = 1;  
  
    /*********************************************    
                Available view formats for Entity are:    
                    
                1 - Leaf    
                2 - Consolidated    
                3 - Collection Attributes    
                4 - Collection    
                5 - Parent Child    
                6 - Levels    
                    
                Available view formats for Derived Hierarchy are:    
                    
                7 - Parent Child    
                8 - Levels     
    *********************************************/    
       
    -- Translate MemberTypes to ViewFormats to refine the check for subscription views.              
    DECLARE @ViewFormat_ID int  
    SELECT @ViewFormat_ID =   
        CASE   
            WHEN @MemberType_ID <= 3 THEN  @MemberType_ID  
            WHEN @MemberType_ID = 4 THEN  7  
            WHEN @MemberType_ID = 5 THEN  4  
        ELSE NULL  
        END   
          
    -- Return indicating whether a subscription view exists.      
    -- This is used to notify the user that the subscription view should be regenerated.     
    EXEC mdm.udpSubscriptionViewCheck @Entity_ID = @Entity_ID, @Model_ID = @Model_ID, @ViewFormat_ID = @ViewFormat_ID, @MarkDirtyFlag = 1, @Return_ID = @Ret output    
    SET @Return_SubscriptionViewExists = @Ret    
  
    EXEC mdm.udpAttributeSave @User_ID = @User_ID, @Attribute_ID = @Attribute_ID, @Entity_ID = @Entity_ID, @MemberType_ID = @MemberType_ID, @Name = @Name, @DisplayName = @Name, @DisplayWidth = @DisplayWidth, @DomainEntity_ID = @DomainEntity_ID,   
        @DataType_ID = @DataType_ID, @DataTypeInformation =@DataTypeInformation, @InputMask_ID = @InputMask_ID, @ChangeTrackingGroup = @ChangeTrackingGroup, @SortOrder = @SortOrder, @Return_ID=@Return_ID OUTPUT,@Return_MUID=@Return_MUID OUTPUT;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
