SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpBusinessRulesDelete 1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRulesDelete]  
(  
	@RuleIDs    mdm.IdList READONLY  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	BEGIN TRANSACTION  
  
	-- Delete logical operator groups  
	EXEC mdm.udpBusinessRuleLogicalOperatorGroupsDelete @RuleIDs  
  
	-- Delete business rules  
	DELETE	  
	FROM 	mdm.tblBRBusinessRule  
	WHERE	ID IN (SELECT ID FROM @RuleIDs);  
  
	COMMIT TRANSACTION  
  
	SET NOCOUNT OFF  
END --proc
GO
