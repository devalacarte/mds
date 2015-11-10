SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Wrapper for udpAttributeGroupSave  
*/  
CREATE PROCEDURE [mdm].[udpAttributeGroupSaveByMUID]  
(  
    @User_ID			INT,  
    @Model_MUID			UNIQUEIDENTIFIER,  
    @Model_Name			NVARCHAR(50) = NULL,  
    @Entity_MUID		UNIQUEIDENTIFIER,   
    @Entity_Name		NVARCHAR(50),  
    @MemberType_ID		TINYINT = NULL,  
    @MUID				UNIQUEIDENTIFIER = NULL,  
    @Name				NVARCHAR(50),  
    @SortOrder			INT = NULL,  
    @FreezeNameCode		BIT = 0,  
    @IsSystem			BIT = 0,  
    @Return_ID			INT = NULL OUTPUT,  
    @Return_MUID		UNIQUEIDENTIFIER = NULL OUTPUT  
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
    DECLARE @AttributeGroup_ID INT,  
            @Entity_ID INT,  
            @Model_ID INT;  
        
    SELECT @Entity_ID =  mdm.udfEntityGetIDByName(@Model_MUID, @Model_Name, @Entity_MUID, @Entity_Name)  
      
    IF (@Entity_ID = -3)--Invalid Model_MUID  
    BEGIN  
        --On error, return NULL results  
        SELECT @MUID = NULL, @Return_MUID = NULL, @Name = NULL;  
        RAISERROR('MDSERR200017|The attribute group cannot be saved. The model ID is not valid.', 16, 1);  
        RETURN;  
    END  
      
    IF (@Entity_ID = -2) --Invalid Entity_MUID  
    BEGIN  
        --On error, return NULL results  
        SELECT @MUID = NULL, @Return_MUID = NULL, @Name = NULL;  
        RAISERROR('MDSERR200018|The attribute group cannot be saved. The entity ID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    SELECT @AttributeGroup_ID = ID from mdm.tblAttributeGroup WHERE MUID = @MUID AND Entity_ID = @Entity_ID AND IsSystem = 0;  
    SELECT @MemberType_ID = ID FROM mdm.tblEntityMemberType WHERE ID = @MemberType_ID;  
  
    IF (@MemberType_ID IS NULL) --Invalid MemberType  
    BEGIN  
        --On error, return NULL results  
        SELECT @MUID = NULL, @Return_MUID = NULL, @Name = NULL;  
        RAISERROR('MDSERR200020|The attribute group cannot be saved. The member type is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    IF (@MUID IS NOT NULL AND CAST(@MUID AS BINARY) <> 0x0)  
    BEGIN  
        -- Update Mode  
        SELECT @AttributeGroup_ID = ID from mdm.tblAttributeGroup WHERE MUID = @MUID AND Entity_ID = @Entity_ID;  
  
        IF @AttributeGroup_ID IS NULL   
        BEGIN  
            --On error, return NULL results  
            SELECT @MUID = NULL, @Return_MUID = NULL, @Name = NULL;  
            RAISERROR('MDSERR200019|The attribute group cannot be saved. The attribute ID is not valid.', 16, 1);  
            RETURN;  
        END;  
    END;  
  
    EXEC mdm.udpAttributeGroupSave @User_ID, @AttributeGroup_ID, @Entity_ID, @MemberType_ID, @Name, @SortOrder, @FreezeNameCode, @IsSystem, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
