SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	EXEC udpCreateSystemLevelViews 1;  
	EXEC udpCreateSystemLevelViews 11111; --invalid  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpCreateSystemLevelViews]   
(  
	@Entity_ID	INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	--Defer view generation if we are in the middle of an upgrade or demo-rebuild  
	IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
		DECLARE @EntityTable  			sysname,  
				@HierarchyParentTable  	sysname,  
				@HierarchyTable  		sysname,  
				@TempTableJoinString 	NVARCHAR(MAX),  
				@TempRootJoin 			NVARCHAR(MAX),  
				@TempSelectString 		NVARCHAR(MAX),  
				@TempWhereString 		NVARCHAR(MAX),  
				@SQL					NVARCHAR(MAX),  
				@TempCounter  			INT,  
				@TempCounterString      NVARCHAR(30),  
				@TempCounterStringPrevious NVARCHAR(30),  
				@TempValue 				INT,  
				@ViewName				sysname;  
  
		SELECT	  
			@EntityTable = E.EntityTable,  
			@HierarchyParentTable = E.HierarchyParentTable,  
			@HierarchyTable = E.HierarchyTable,  
			@ViewName = N'viw_SYSTEM_' + CONVERT(NVARCHAR(30), M.ID) + N'_' + CONVERT(NVARCHAR(30), E.ID) + N'_LEVELS',  
			@TempCounter = 1,  
			@TempSelectString = N'',  
			@TempTableJoinString = N''  
		FROM mdm.tblEntity E  
		INNER JOIN mdm.tblModel M ON (E.Model_ID = M.ID)  
		WHERE E.ID = @Entity_ID AND E.IsFlat = 0;  
  
		IF @ViewName IS NOT NULL BEGIN --Ensure row actually exists  
  
			WHILE @TempCounter < 12	BEGIN  
			    SET @TempCounterString = CONVERT(NVARCHAR(30), @TempCounter);  
			    SET @TempCounterStringPrevious = CONVERT(NVARCHAR(30), @TempCounter-1);  
				SET @TempSelectString += N'  
					CASE   
						WHEN EN' + @TempCounterString + N'.ID IS NOT NULL   
						THEN EN' + @TempCounterString + N'.Code   
						WHEN HP' + @TempCounterString + N'.ID IS NOT NULL THEN HP' + @TempCounterString + N'.Code   
						ELSE NULL   
					END AS L' + @TempCounterString + N','  
				SET @TempTableJoinString += N'  
					LEFT JOIN mdm.' + quotename(@HierarchyTable) + N' H' + @TempCounterString + N'   
						ON H' + @TempCounterString + N'.Version_ID = H' + @TempCounterStringPrevious + N'.Version_ID  
						AND H' + @TempCounterString + N'.Hierarchy_ID = H' + @TempCounterStringPrevious + N'.Hierarchy_ID  
						AND H' + @TempCounterStringPrevious + N'.ChildType_ID = 2						  
						AND H' + @TempCounterString + N'.Parent_HP_ID = H' + @TempCounterStringPrevious + N'.Child_HP_ID   
						AND H' + @TempCounterString + N'.Status_ID = H' + @TempCounterStringPrevious + N'.Status_ID  
					LEFT JOIN mdm.' + quotename(@EntityTable) + N' EN' + @TempCounterString + N'   
						ON H' + @TempCounterString + N'.Version_ID = EN' + @TempCounterString + N'.Version_ID  
						AND H' + @TempCounterString + N'.ChildType_ID = 1 						  
						AND H' + @TempCounterString + N'.Child_EN_ID = EN' + @TempCounterString + N'.ID   
						AND H' + @TempCounterString + N'.Status_ID = EN' + @TempCounterString + N'.Status_ID  
						AND EN' + @TempCounterString + N'.Status_ID = 1  
					LEFT JOIN mdm.' + quotename(@HierarchyParentTable) + N' HP' + @TempCounterString + N'   
						ON H' + @TempCounterString + N'.Version_ID = HP' + @TempCounterString + N'.Version_ID  
						AND H' + @TempCounterString + N'.ChildType_ID = 2 						  
						AND H' + @TempCounterString + N'.Child_HP_ID = HP' + @TempCounterString + N'.ID   
						AND H' + @TempCounterString + N'.Status_ID = HP' + @TempCounterString + N'.Status_ID   
						AND HP' + @TempCounterString + N'.Status_ID = 1  
					';				  
				SET @TempCounter += 1;  
			END; --if  
		    	  
			SET @TempWhereString = N' WHERE H0.Parent_HP_ID IS NULL';  
  
			SET @TempSelectString = LEFT(@TempSelectString, LEN(@TempSelectString)-1);  
  
			SET @SQL = CASE   
				WHEN EXISTS(SELECT 1 FROM sys.views WHERE [name] = @ViewName AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER'  
				ELSE N'CREATE' END + N' VIEW mdm.' + quotename(@ViewName) + N'  
				/*WITH ENCRYPTION*/   
				AS SELECT  
					H0.Version_ID,H.Name,H0.ID,''<ROOT>'' AS ROOT,   
					CASE   
						WHEN EN0.ID IS NOT NULL THEN EN0.Code   
						ELSE HP0.Code   
					END AS L0, --case  
					' + @TempSelectString + N'  
				FROM mdm.' + quotename(@HierarchyTable) + N' H0   
				INNER JOIN mdm.tblHierarchy AS H ON H.ID = H0.Hierarchy_ID   
				LEFT JOIN mdm.' + quotename(@EntityTable) + N' AS EN0 ON H0.Version_ID = EN0.Version_ID   
					AND H0.ChildType_ID = 1   
					AND H0.Child_EN_ID = EN0.ID   
					AND H0.Status_ID = EN0.Status_ID   
					AND EN0.Status_ID = 1   
				LEFT JOIN mdm.' + quotename(@HierarchyParentTable) + N' AS HP0 ON H0.Version_ID = HP0.Version_ID   
					AND H0.ChildType_ID = 2   
					AND H0.Child_HP_ID = HP0.ID   
					AND H0.Status_ID = HP0.Status_ID   
					AND HP0.Status_ID = 1   
				' + @TempTableJoinString + N' ' + @TempWhereString + N';';  
  
			--PRINT(@SQL);  
			EXEC sp_executesql @SQL;  
  
		END; ---if  
  
	END; --if  
		  
	SET NOCOUNT OFF;  
END; --proc
GO
