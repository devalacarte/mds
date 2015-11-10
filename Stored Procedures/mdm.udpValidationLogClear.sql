SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpValidationLogClear 3  
  
select * from mdm.tblValidationLog  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpValidationLogClear]  
(  
	@Version_ID	INT,	  
	@ID			INT = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	IF @ID IS NOT NULL  
		BEGIN  
			DELETE FROM mdm.tblValidationLog WHERE ID = @ID  
		END  
	ELSE  
		BEGIN  
			DELETE FROM mdm.tblValidationLog WHERE Version_ID = @Version_ID  
		END  
  
	SET NOCOUNT OFF  
END --proc
GO
