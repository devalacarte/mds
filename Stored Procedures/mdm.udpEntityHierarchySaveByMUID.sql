SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Wrapper for udpEntityHierarchySave  
*/  
CREATE PROCEDURE [mdm].[udpEntityHierarchySaveByMUID]  
(  
    @User_ID			INT,  
    @Model_MUID			UNIQUEIDENTIFIER,  
    @Model_Name			NVARCHAR(50) = NULL,  
    @Entity_MUID		UNIQUEIDENTIFIER,   
    @Entity_Name		NVARCHAR(50),  
    @Hierarchy_MUID		UNIQUEIDENTIFIER = NULL,  
    @HierarchyName		NVARCHAR(100) = NULL,  
    @IsMandatory		BIT = NULL,  
    @Return_DidEntityIsFlatChange BIT = NULL OUTPUT,  
    @Return_ID			INT = NULL OUTPUT,  
    @Return_MUID		UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    /*  
    Mode		@Hierarchy_MUID		@Return_MUID  
    --------    ------------------  ------------------  
    Create		Empty Guid or null	Empty Guid or null  
    Clone		Empty Guid or null	Guid	  
    Update		Guid				n/a  
    */  
    DECLARE @Hierarchy_ID INT,  
            @Entity_ID INT,  
            @Model_ID INT,  
            @CurrentEntityIsFlat BIT,  
            @NewEntityIsFlat BIT,  
            @ErrorMsg NVARCHAR(250);  
        
    IF @HierarchyName IS NOT NULL AND Len(@HierarchyName) > 50 -- Check to see if the HierarchyName exceeds the length limit (50).   
    BEGIN  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;    
        RAISERROR('MDSERR200088|The explicit hierarchy cannot be saved. The explicit hierarchy name cannot be more than 50 characters.', 16, 1);  
        RETURN;    
    END;  
  
    IF @Entity_MUID IS NOT NULL  
        BEGIN  
  
            SELECT @Entity_ID = ID, @CurrentEntityIsFlat = IsFlat FROM mdm.tblEntity WHERE MUID = @Entity_MUID AND IsSystem = 0;  
  
            IF (@Entity_ID IS NULL) --Invalid Entity_MUID  
            BEGIN  
                --On error, return NULL results  
                SELECT @Return_ID = NULL, @Return_MUID = NULL;  
                RAISERROR('MDSERR200011|The explicit hierarchy cannot be saved. The entity ID is not valid.', 16, 1);  
                RETURN;  
            END;  
        END  
    ELSE  
        IF (@Model_Name IS NOT NULL OR @Model_MUID IS NOT NULL) AND (@Entity_Name IS NOT NULL)   
        BEGIN  
            SELECT @Model_ID = ID FROM mdm.tblModel WHERE   
                (((@Model_MUID IS NULL) OR (MUID = @Model_MUID)) AND ((@Model_Name IS NULL) OR ([Name] = @Model_Name)))   
                AND IsSystem = 0;  
  
            IF (@Model_ID IS NULL) --Invalid Model_MUID  
            BEGIN  
                --On error, return NULL results  
                SELECT @Return_ID = NULL, @Return_MUID = NULL;  
                RAISERROR('MDSERR200010|The explicit hierarchy cannot be saved. The model ID is not valid.', 16, 1);  
                RETURN;  
            END  
  
            SELECT @Entity_ID = ID, @CurrentEntityIsFlat = IsFlat  FROM mdm.tblEntity WHERE [Name] = @Entity_Name AND Model_ID = @Model_ID AND IsSystem = 0;  
  
            IF (@Entity_ID IS NULL) --Invalid Entity_MUID  
            BEGIN  
                --On error, return NULL results  
                SELECT @Return_ID = NULL, @Return_MUID = NULL;  
                RAISERROR('MDSERR200011|The explicit hierarchy cannot be saved. The entity ID is not valid.', 16, 1);  
                RETURN;  
            END  
        END  
  
    IF (@Hierarchy_MUID IS NOT NULL AND CAST(@Hierarchy_MUID  AS BINARY) <> 0x0)  
    BEGIN  
        -- Update Mode  
        SELECT  @Hierarchy_ID = ID FROM mdm.tblHierarchy WHERE MUID = @Hierarchy_MUID AND Entity_ID = @Entity_ID;  
  
        IF @Hierarchy_ID IS NULL   
        BEGIN  
            --On error, return NULL results  
            SELECT @Return_ID = NULL, @Return_MUID = NULL;  
            RAISERROR('MDSERR200012|The explicit hierarchy cannot be saved. The explicit hierarchy ID is not valid.', 16, 1);  
            RETURN;  
        END;  
  
    END;  
  
    EXEC mdm.udpEntityHierarchySave @User_ID, @Hierarchy_ID, @Entity_ID, @HierarchyName, @IsMandatory, @Return_ID OUTPUT, @Return_MUID OUTPUT  
  
    SELECT @NewEntityIsFlat = IsFlat FROM mdm.tblEntity WHERE MUID = @Entity_MUID AND IsSystem = 0;  
    -- Return indicating whether the entity how has hierarchies.  This is used in the API to determine if business rules should be created  
    -- for the consolidated and collection entity tables.   
    IF @NewEntityIsFlat =  @CurrentEntityIsFlat  
        SET @Return_DidEntityIsFlatChange = 0;  
    ELSE  
        SET @Return_DidEntityIsFlatChange = 1;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
