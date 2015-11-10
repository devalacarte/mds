SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*    
==============================================================================    
 Copyright (c) Microsoft Corporation. All Rights Reserved.    
==============================================================================    
  
Description: Purge already deleted members for the specified model and version.  
   
EXEC mdm.udpDeletedMembersPurge @ModelName = N'Product', @VersionName = N'Version 1'     
    
*/    
CREATE PROCEDURE [mdm].[udpDeletedMembersPurge]  
(    
	@ModelName		NVARCHAR(50),  
	@VersionName	NVARCHAR(50)  
)    
WITH EXECUTE AS 'mds_schema_user'    
AS     
BEGIN    
    SET NOCOUNT ON;    
  
    DECLARE     
        @Model_ID						INT,  
		@Version_ID						INT,    
		@TranCounter					INT,  
		@SQL							NVARCHAR(MAX),  
		@DeletedStatus					NVARCHAR(2) = N'2',  
		@CurrentEntityID				INT,  
		@CurrentFlatFlag				BIT,	  
		@CurrentEntityTable				SYSNAME,  
		@CurrentHierarchyParentTable	SYSNAME,  
		@CurrentHierarchyTable			SYSNAME,  
		@CurrentCollectionMemberTable	SYSNAME,  
		@CurrentCollectionTable			SYSNAME,  
		@LeafMemberType					NVARCHAR(2) = N'1',  
		@ConsolidatedMemberType			NVARCHAR(2) = N'2';  
  
	CREATE TABLE #EntityTableNames    
    (    
		ID						INT,	  
		IsFlat					BIT,  
		EntityTable				NVARCHAR(128),  
		HierarchyParentTable	NVARCHAR(128) NULL,  
		HierarchyTable			NVARCHAR(128) NULL,  
		CollectionMemberTable	NVARCHAR(128) NULL,  
		CollectionTable			NVARCHAR(128) NULL  
    );  
  
	-- Get @Model_ID and Version_ID  
  
	SELECT @Model_ID = md.ID, @Version_ID = ver.ID  
	FROM mdm.tblModel md  
	JOIN mdm.tblModelVersion ver  
	ON md.ID = ver.Model_ID  
	WHERE md.Name = @ModelName AND ver.Name = @VersionName;  
  
	--Check invalid parameters    
    IF (@Model_ID IS NULL OR @Version_ID IS NULL)    
    BEGIN    
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);    
        RETURN(1);    
    END; --if    
  
	-- Pupulate Entity, Hierarchy Parent, and Hierarchy Relationship Table Names.  
  
	INSERT INTO #EntityTableNames  
	(  
		ID, IsFlat, EntityTable, HierarchyParentTable, HierarchyTable, CollectionMemberTable, CollectionTable  
	)  
	SELECT ID, IsFlat, EntityTable, HierarchyParentTable, HierarchyTable, CollectionMemberTable, CollectionTable  
	FROM mdm.tblEntity  
	WHERE Model_ID = @Model_ID;  
  
    --Start transaction, being careful to check if we are nested    
    SET @TranCounter = @@TRANCOUNT;  
	    
    IF @TranCounter > 0 SAVE TRANSACTION TX;    
    ELSE BEGIN TRANSACTION;  
   
	BEGIN TRY   
  
		-- Purge members.  
		WHILE EXISTS(SELECT 1 FROM #EntityTableNames)   
		BEGIN        
			SELECT TOP 1         
				@CurrentEntityID = ID,  
				@CurrentFlatFlag = IsFlat,      
				@CurrentEntityTable = EntityTable,  
				@CurrentHierarchyParentTable = HierarchyParentTable,  
				@CurrentHierarchyTable = HierarchyTable,  
				@CurrentCollectionMemberTable = CollectionMemberTable,  
				@CurrentCollectionTable = CollectionTable  
			FROM #EntityTableNames        
			ORDER BY ID;    
       
			IF @CurrentFlatFlag = 0   
			BEGIN   
				-- If there is a hierarchy, purge the leaf member from Hierarchy Relationship table.       
				SET @SQL = N'         
				DELETE FROM mdm.' + QUOTENAME(@CurrentHierarchyTable) + N'    
				FROM mdm.' + QUOTENAME(@CurrentHierarchyTable) + N' hr    
				INNER JOIN mdm.' + QUOTENAME(@CurrentEntityTable) + N' en     
				ON hr.Child_EN_ID = en.ID AND en.Version_ID = ' +  CONVERT(NVARCHAR(30), @Version_ID) + N'  
				WHERE ' + N' en.Status_ID = ' + @DeletedStatus + N'  
				AND ChildType_ID = ' + @LeafMemberType + ';';   
  
				EXEC sp_executesql @SQL;  
  
				-- If there is a hierarchy, purge the consolidated member from Hierarchy Relationship table.       
				SET @SQL = N'         
				DELETE FROM mdm.' + QUOTENAME(@CurrentHierarchyTable) + N'    
				FROM mdm.' + QUOTENAME(@CurrentHierarchyTable) + N' hr    
				INNER JOIN mdm.' + QUOTENAME(@CurrentHierarchyParentTable) + N' hp     
				ON hr.Child_HP_ID = hp.ID AND hp.Version_ID = ' +  CONVERT(NVARCHAR(30), @Version_ID) + N'  
				WHERE ' + N' hp.Status_ID = ' + @DeletedStatus + N'  
				AND ChildType_ID = ' + @ConsolidatedMemberType + ';';   
  
				EXEC sp_executesql @SQL;  
  
				-- Purge consolidated member security.    
				SET @SQL = N'   
				DELETE FROM mdm.tblSecurityRoleAccessMember    
				FROM mdm.tblSecurityRoleAccessMember sra    
				INNER JOIN mdm.' + QUOTENAME(@CurrentHierarchyParentTable) + N' hp     
				ON sra.Member_ID = hp.ID   
				AND sra.Entity_ID = ' + CONVERT(NVARCHAR(30), @CurrentEntityID) + N'  
				AND sra.HierarchyType_ID IN (0, 1) -- Derived and Explicit Hierarchy    
				AND sra.MemberType_ID = 2 -- Consolidated member type.  
				AND hp.Version_ID = ' +  CONVERT(NVARCHAR(30), @Version_ID) + N'    
				WHERE hp.Status_ID = ' + @DeletedStatus + N';';   
  
				EXEC sp_executesql @SQL;  
  
				-- Purge leaf members from collection member table.  
				SET @SQL = N'         
				DELETE FROM mdm.' + QUOTENAME(@CurrentCollectionMemberTable) + N'    
				FROM mdm.' + QUOTENAME(@CurrentCollectionMemberTable) + N' cm    
				INNER JOIN mdm.' + QUOTENAME(@CurrentEntityTable) + N' en     
				ON cm.Child_EN_ID = en.ID AND en.Version_ID = ' +  CONVERT(NVARCHAR(30), @Version_ID) + N'  
				WHERE ' + N' en.Status_ID = ' + @DeletedStatus + N';';   
  
				EXEC sp_executesql @SQL;  
  
				-- Purge consolidated members from collection member table.  
				SET @SQL = N'         
				DELETE FROM mdm.' + QUOTENAME(@CurrentCollectionMemberTable) + N'    
				FROM mdm.' + QUOTENAME(@CurrentCollectionMemberTable) + N' cm    
				INNER JOIN mdm.' + QUOTENAME(@CurrentHierarchyParentTable) + N' hp     
				ON cm.Child_HP_ID = hp.ID AND hp.Version_ID = ' +  CONVERT(NVARCHAR(30), @Version_ID) + N'  
				WHERE ' + N' hp.Status_ID = ' + @DeletedStatus + N';';   
  
				EXEC sp_executesql @SQL;  
  
				-- Purge members from collection table.  
				SET @SQL = N'DELETE FROM mdm.' + QUOTENAME(@CurrentCollectionTable) + N' WHERE Version_ID = ' + CONVERT(NVARCHAR(30), @Version_ID) + N' AND Status_ID = ' + @DeletedStatus + N';';    
  
				EXEC sp_executesql @SQL;  
  
				-- Purge consolidated members from each hierarchy parent member table.  
				SET @SQL = N'DELETE FROM mdm.' + QUOTENAME(@CurrentHierarchyParentTable) + N' WHERE Version_ID = ' + CONVERT(NVARCHAR(30), @Version_ID) + N' AND Status_ID = ' + @DeletedStatus + N';';    
  
				EXEC sp_executesql @SQL;  
  
			END; --IF    
  
			-- Purge leaf member security    
			SET @SQL = N'   
			DELETE FROM mdm.tblSecurityRoleAccessMember    
			FROM mdm.tblSecurityRoleAccessMember sra    
			INNER JOIN mdm.' + QUOTENAME(@CurrentEntityTable) + N' en     
			ON sra.Member_ID = en.ID   
			AND sra.Entity_ID = ' + CONVERT(NVARCHAR(30), @CurrentEntityID) + N'  
			AND sra.HierarchyType_ID IN (0, 1) -- Derived and Explicit Hierarchy    
			AND sra.MemberType_ID = 1 -- Leaf member type.  
			AND en.Version_ID = ' +  CONVERT(NVARCHAR(30), @Version_ID) + N'    
			WHERE en.Status_ID = ' + @DeletedStatus + N';';   
  
			EXEC sp_executesql @SQL;  
  
			-- Purge leaf members from each entity member table.  
			SET @SQL = N'DELETE FROM mdm.' + QUOTENAME(@CurrentEntityTable) + N' WHERE Version_ID = ' + CONVERT(NVARCHAR(30), @Version_ID) + N' AND Status_ID = ' + @DeletedStatus + N';';    
  
			EXEC sp_executesql @SQL;  
  
    
			SET @SQL = N'EXEC mdm.udpSecurityMemberProcessRebuildModelVersion ' +  CONVERT(NVARCHAR(30), @Version_ID) + N', 1;' -- 1 means Process immediately.    
  
			EXEC sp_executesql @SQL;  
  
			DELETE FROM #EntityTableNames  
			WHERE ID = @CurrentEntityID;  
  
		END; -- WHILE  
  
        --Commit only if we are not nested    
        IF @TranCounter = 0 COMMIT TRANSACTION;   
    END TRY  
	    
    BEGIN CATCH    
        -- Get error info  
        DECLARE  
            @ErrorMessage NVARCHAR(4000),  
            @ErrorSeverity INT,  
            @ErrorState INT;  
        EXEC mdm.udpGetErrorInfo  
            @ErrorMessage = @ErrorMessage OUTPUT,  
            @ErrorSeverity = @ErrorSeverity OUTPUT,  
            @ErrorState = @ErrorState OUTPUT;  
    
        IF @TranCounter = 0     
            ROLLBACK TRANSACTION;    
        ELSE IF XACT_STATE() <> -1     
            ROLLBACK TRANSACTION TX;    
                
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);    
        RETURN(1);    
            
    END CATCH    
  
    SET NOCOUNT OFF;    
END; --proc
GO
