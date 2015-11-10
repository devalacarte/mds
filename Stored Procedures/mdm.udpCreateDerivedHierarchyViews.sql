SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	EXEC mdm.udpCreateDerivedHierarchyViews 3;  
	EXEC mdm.udpCreateDerivedHierarchyViews 4;  
	EXEC mdm.udpCreateDerivedHierarchyViews 5;  
	SELECT * FROM mdm.tblModel;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
  
CREATE PROCEDURE [mdm].[udpCreateDerivedHierarchyViews]  
(  
	@Model_ID	INT,  
	@Entity_ID	INT=0 --any non zero value results in only that entity being generated  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	--Defer view generation if we are in the middle of an upgrade or demo-rebuild  
	IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
		DECLARE @TempID INT;  
		DECLARE @TempTable TABLE (RowNumber INT IDENTITY (1, 1) PRIMARY KEY CLUSTERED NOT NULL, ID INT NOT NULL);  
  
		IF @Entity_ID = 0   
		BEGIN  
    		INSERT INTO @TempTable(ID)  
	    	SELECT ID FROM mdm.tblDerivedHierarchy WHERE Model_ID = @Model_ID;  
        END  
        ELSE BEGIN  
    		INSERT INTO @TempTable(ID)  
            SELECT DISTINCT Hierarchy_ID from mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS  
            WHERE [Object_ID] = 3 -- Entity  
            AND Foreign_ID = @Entity_ID  
            AND Model_ID = @Model_ID;  
        END  
  
		DECLARE @Counter INT = 1;  
		DECLARE @MaxCounter INT = (SELECT MAX(RowNumber) FROM @TempTable);  
  
		WHILE @Counter <= @MaxCounter  
        BEGIN  
			SELECT @TempID = ID FROM @TempTable WHERE [RowNumber] = @Counter;  
			EXEC mdm.udpCreateSystemDerivedHierarchyParentChildView @TempID;  
            SET @Counter += 1;  
		END; --while  
  
	END; --if  
  
	SET NOCOUNT OFF;  
END; --proc
GO
