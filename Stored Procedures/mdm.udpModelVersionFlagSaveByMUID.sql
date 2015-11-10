SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpModelVersionFlagSaveByMUID '1', '1565655D-4B03-4F64-B37F-956F75BF396D', '9910CA76-763A-4029-B81A-B54E20EFD8B0', 1, 'JV Model 1', 'Product - joint venture model #1', 1  
    EXEC mdm.udpModelVersionFlagSaveByMUID '1', Null, '08DB8C45-1EA7-4C5A-9F21-4D4095EA2391', 1, 'Test', 'Product - Test flag', 0  
  
    SELECT * FROM mdm.viw_SYSTEM_SCHEMA_VERSION_FLAGS  
*/  
CREATE PROCEDURE [mdm].[udpModelVersionFlagSaveByMUID]  
(  
    @User_ID            INT,  
    @Model_MUID			UNIQUEIDENTIFIER,  
    @Model_Name			NVARCHAR(50) = NULL,  
    @MUID 				UNIQUEIDENTIFIER = NULL,  
    @Name 				NVARCHAR(50),  
    @Status_ID 			TINYINT,  
    @Description 		NVARCHAR(500),  
    @IsCommittedOnly 	BIT,  
    @Return_ID			INT = NULL OUTPUT,  
    @Return_MUID		UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    /*  
    Mode		@MUID				@Return_MUID  
    --------    ------------------  ------------------  
    Create		Empty Guid or null	Empty Guid or null  
    Clone		Empty Guid or null	Guid	  
    Update		Guid				n/a  
    */  
    DECLARE @VersionFlag_ID		INT,  
            @Model_ID			INT,  
            @CommittedOnly_ID	TINYINT;  
  
    IF @Model_Name IS NULL AND @Model_MUID IS NULL --Missing Model identifier  
    BEGIN  
        RAISERROR('MDSERR200006|The version flag cannot be saved. The model ID is not valid.', 16, 1);  
        RETURN;  
    END;        
  
    SELECT @Model_ID = ID  FROM mdm.tblModel WHERE (  
        ((@Model_MUID IS NULL) OR (MUID = @Model_MUID))   
            AND ((@Model_Name IS NULL) OR ([Name] = @Model_Name))) AND IsSystem = 0;  
  
    IF (@Model_ID IS NULL) --Invalid Model_MUID  
    BEGIN  
        RAISERROR('MDSERR200006|The version flag cannot be saved. The model ID is not valid.', 16, 1);  
        RETURN;  
    END;        
  
    IF (@MUID IS NOT NULL AND CAST(@MUID  AS BINARY) <> 0x0)  
    BEGIN  
        -- Update Mode  
        SELECT @VersionFlag_ID = ID FROM mdm.tblModelVersionFlag WHERE MUID = @MUID AND Model_ID = @Model_ID;  
  
  
        IF @VersionFlag_ID IS NULL   
        BEGIN  
            RAISERROR('MDSERR200007|The version flag cannot be saved. The version flag ID is not valid.', 16, 1);  
            RETURN;  
        END;  
    END;  
  
    SELECT @CommittedOnly_ID = CAST(@IsCommittedOnly AS TINYINT);  
  
    EXEC mdm.udpModelVersionFlagSave @User_ID, @VersionFlag_ID, @Model_ID, @Status_ID, @Name, @Description, @CommittedOnly_ID, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
