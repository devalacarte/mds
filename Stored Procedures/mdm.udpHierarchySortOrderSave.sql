SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Friday, June 2, 2006  
Procedure  : mdm.udpHierarchySortOrderSave  
Component  : Import (Staging)  
Description: mdm.udpHierarchySortOrderSave recalculates the sort order for an entire hierarchy.  It assumes that the level number is current and correct.  
Parameters : Model Version ID, Hierarchy ID  
Return     : N/A  
Example    : EXEC mdm.udpHierarchySortOrderSave 1, 1  
*/  
  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpHierarchySortOrderSave]  
(  
   @Version_ID   INT,  
   @Hierarchy_ID INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @SQL             NVARCHAR(MAX) --SQL string     
	DECLARE @tblRelationship sysname    --Hierarchy relationships table  
	DECLARE @Entity_ID       INT            --Entity ID  
  
	SELECT @Entity_ID = Entity_ID FROM mdm.tblHierarchy WHERE ID = @Hierarchy_ID  
	SELECT @tblRelationship = HierarchyTableName FROM [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Entity_ID  
  
  
	--Temporary table to store list of descendants  
	CREATE TABLE #tblHierarchy   
	(  
		LevelNumber SMALLINT,   
		ID INT,   
		Parent_ID INT,   
		Descendants INT,   
		Child_ID INT,   
		SeqNum INT IDENTITY (1, 1),   
		PriorParent_ID INT,   
		FirstChildSeqNum INT,   
		InitSortOrder INT NOT NULL DEFAULT 1  
	);  
  
	SET @SQL = N'  
		INSERT INTO #tblHierarchy   
		(  
			LevelNumber,   
			ID,   
			Parent_ID,   
			Descendants,   
			Child_ID  
		)   
		SELECT   
			tSource.LevelNumber,   
			tSource.ID,   
			tSource.Parent_HP_ID,   
			tDerived.Descendants,   
			CASE tSource.ChildType_ID WHEN 1 THEN tSource.Child_EN_ID WHEN 2 THEN tSource.Child_HP_ID END  
		FROM mdm.' + quotename(@tblRelationship) + N' AS tSource   
		INNER JOIN (  
				SELECT LevelNumber, Parent_HP_ID, COUNT(*) AS Descendants   
				FROM mdm.' + quotename(@tblRelationship) + N'   
				WHERE Version_ID = @Version_ID   
					AND Hierarchy_ID = @Hierarchy_ID   
				GROUP BY Parent_HP_ID, LevelNumber  
			) AS tDerived  
			ON tSource.Parent_HP_ID = tDerived.Parent_HP_ID  
		WHERE Version_ID = @Version_ID   
			AND Hierarchy_ID = @Hierarchy_ID  
		ORDER BY   
			tSource.Parent_HP_ID, tSource.SortOrder, tSource.LastChgDTM;';  
	EXEC sp_executesql @SQL, N'@Version_ID INT, @Hierarchy_ID INT', @Version_ID, @Hierarchy_ID;  
  
	--Compute initial sort order  
	UPDATE #tblHierarchy SET InitSortOrder = SeqNum % Descendants + 1  
  
	--Compute prior parent ID  
	UPDATE tOrig SET PriorParent_ID = tDerived.Parent_ID FROM #tblHierarchy tOrig JOIN #tblHierarchy tDerived ON tOrig.SeqNum-1 = tDerived.SeqNum  
  
	--Compute first child sequence number  
	UPDATE tOrig SET FirstChildSeqNum = tDerived.MinSeqNum   
	FROM #tblHierarchy tOrig   
	   JOIN (SELECT Parent_ID, MIN(SeqNum) MinSeqNum FROM #tblHierarchy GROUP BY Parent_ID) tDerived ON tOrig.Parent_ID = tDerived.Parent_ID  
  
	SET @SQL = N'  
		UPDATE tSource SET   
			SortOrder = tDerived.SortOrder   
		FROM mdm.' + quotename(@tblRelationship) + N' AS tSource   
		INNER JOIN (  
				SELECT ID, SeqNum - FirstChildSeqNum + 1 AS SortOrder   
				FROM #tblHierarchy  
			) AS tDerived  
			ON tSource.ID = tDerived.ID   
		WHERE Version_ID = @Version_ID   
			AND Hierarchy_ID = @Hierarchy_ID   
			AND tSource.SortOrder <> tDerived.SortOrder;';  
			  
	EXEC sp_executesql @SQL, N'@Version_ID INT, @Hierarchy_ID INT', @Version_ID, @Hierarchy_ID;  
  
	DROP TABLE #tblHierarchy;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
