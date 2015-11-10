SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpBusinessRuleMarkAsDeletePending 1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleMarkAsDeletePending]  
(  
	@RuleID				INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	-- Mark as Delete Pending  
	UPDATE	tblBRBusinessRule  
	SET		Status_ID = 6   
	WHERE	ID = @RuleID  
  
	SET NOCOUNT OFF  
END --proc
GO
