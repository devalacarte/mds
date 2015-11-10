SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EDM-1075 (10/21/2005): Generate level-based subscription views based on number of levels in hierarchy.  
EDM-1027 (10/21/2005): Remove limit on number of levels in the Level-based subscription views.  
------------------------------------------------------------------------------------------------------  
This procedure constructs a hierarchy tree for a given member.  Then it determines the level - within   
the hierarchy - associated with the member.  If requested the corresponding member is updated.  
	EXEC mdm.udpHierarchyMemberLevelSave 21, 17, 0, 2  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpHierarchyMemberLevelSave]  
(  
   @Version_ID    INT,  
   @Hierarchy_ID  INT,  
   @Member_ID     INT,  
   @MemberType_ID TINYINT, --MemberType_ID: 1=EN, 2=HP, 3=CN  
   @MemberLevel   SMALLINT = NULL OUTPUT --Newly calculated level number; note: -1 indicates 'ROOT'.  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE   
		 @strSQL			NVARCHAR(MAX)	--SQL string     
		,@Entity_ID			INT				--Entity ID  
		,@tblRelationship	sysname			--Hierarchy relationships table  
		,@Level				SMALLINT		--Counter variable   
		,@MaxLevelNew		SMALLINT;		--Recalculated (new) maximum level number  
  
	--Assign local variables  
	SELECT @Entity_ID = Entity_ID FROM mdm.tblHierarchy WHERE ID = @Hierarchy_ID;  
	SELECT @tblRelationship = HierarchyTableName FROM [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Entity_ID;  
  
	--Temporary table to store list of ascendants (ancestors)  
	CREATE TABLE #tblHierarchy   
	(  
		ID				INT,   
		MemberType_ID	INT,   
		[Level]			SMALLINT  
	);  
  
	--Create base record  
	INSERT INTO #tblHierarchy(ID, MemberType_ID, [Level])  
	SELECT @Member_ID, @MemberType_ID, 0; --0, 1, 0  
  
	SET @Level = 1;  
	  
	--Create first level (if it exists)	  
	SET @strSQL = N'  
		INSERT INTO #tblHierarchy(ID, MemberType_ID, [Level])  
		SELECT   
			Parent_HP_ID,   
			2,   
			1   
		FROM mdm.' + quotename(@tblRelationship) + N'   
		WHERE Version_ID = @Version_ID   
			AND Hierarchy_ID = @Hierarchy_ID   
			AND Status_ID = 1   
			AND ChildType_ID = @MemberType_ID  
			AND ' + CASE @MemberType_ID WHEN 1 THEN N'Child_EN_ID' WHEN 2 THEN N'Child_HP_ID' WHEN 3 THEN N'Child_CN_ID' END + N' = @Member_ID;';			  
  
	EXEC sp_executesql @strSQL,   
	    N'@Version_ID INT, @Hierarchy_ID INT, @Member_ID INT, @MemberType_ID INT',   
	    @Version_ID, @Hierarchy_ID, @Member_ID, @MemberType_ID;  
			  
	--Temporary table to collect ascendants (ancestors)  
	WHILE @Level < 22 AND EXISTS(SELECT 1 FROM #tblHierarchy WHERE [Level] = @Level) BEGIN  
	  
		SET @strSQL = N'  
			INSERT INTO #tblHierarchy(ID, MemberType_ID, [Level])  
			SELECT DISTINCT   
				Parent_HP_ID,   
				ChildType_ID,   
				@Level + 1   
			FROM mdm.' + quotename(@tblRelationship) + N'   
			WHERE Version_ID = @Version_ID   
				AND Hierarchy_ID = @Hierarchy_ID   
				AND Status_ID = 1   
				AND ChildType_ID = 2   
				AND Child_HP_ID IN (SELECT ID FROM #tblHierarchy WHERE [Level] = @Level);';  
		  EXEC sp_executesql @strSQL,   
		    N'@Version_ID INT, @Hierarchy_ID INT, @Level INT',   
		    @Version_ID, @Hierarchy_ID, @Level;  
		    
		  SET @Level = @Level + 1;  
		    
	END; --while  
  
	SELECT @MemberLevel = MAX([Level]) - 1 FROM #tblHierarchy;  
  
	--Temporary table to collect descendants  
	TRUNCATE TABLE #tblHierarchy;  
  
	SET @Level = @MemberLevel; --Apex  
	  
	INSERT INTO #tblHierarchy(ID, MemberType_ID, [Level])  
	SELECT @Member_ID, @MemberType_ID, @Level;  
	WHILE EXISTS(SELECT 1 FROM #tblHierarchy WHERE [Level] = @Level) BEGIN  
  
		SET @strSQL = N'  
			INSERT INTO #tblHierarchy(ID, MemberType_ID, [Level])  
			SELECT DISTINCT   
				CASE ChildType_ID WHEN 1 THEN Child_EN_ID WHEN 2 THEN Child_HP_ID END AS Child_ID,   
				ChildType_ID,   
				@Level + 1   
			FROM mdm.' + quotename(@tblRelationship) + N'   
			WHERE Version_ID = @Version_ID   
				AND Hierarchy_ID = @Hierarchy_ID   
				AND Status_ID = 1   
				AND (  
					ISNULL(Parent_HP_ID, 0) IN (SELECT ID FROM #tblHierarchy WHERE [Level] = @Level AND MemberType_ID = 2)  
				);';  
  
		EXEC sp_executesql @strSQL,   
		    N'@Version_ID INT, @Hierarchy_ID INT, @Level INT',   
		    @Version_ID, @Hierarchy_ID, @Level;  
  
		SET @Level = @Level + 1;  
		    
	END; --while  
	  
	--EN  
	SET @strSQL = N'  
		UPDATE tHR SET   
			tHR.LevelNumber = tDesc.[Level]   
		FROM mdm.' + quotename(@tblRelationship) + N' AS tHR   
		INNER JOIN #tblHierarchy AS tDesc   
			ON tDesc.MemberType_ID = tHR.ChildType_ID  
			AND tDesc.ID = tHR.Child_EN_ID  
		WHERE Version_ID = @Version_ID   
			AND Hierarchy_ID = @Hierarchy_ID   
			AND tDesc.MemberType_ID = 1  
			AND Status_ID = 1  
			AND tHR.LevelNumber <> tDesc.[Level];';  
	EXEC sp_executesql @strSQL,   
	    N'@Version_ID INT, @Hierarchy_ID INT',   
	    @Version_ID, @Hierarchy_ID;  
			  
	--HP  
	SET @strSQL = N'  
		UPDATE tHR SET   
			tHR.LevelNumber = tDesc.[Level]   
		FROM mdm.' + quotename(@tblRelationship) + N' AS tHR   
		INNER JOIN #tblHierarchy AS tDesc   
			ON tDesc.MemberType_ID = tHR.ChildType_ID  
			AND tDesc.ID = tHR.Child_HP_ID  
		WHERE Version_ID = @Version_ID   
			AND Hierarchy_ID = @Hierarchy_ID   
			AND tDesc.MemberType_ID = 2  
			AND Status_ID = 1  
			AND tHR.LevelNumber <> tDesc.[Level];';  
	EXEC sp_executesql @strSQL,   
	    N'@Version_ID INT, @Hierarchy_ID INT',   
	    @Version_ID, @Hierarchy_ID;  
  
	DROP TABLE #tblHierarchy;  
  
	--Compute the new maximum number of levels in the hierarchy.  
	SET @strSQL = N'  
		SET @MaxLevelNew = (SELECT MAX(LevelNumber) FROM mdm.' + quotename(@tblRelationship) + N');  
		SET @MaxLevelNew = ISNULL(@MaxLevelNew, 0);'    
  
	EXEC sp_executesql @strSQL, N'@MaxLevelNew SMALLINT OUTPUT', @MaxLevelNew OUTPUT;  
	  
	SET NOCOUNT OFF;  
END; --proc
GO
