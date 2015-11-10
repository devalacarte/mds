SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
 Wrapper for udpVersionSave sproc.  
*/  
CREATE PROCEDURE [mdm].[udpVersionSaveByMUID]  
(  
    @User_ID				INT,  
    @Model_MUID				UNIQUEIDENTIFIER,  
    @Version_MUID			UNIQUEIDENTIFIER = NULL,  
    @CurrentVersion_MUID	UNIQUEIDENTIFIER = NULL,  
    @Status_ID			    INT = NULL,  
    @Name					NVARCHAR(50) = NULL,  
    @Description			NVARCHAR(250) = NULL,  
    @VersionFlag_MUID		UNIQUEIDENTIFIER = NULL,  
    @Return_ID				INT = NULL OUTPUT,  
    @Return_MUID			UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
DECLARE  
    @Model_ID			INT,  
    @Version_ID			INT,  
    @CurrentVersion_ID  INT,  
    @VersionFlag_ID		INT;  
  
    DECLARE @EmptyMuid UNIQUEIDENTIFIER SET @EmptyMuid = CONVERT(UNIQUEIDENTIFIER, 0x0);  
  
    SELECT @Model_ID = ID FROM mdm.tblModel WHERE MUID = @Model_MUID AND IsSystem = 0;  
      
    SELECT @Version_ID = ID FROM mdm.tblModelVersion WHERE MUID = @Version_MUID AND Model_ID = @Model_ID;  
    SELECT @CurrentVersion_ID = ID FROM mdm.tblModelVersion WHERE MUID = @CurrentVersion_MUID AND Model_ID = @Model_ID;  
  
    IF @VersionFlag_MUID IS NOT NULL AND @VersionFlag_MUID <> @EmptyMuid  
    BEGIN  
        SELECT @VersionFlag_ID = ID FROM mdm.tblModelVersionFlag WHERE MUID = @VersionFlag_MUID;  
        IF (@VersionFlag_ID IS NULL) --Invalid Version_MUID  
        BEGIN  
            --On error, return NULL results  
            SELECT @Return_ID = NULL, @Return_MUID = NULL;  
            RAISERROR('MDSERR200070|The version cannot be saved. The version flag ID is not valid.', 16, 1);  
            RETURN;  
        END  
    END; --if        
      
    --Test for invalid parameters  
    IF (@Model_ID IS NULL) --Invalid Model_MUID  
    BEGIN  
        --On error, return NULL results  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RAISERROR('MDSERR200004|The version cannot be saved. The model ID is not valid.', 16, 1);  
        RETURN;  
    END; --if        
  
    IF (@Version_MUID IS NOT NULL AND @Version_MUID <> @EmptyMuid AND @Version_ID IS NULL) --Invalid Version_MUID  
    BEGIN  
        --On error, return NULL results  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RAISERROR('MDSERR200005|The version cannot be saved. The version ID is not valid.', 16, 1);  
        RETURN;  
    END; --if        
  
    EXEC mdm.udpVersionSave @User_ID, @Model_ID, @Version_ID, @CurrentVersion_ID, @Status_ID, @Name, @Description, @VersionFlag_ID, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
