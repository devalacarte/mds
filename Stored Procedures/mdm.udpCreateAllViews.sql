SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    This SPROC recreates all views, including subscription views  
  
	EXEC mdm.udpCreateAllViews;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpCreateAllViews]  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	--Defer view generation if we are in the middle of an upgrade or demo-rebuild  
	IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
		DECLARE @TempTable 	TABLE (RowNumber INT IDENTITY (1, 1) PRIMARY KEY CLUSTERED NOT NULL , ID INT NOT NULL);  
		DECLARE @TempID 	INT;  
  
		INSERT INTO @TempTable SELECT ID FROM mdm.tblModel ORDER BY ID DESC;  
  
		DECLARE @Counter INT = 1;  
		DECLARE @MaxCounter INT = (SELECT MAX(RowNumber) FROM @TempTable);  
		  
		WHILE @Counter <= @MaxCounter  
		BEGIN  
			SELECT @TempID = ID FROM @TempTable WHERE [RowNumber] = @Counter;  
			  
			EXEC mdm.udpCreateViews @TempID;  
  
			SET @Counter = @Counter +1;  
		END; --while  
		  
		DELETE FROM @TempTable  
		--DONT reset @counter since it's used below		  
		--Create Derived Hierachy Views  
		INSERT INTO @TempTable SELECT ID FROM mdm.tblDerivedHierarchy;  
		SELECT @MaxCounter =MAX(RowNumber) FROM @TempTable;  
		  
		WHILE @Counter <= @MaxCounter  
		BEGIN  
			SELECT @TempID = ID FROM @TempTable WHERE [RowNumber] = @Counter  
  
			EXEC mdm.udpCreateSystemDerivedHierarchyParentChildView @TempID;  
  
			SET @Counter = @Counter +1;  
  
		END; --while  
  
        -- Regenerate subscription views if there are any  
        IF EXISTS(SELECT * FROM [mdm].[tblSubscriptionView])  
        BEGIN  
            DECLARE @SubscriptionViewID       INT,   
                    @ViewEntity_ID            INT,  
                    @ViewModel_ID             INT,  
                    @DerivedHierarchy_ID      INT,  
                    @ViewFormat_ID            INT,  
                    @ModelVersion_ID          INT,  
                    @ModelVersionFlag_ID      INT,  
                    @SubscriptionViewName     sysname,  
                    @Levels                   INT;  
  
            --Table variable we use to iterate through subscription views  
            DECLARE @subscriptionViews TABLE     
            (    
                  ID                  INT NOT NULL,      
                  Entity_ID           INT NULL,  
                  Model_ID            INT NOT NULL,  
                  DerivedHierarchy_ID INT NULL,  
                  ViewFormat_ID       INT NOT NULL,  
                  ModelVersion_ID     INT NULL,  
                  ModelVersionFlag_ID INT NULL,  
                  Name                sysname NOT NULL,  
                  Levels              INT NULL  
            );            
              
            --Fill out the temp table with the subscription view definitions  
            INSERT INTO @subscriptionViews  
            (  
                ID, Entity_ID, Model_ID, DerivedHierarchy_ID, ViewFormat_ID, ModelVersion_ID, ModelVersionFlag_ID, Name, Levels  
            )  
            SELECT   
                ID,  
                Entity_ID,  
                Model_ID,  
                DerivedHierarchy_ID,  
                ViewFormat_ID,  
                ModelVersion_ID,  
                ModelVersionFlag_ID,  
                Name,  
                Levels  
            FROM   
            [mdm].[tblSubscriptionView];  
  
            --Iterate through the subscription view definitions  
            WHILE EXISTS(SELECT 1 FROM @subscriptionViews) BEGIN  
  
                SELECT TOP 1  
                    @SubscriptionViewID = ID,  
                    @ViewEntity_ID = Entity_ID,  
                    @ViewModel_ID = Model_ID,  
                    @DerivedHierarchy_ID = DerivedHierarchy_ID,  
                    @ViewFormat_ID = ViewFormat_ID,  
                    @ModelVersion_ID = ModelVersion_ID,  
                    @ModelVersionFlag_ID = ModelVersionFlag_ID,  
                    @SubscriptionViewName = Name,  
                    @Levels = Levels  
                FROM @subscriptionViews  
                ORDER BY ID;    
  
                --Call udpCreateSubscriptionViews to create each view  
                --The SPROCS udpCreateSubscriptionViews calls are smart enough to ALTER (instead of CREATE) if the view already exists  
                -- so there is no risk of us trying to recreate an existing view  
                EXEC [mdm].[udpCreateSubscriptionViews] @SubscriptionViewID, @ViewEntity_ID, @ViewModel_ID, @DerivedHierarchy_ID, @ModelVersion_ID, @ModelVersionFlag_ID, @ViewFormat_ID, @Levels, @SubscriptionViewName;  
  
                DELETE FROM @subscriptionViews WHERE ID = @SubscriptionViewID  
  
            END; -- WHILE  
        END; --IF EXISTS(SELECT * FROM [mdm].[tblSubscriptionView])  
  
	END; --if  
  
	SET NOCOUNT OFF;  
END; --proc
GO
