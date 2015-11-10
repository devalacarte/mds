SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpBusinessRuleLogicalOperatorGroupsDelete 1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleLogicalOperatorGroupsDelete]  
(  
	@RuleIDs mdm.IdList READONLY  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	BEGIN TRANSACTION  
  
	-- Delete associated business rule item properties  
	DELETE  
	FROM	mdm.tblBRItemProperties  
	WHERE	BRItem_ID IN  
		(  
		SELECT	i.ID  
		FROM 	mdm.tblBRItem i INNER JOIN  
			mdm.tblBRLogicalOperatorGroup l ON   
				i.BRLogicalOperatorGroup_ID = l.ID AND  
				l.BusinessRule_ID IN (SELECT ID FROM @RuleIDs)  
		)  
  
	-- Delete associated business rule items  
	DELETE  
	FROM	mdm.tblBRItem  
	WHERE	BRLogicalOperatorGroup_ID IN  
		(  
		SELECT	ID  
		FROM 	mdm.tblBRLogicalOperatorGroup  
		WHERE	BusinessRule_ID IN (SELECT ID FROM @RuleIDs)  
		)  
  
	-- Delete logical operator groups  
	DELETE	  
	FROM 	mdm.tblBRLogicalOperatorGroup  
	WHERE	BusinessRule_ID IN (SELECT ID FROM @RuleIDs);  
  
	-- Clear RuleText and change status to unpublished  
	UPDATE	mdm.tblBRBusinessRule  
	SET	RuleConditionText = CAST(N''  AS NVARCHAR(1000)),  
		RuleActionText = CAST(N'' AS NVARCHAR(1000)),  
		Status_ID = mdm.udfBusinessRuleGetNewStatusID(3, br.Status_ID)  
	FROM	mdm.tblBRBusinessRule br  
	WHERE	br.ID IN (SELECT ID FROM @RuleIDs);  
  
	COMMIT TRANSACTION  
  
	SET NOCOUNT OFF  
END --proc
GO
