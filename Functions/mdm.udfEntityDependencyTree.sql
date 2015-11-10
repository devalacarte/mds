SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Gets the default entity processing sequence for a model.  The default processing sequence is based on the relationships between entities via  
    domain-based attributes.  
  
	SELECT * FROM mdm.udfEntityDependencyTree(1, 1) ORDER BY [Level];  
	SELECT * FROM mdm.udfEntityDependencyTree(7, NULL) ORDER BY [Level];  
	SELECT * FROM mdm.udfEntityDependencyTree(NULL, NULL) ORDER BY [Level];  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfEntityDependencyTree]   
(  
	@Model_ID	INT,	--NULL returns all Models  
	@Entity_ID	INT		--NULL returns all Entities  
)  
RETURNS TABLE   
/*WITH SCHEMABINDING*/  
AS   
	RETURN  
    --The [Base] CTE contains all data from the Entity table, in a convenient but unfiltered format  
	WITH Base AS (  
		SELECT DISTINCT  
			E.Model_ID,  
			E.IsSystem,  
			E.ID AS Entity_ID,   
			E.[Name], --included for debugging purposes  
			A.MemberType_ID,  
			CASE A.MemberType_ID  
				WHEN 1 THEN E.EntityTable  
				WHEN 2 THEN E.HierarchyParentTable  
				WHEN 3 THEN E.CollectionTable  
				WHEN 4 THEN E.HierarchyTable  
				WHEN 5 THEN E.CollectionMemberTable  
			END AS TableName,  
			NULLIF(A.DomainEntity_ID, E.ID) AS DomainEntity_ID --Ignore self referencing DBA  
		FROM mdm.tblEntity AS E  
		INNER JOIN mdm.tblAttribute AS A ON E.ID = A.Entity_ID  
		WHERE E.Model_ID = ISNULL(@Model_ID, Model_ID)  
	),  
	--The [Recurse] CTE uses leaf DBAs as the root, and recurses all Entities that point to them  
	Recurse AS (  
		--Anchor clause returns all Entities that are leaf DBAs (ie have no DBAs themselves)  
		SELECT DISTINCT  
		    Entity_ID  
		    ,0 AS [Level]   
		    ,CAST(Entity_ID AS NVARCHAR(MAX)) AS EntityIDPath -- Used to prevent endless loop with circular references.  
		    ,0 AS [EntityOccurrenceCount] -- Used to prevent endless loop with circular references.  
		FROM Base  
		WHERE DomainEntity_ID IS NULL   
		AND Entity_ID = ISNULL(NULL, Entity_ID)  
  
		UNION ALL --Recursive conjunct  
  
		--Recursive clause returns all Entities that point to the leaf DBAs  
		SELECT   
		     b.Entity_ID  
		    ,r.[Level] + 1   
		    ,r.EntityIDPath + N'/' + CAST(b.Entity_ID AS NVARCHAR(MAX)) AS EntityIDPath -- Used to prevent endless loop with circular references.  
		    ,mdm.udfGetStringOccurrenceCount(r.EntityIDPath, b.Entity_ID) AS EntityOccurrenceCount -- Used to prevent endless loop with circular references.  
		FROM Base AS b   
		INNER JOIN Recurse AS r   
		    ON (b.DomainEntity_ID = r.Entity_ID)  
		    AND EntityOccurrenceCount < 2 -- A value > 1 indicates a circular reference.]  
	),  
    --The [Explode] CTE adds back in all the other member tables (_HP, CN, etc) since the recursed tables are only _EN  
	Explode AS (  
		SELECT b.Model_ID, b.IsSystem, b.Entity_ID, b.[Name], b.MemberType_ID, b.TableName, b.DomainEntity_ID, r.[Level]  
		FROM Base AS b   
		INNER JOIN Recurse AS r ON (b.Entity_ID = r.Entity_ID)  
	),  
	--Finally we group the results (since there might be duplicates due to common DBAs) and return them to the caller  
	Final AS (  
		SELECT Model_ID, IsSystem, Entity_ID, MemberType_ID, [Name], TableName, MAX([Level]) AS [Level]  
		FROM Explode  
		GROUP BY Model_ID, IsSystem, Entity_ID, MemberType_ID, [Name], TableName  
	)  
	SELECT   
		Model_ID, IsSystem, Entity_ID, MemberType_ID, [Name], TableName,  
		ROW_NUMBER() OVER (ORDER BY Model_ID, [Level], Entity_ID, MemberType_ID) AS [Level]  
	FROM Final;
GO
