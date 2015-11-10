SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpValidationLogClearForBusinessRules 1,1,1,0  
exec mdm.udpValidationLogClearForBusinessRules 1,1,1,1 -- delete validation log entries for excluded rules only  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpValidationLogClearForBusinessRules]  
(  
		@BRType_ID     	INT,  
		@BRSubType_ID	INT,  
		@Foreign_ID	INT,  
		@ExcludedRulesOnly BIT = 0  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DELETE vl  
	FROM mdm.tblValidationLog vl  
	INNER JOIN 	mdm.tblBRBusinessRule br  
	ON br.ID = vl.BRBusinessRule_ID  
	INNER JOIN mdm.tblListRelationship lr ON   
		br.ForeignType_ID = lr.ID AND  
		br.Foreign_ID = @Foreign_ID AND  
		lr.Parent_ID = @BRType_ID AND  
		lr.Child_ID = @BRSubType_ID AND  
		br.Status_ID =  CASE WHEN ISNULL(@ExcludedRulesOnly, 0) = 0 THEN br.Status_ID ELSE 2 END    
	  
	SET NOCOUNT OFF  
END --proc
GO
