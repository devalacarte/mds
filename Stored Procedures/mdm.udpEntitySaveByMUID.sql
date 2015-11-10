SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Wrapper for the udpEntitySave proc.  
  
    DECLARE @Return_ID INT, @MUID UNIQUEIDENTIFIER, @Return_MUID UNIQUEIDENTIFIER,  @Return_CodeAttrMUID UNIQUEIDENTIFIER, @Return_DidNameChange BIT;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    --SET @MUID = NEWID();  
    --EXEC mdm.udpEntitySaveByMUID 1, 'AADA7D02-CA0B-4A12-B23D-FB5676F0DA69', null, null, 'Entity1-1', @Return_ID OUTPUT, @Return_MUID OUTPUT;  
  
    EXEC mdm.udpEntitySaveByMUID 1, '8DDC258D-8831-45E3-AFF1-17B3BDB87556', NULL, 'F1644AF9-4DEE-4090-8FEA-3E9B75DE8900', 'Entity 2-22', @Return_CodeAttrMUID OUTPUT,   
        @Return_DidNameChange OUTPUT, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
  
    SELECT @Return_ID, @Return_MUID, @Return_CodeAttrMUID, @Return_DidNameChange;  
    SELECT * FROM mdm.tblEntity WHERE ID = @Return_ID;  
  
*/  
CREATE PROCEDURE [mdm].[udpEntitySaveByMUID]  
(  
    @User_ID	        	INT,  
    @Model_MUID		        UNIQUEIDENTIFIER,  
    @Model_Name	        	NVARCHAR(50) = NULL,  
    @Entity_MUID	        UNIQUEIDENTIFIER = NULL,  
    @Entity_Name	        NVARCHAR(50),  
    @StagingBase			NVARCHAR(60) = N'',  
    @CodeGenSeed            INT = NULL,  
    @Return_DidNameChange   BIT = NULL OUTPUT,  
    @Return_ID		        INT = NULL OUTPUT,  
    @Return_MUID	        UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    /*  
    Mode		@Entity_MUID		@Return_MUID  
    --------    ------------------  ------------------  
    Create		Empty Guid or null	Empty Guid or null  
    Clone		Empty Guid or null	Guid	  
    Update		Guid				n/a  
    */  
    DECLARE @Model_ID       INT,  
            @Entity_ID      INT,  
            @IsSystem       BIT,  
            @CurrentName    NVARCHAR(50),  
            @CurrentStagingBaseName NVARCHAR(60),  
            @ErrorMsg       NVARCHAR(250);  
  
    IF @Model_Name IS NULL AND @Model_MUID IS NULL --Missing Model identifier  
    BEGIN  
        RAISERROR('MDSERR200002|The entity cannot be saved. The model ID is not valid.', 16, 1);  
        RETURN;  
    END;        
        
    SELECT @Model_ID = ID FROM mdm.tblModel WHERE   
    (((@Model_MUID IS NULL) OR (MUID = @Model_MUID)) AND ((@Model_Name IS NULL) OR ([Name] =@Model_Name)));   
  
    --Test for invalid parameters  
    IF (@Model_ID IS NULL) --Invalid Model_MUID  
    BEGIN  
        --On error, return NULL results  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RAISERROR('MDSERR200002|The entity cannot be saved. The model ID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    IF (@Entity_MUID IS NOT NULL AND CAST(@Entity_MUID  AS BINARY) <> 0x0)  
    BEGIN  
        -- Update Mode  
        SELECT @Entity_ID = ID, @CurrentName = [Name], @CurrentStagingBaseName = StagingBase FROM mdm.tblEntity WHERE MUID = @Entity_MUID AND Model_ID = @Model_ID AND IsSystem = 0  
  
        IF @Entity_ID IS NULL   
        BEGIN  
            --On error, return NULL results  
            SELECT @Return_ID = NULL, @Return_MUID = NULL  
            RAISERROR('MDSERR200003|The entity cannot be saved. The entity ID is not valid.', 16, 1);  
            RETURN  
        END;  
    END;  
  
    SET @IsSystem = 0;  -- This proc does not add or update IsSystem Entities  
    EXEC mdm.udpEntitySave  @User_ID = @User_ID,   
                            @Entity_ID = @Entity_ID,   
                            @Model_ID = @Model_ID,   
                            @EntityName = @Entity_Name,   
                            @IsSystem = @IsSystem,   
                            @StagingBase = @StagingBase,   
                            @CodeGenSeed = @CodeGenSeed,   
                            @Return_ID = @Return_ID OUTPUT,   
                            @Return_MUID = @Return_MUID OUTPUT;  
      
    -- Return indicating whether the entity name was updated.  This is used in the API to determine if business rules should be refreshed.   
    IF (LTRIM(RTRIM(@CurrentName)) =  LTRIM(RTRIM(ISNULL(@Entity_Name, @CurrentName)))) OR (LTRIM(RTRIM(@CurrentStagingBaseName)) =  LTRIM(RTRIM(CASE WHEN LEN(@StagingBase) > 0 THEN @StagingBase ELSE @CurrentStagingBaseName END)))  
        SET @Return_DidNameChange = 0;  
    ELSE  
        SET @Return_DidNameChange = 1;  
  
  
    SET NOCOUNT OFF;  
END; --proc
GO
