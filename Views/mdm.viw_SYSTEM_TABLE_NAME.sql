SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_TABLE_NAME]  
/*WITH SCHEMABINDING*/  
	AS 	  
	SELECT  
		ID,  
		Model_ID,  
		[Name]					AS EntityName,  
		EntityTable				AS EntityTableName,  
		HierarchyTable			AS HierarchyTableName,  
		HierarchyParentTable	AS HierarchyParentTableName,  
		CollectionTable			AS CollectionTableName,  
		CollectionMemberTable	AS CollectionMemberTableName,  
		SecurityTable				AS SecurityTableName,  
		StagingBase + '_Leaf'			AS StagingLeafName,  
		StagingBase + '_Consolidated'	AS StagingConsolidatedName,  
		StagingBase + '_Relationship'		AS StagingRelationshipName,  
		StagingBase				AS StagingBase,   
		IsFlat					AS IsFlat  
	FROM	  
		mdm.tblEntity
GO
