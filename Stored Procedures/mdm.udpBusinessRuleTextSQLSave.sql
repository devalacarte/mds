SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Updates the text and sql columns of the business rule with the given Muid.   
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleTextSQLSave]  
(  
	@User_ID	 		INT, --Person performing save  
	@RuleMuid           UNIQUEIDENTIFIER = NULL,  
	@RuleConditionText	NVARCHAR(MAX) = NULL,   
	@RuleActionText		NVARCHAR(MAX) = NULL,   
	@RuleConditionSQL	NVARCHAR(MAX) = NULL   
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @ActionType AS INT  
	IF @RuleActionText IS NULL OR LEN(@RuleActionText) = 0 BEGIN  
		-- treat rules without actions as newly-created   
		SET @ActionType = 1 -- 1 = enum ActionType.Create  
	END ELSE BEGIN  
		SET @ActionType = 3 -- 3 = enum ActionType.Change  
	END  
  
	UPDATE tblBRBusinessRule  
	SET  
		RuleConditionText = @RuleConditionText,  
		RuleActionText = @RuleActionText,  
		RuleConditionSQL = @RuleConditionSQL,  
		Status_ID = mdm.udfBusinessRuleGetNewStatusID(@ActionType, Status_ID),   
		LastChgUserID = @User_ID,  
		LastChgDTM = GETUTCDATE()  
	FROM mdm.tblBRBusinessRule  
	WHERE	MUID = @RuleMuid  
  
	SET NOCOUNT OFF  
END --proc
GO
