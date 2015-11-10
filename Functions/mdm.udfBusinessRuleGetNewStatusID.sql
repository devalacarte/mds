SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT mdm.udfBusinessRuleGetNewStatusID(1,0)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfBusinessRuleGetNewStatusID]  
(  
	@Action_ID	INT,  
	@CurrentStatus_ID INT  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @NewStatus_ID INT  
	  
	SELECT 	@NewStatus_ID = st.NewStatus_ID  
	FROM	mdm.tblBRStatusTransition st  
	WHERE	st.Action_ID = @Action_ID  
	AND		st.CurrentStatus_ID = @CurrentStatus_ID  
		  
	RETURN ISNULL(@NewStatus_ID, @CurrentStatus_ID)  
  
END --fn
GO
