SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
DECLARE @HierRulesCount INT  
EXEC @HierRulesCount = mdm.udpBusinessRuleHierarchyInheritanceRulesExists 1, NULL, 12  
SELECT @HierRulesCount   
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleHierarchyInheritanceRulesExists]  
	(  
	@Entity_ID		INT,  
	@AttributeName	NVARCHAR(250) = NULL,  
	@Hierarchy_ID	INT = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE	@HierarchyInheritanceRulesCount INT   
  
	SELECT	@HierarchyInheritanceRulesCount = COUNT(*)  
	FROM	mdm.viw_SYSTEM_BUSINESSRULES_HIERARCHY_CHANGEVALUE_INHERITANCE v  
	WHERE	v.EntityID = @Entity_ID  
	AND		((@AttributeName IS NULL) OR (v.AttributeName = @AttributeName))  
	AND		((@Hierarchy_ID IS NULL) OR (v.HierarchyID = @Hierarchy_ID))  
  
	RETURN @HierarchyInheritanceRulesCount  
  
	SET NOCOUNT OFF  
END --proc
GO
