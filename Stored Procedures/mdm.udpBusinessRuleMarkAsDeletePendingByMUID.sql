SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
exec mdm.udpBusinessRuleMarkAsDeletePendingByMUID <rule MUID>  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleMarkAsDeletePendingByMUID]  
(  
	@RuleMUID UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
    -- lookup rule ID  
    DECLARE @RuleID INT   
    SET @RuleID = (SELECT ID FROM mdm.tblBRBusinessRule WHERE MUID = @RuleMUID)  
  
    IF @RuleID IS NULL BEGIN  
        RAISERROR('MDSERR400005|The business rule MUID is not valid.', 16, 1);  
    END ELSE BEGIN  
        EXEC mdm.udpBusinessRuleMarkAsDeletePending @RuleID  
    END  
  
	SET NOCOUNT OFF  
END --proc
GO
