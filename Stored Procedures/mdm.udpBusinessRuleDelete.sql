SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpBusinessRuleDelete 1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleDelete]  
(  
	@RuleID				INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
  
    DECLARE	@RuleIDs mdm.IdList;   
      
    --Add the single RuleID into the Id list table.  
    INSERT INTO @RuleIDs (ID) VALUES (@RuleID);  
      
	EXEC mdm.udpBusinessRulesDelete @RuleIDs  
	  
	SET NOCOUNT OFF  
END --proc
GO
