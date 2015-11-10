SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
		EXEC mdm.udpCreateSubscriptionViews 1,1,1,1,1, 'TEST'  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpCreateSubscriptionViews]  
(  
	@SubscriptionView_ID	INT = NULL,   
	@Entity_ID				INT,  
	@Model_ID				INT,  
	@DerivedHierarchy_ID	INT,  
	@ModelVersion_ID		INT,  
	@ModelVersionFlag_ID	INT,  
	@ViewFormat_ID			INT,  
	@Levels					INT,  
	@SubscriptionViewName	sysname  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
  
	--Defer view generation if we are in the middle of an upgrade or demo-rebuild  
	IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
      
		-- Views for Entity  
		IF (@Entity_ID IS NOT NULL) BEGIN  
		  
			DECLARE @IsFlat 		BIT;  
  
			SELECT @IsFlat = IsFlat   
			FROM tblEntity E  
			WHERE E.ID = @Entity_ID;  
		  
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
			  
			  
			  
			-- Leaf attributes  
			IF (@ViewFormat_ID = 1)  
				EXEC mdm.udpCreateAttributeViews @Entity_ID, 1, @Model_ID, @ModelVersion_ID, @ModelVersionFlag_ID, @SubscriptionViewName; --Leaf  
  
			IF @IsFlat = 0 BEGIN  
				  
				IF (@ViewFormat_ID = 2)  
					EXEC mdm.udpCreateAttributeViews @Entity_ID, 2, @Model_ID, @ModelVersion_ID, @ModelVersionFlag_ID, @SubscriptionViewName; --Consolidated  
  
				IF (@ViewFormat_ID = 3)  
					EXEC mdm.udpCreateAttributeViews @Entity_ID, 3, @Model_ID, @ModelVersion_ID, @ModelVersionFlag_ID, @SubscriptionViewName; --Collection  
				  
				IF (@ViewFormat_ID =4)  
					EXEC mdm.udpCreateCollectionViews @Entity_ID, @Model_ID, @ModelVersion_ID, @ModelVersionFlag_ID, @SubscriptionViewName;   
  
				IF (@ViewFormat_ID =5)  
					EXEC mdm.udpCreateParentChildViews @Entity_ID, @Model_ID, @ModelVersion_ID, @ModelVersionFlag_ID, @SubscriptionViewName;  
				  
				IF (@ViewFormat_ID =6)  
					EXEC mdm.udpCreateLevelViews @Entity_ID, @Levels, @Model_ID, @ModelVersion_ID, @ModelVersionFlag_ID, @SubscriptionViewName;  
				  
  
			END; --if  
		  
		END   
		--Views for Derived Hierarchy  
		ELSE BEGIN  
		  
				IF (@ViewFormat_ID =7)  
					EXEC mdm.udpCreateDerivedHierarchyParentChildView @DerivedHierarchy_ID, @Model_ID, @ModelVersion_ID, @ModelVersionFlag_ID,	@SubscriptionViewName;  
				  
				IF (@ViewFormat_ID = 8)  
					EXEC mdm.udpCreateDerivedHierarchyLevelView @DerivedHierarchy_ID, @Levels, @Model_ID, @ModelVersion_ID, @ModelVersionFlag_ID,	@SubscriptionViewName;  
		  
		END  
		  
        -- update isDirty flag  
	    IF (@SubscriptionView_ID IS NOT NULL)  
            UPDATE mdm.tblSubscriptionView  
            SET IsDirty = 0  
            WHERE ID = @SubscriptionView_ID  
		  
	END; --if  
  
	SET NOCOUNT OFF;  
END; --proc
GO
