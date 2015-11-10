SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT * FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_CHANGEVALUE_INHERITANCE  
  
DECLARE @DBARulesCount INT  
EXEC @DBARulesCount = mdm.udpBusinessRuleDBAInheritanceRulesExists 81, NULL  
SELECT @DBARulesCount   
  
EXEC @DBARulesExist = mdm.udpBusinessRuleDBAInheritanceRulesExists 80, '2 Digit Code'  
SELECT @DBARulesExist   
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleDBAInheritanceRulesExists]  
	(  
	@Entity_ID		INT,  
	@AttributeName	NVARCHAR(250) = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE	@DBAInheritanceRulesCount INT   
  
	SELECT	@DBAInheritanceRulesCount = COUNT(*)  
	FROM	mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_CHANGEVALUE_INHERITANCE v  
	WHERE	v.EntityID = @Entity_ID  
	AND		((@AttributeName  IS NULL) OR (v.AttributeName = @AttributeName ))  
  
	RETURN @DBAInheritanceRulesCount  
  
	SET NOCOUNT OFF  
END --proc
GO
