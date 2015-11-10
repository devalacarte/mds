SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfEntityHasHierarchy(1);  
	SELECT mdm.udfEntityHasHierarchy(3);  
	SELECT mdm.udfEntityHasHierarchy(NULL);  
	SELECT mdm.udfEntityHasHierarchy(99999);  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfEntityHasHierarchy]  
(  
   @Entity_ID  INT  
)   
RETURNS BIT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @Return BIT;  
  
	SELECT @Return = ISNULL(1 - IsFlat, 0)   
	FROM mdm.tblEntity WHERE ID = @Entity_ID;  
     
	RETURN ISNULL(@Return, 0);  
END; --fn
GO
