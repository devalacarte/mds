SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Wrapper for mdm.udpDerivedHierarchyDetailSave proc.  
*/  
CREATE PROCEDURE [mdm].[udpDerivedHierarchyDetailSaveByMUID]  
(  
	@User_ID				INT,  
	@Model_MUID				UNIQUEIDENTIFIER,  
	@Model_Name				NVARCHAR(50) = NULL,  
	@DerivedHierarchy_MUID	UNIQUEIDENTIFIER,  
	@DerivedHierarchy_Name	NVARCHAR(50) = NULL,  
	@MUID               	UNIQUEIDENTIFIER,  
	@Name                   NVARCHAR(50),  
	@DisplayName            NVARCHAR(100),  
	@ForeignEntity_MUID		UNIQUEIDENTIFIER,   
	@ForeignEntity_Name		NVARCHAR(50),  
	@Foreign_Name		    NVARCHAR(50),  
	@Foreign_MUID			UNIQUEIDENTIFIER,  
	@ForeignType_ID			INT,  
	@IsVisible				BIT,  
    @Return_ID	            INT = NULL OUTPUT,  
    @Return_MUID            UNIQUEIDENTIFIER = NULL OUTPUT  
  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	/*  
	Mode		@DerivedHierarchy_MUID  @Return_MUID  
	--------    ----------------------  ------------------  
	Create		Empty Guid or null	    Empty Guid or null  
	Clone		Empty Guid or null	    Guid	  
	Update		Guid				    n/a  
	*/  
  
       
    DECLARE @Level_ID INT,  
            @Hierarchy_ID INT,  
            @Model_ID INT,  
        	@ForeignParent_ID INT,  
	        @Foreign_ID INT;  
        
	/************************************************/  
	/*@ForeignType_ID is Common.HierarchyItemType   */  
	/************************************************/  
    DECLARE @HierarchyItemType_Entity          INT  SET @HierarchyItemType_Entity = 0;  
    DECLARE @HierarchyItemType_DBA             INT  SET @HierarchyItemType_DBA = 1;  
    DECLARE @HierarchyItemType_Hierarchy       INT  SET @HierarchyItemType_Hierarchy = 2;  
    DECLARE @HierarchyItemType_ConsolidatedDBA INT  SET @HierarchyItemType_ConsolidatedDBA = 3;  
  
  
	IF (@Model_Name IS NOT NULL OR @Model_MUID IS NOT NULL) AND (@DerivedHierarchy_Name IS NOT NULL)   
	BEGIN  
        SELECT @Model_ID = mdm.udfModelGetIDByName(@Model_MUID, @Model_Name)   
  
		IF (@Model_ID IS NULL) --Invalid Model_MUID  
		BEGIN  
			--On error, return NULL results  
			SELECT @Return_ID = NULL, @Return_MUID = NULL;  
			RAISERROR('MDSERR200053|The hierarchy level cannot be saved. The model ID is not valid.', 16, 1);  
			RETURN;  
  
		END  
  
		SELECT @Hierarchy_ID = ID FROM mdm.tblDerivedHierarchy WHERE [Name] = @DerivedHierarchy_Name AND Model_ID = @Model_ID;  
  
		IF (@Hierarchy_ID IS NULL) --Invalid DerivedHierarchy_Name  
		BEGIN  
			--On error, return NULL results  
			SELECT @Return_ID = NULL, @Return_MUID = NULL;  
			RAISERROR('MDSERR200054|The derived hierarchy level cannot be saved. The derived hierarchy ID is not valid.', 16, 1);  
			RETURN;  
		END  
	END  
	ELSE  
	BEGIN  
  
		SELECT @Hierarchy_ID = ID, @Model_ID = Model_ID FROM mdm.tblDerivedHierarchy WHERE MUID = @DerivedHierarchy_MUID;  
  
		IF (@Hierarchy_ID IS NULL) --Invalid DerivedHierarchy_MUID  
		BEGIN  
			--On error, return NULL results  
			SELECT @Return_ID = NULL, @Return_MUID = NULL;  
			RAISERROR('MDSERR200054|The derived hierarchy level cannot be saved. The derived hierarchy ID is not valid.', 16, 1);  
			RETURN;  
		END;  
	END  
  
	IF (@MUID IS NOT NULL AND @MUID <> CONVERT(UNIQUEIDENTIFIER, 0x0))  
	BEGIN  
		-- Update Mode  
	    SELECT  @Level_ID = ID FROM mdm.tblDerivedHierarchyDetail WHERE MUID = @MUID AND DerivedHierarchy_ID = @Hierarchy_ID;  
  
		IF @Level_ID IS NULL   
		BEGIN  
			--On error, return NULL results  
			SELECT @Return_ID = NULL, @Return_MUID = NULL;  
			RAISERROR('MDSERR200055|The derived hierarchy level cannot be saved. The derived hierarchy level ID is not valid.', 16, 1);  
			RETURN;  
		END;  
  
	END;  
  
    SELECT  @Foreign_ID = CASE @ForeignType_ID  
        WHEN @HierarchyItemType_Entity          THEN (SELECT mdm.udfEntityGetIDByName(@Model_MUID, @Model_Name, @Foreign_MUID, @Foreign_Name))  
        WHEN @HierarchyItemType_DBA             THEN (SELECT mdm.udfAttributeGetIDByName(@Model_MUID, @Model_Name, @ForeignEntity_MUID, @ForeignEntity_Name, @Foreign_MUID, @Foreign_Name, 1, 0))  
        WHEN @HierarchyItemType_Hierarchy       THEN (SELECT mdm.udfHierarchyGetIDByName(@Model_MUID, @Model_Name, @ForeignEntity_MUID, @ForeignEntity_Name, @Foreign_MUID, @Foreign_Name))  
        WHEN @HierarchyItemType_ConsolidatedDBA THEN (SELECT mdm.udfAttributeGetIDByName(@Model_MUID, @Model_Name, @ForeignEntity_MUID, @ForeignEntity_Name, @Foreign_MUID, @Foreign_Name, 2, 0))  
    END;   
	IF ISNULL(@Foreign_ID, -1) < 0   
	BEGIN  
		--On error, return NULL results  
		SELECT @Return_ID = NULL, @Return_MUID = NULL;  
		RAISERROR('MDSERR200063|The derived hierarchy level cannot be saved. The Foreign ID is not valid.', 16, 1);  
		RETURN;  
	END;  
  
    EXEC mdm.udpDerivedHierarchyDetailSave @User_ID, @Level_ID, @Hierarchy_ID, @Foreign_ID, @ForeignType_ID,   
            @Name, @DisplayName, @IsVisible, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
  
	SET NOCOUNT OFF  
END --proc
GO
