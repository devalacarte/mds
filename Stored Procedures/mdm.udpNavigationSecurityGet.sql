SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Exec mdm.udpNavigationSecurityGet  @Foreign_ID = 1, @ForeignType_ID = 2, @SecurityStatus_ID = 1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpNavigationSecurityGet]  
(  
	@Foreign_ID			INT,  
	@ForeignType_ID		INT,  
	@SecurityStatus_ID	INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	IF @SecurityStatus_ID = 1 --Member of  
		BEGIN  
			SELECT  
				@Foreign_ID Foreign_ID,  
				N.ID		Function_ID,  
				N.Constant	Function_Constant,  
				N.Name		Function_Name,  
				NS.MUID MUID,  
				NS.Permission_ID   
			FROM  
				mdm.tblNavigation N  
					INNER JOIN mdm.tblNavigationSecurity NS ON NS.Navigation_ID = N.ID  
						AND NS.Foreign_ID = @Foreign_ID  
						AND NS.ForeignType_ID = @ForeignType_ID  
		END  
	ELSE IF @SecurityStatus_ID = 2 --Not Member of  
		BEGIN  
			SELECT  
				@Foreign_ID Foreign_ID,  
				N.ID		Function_ID,  
				N.Constant	Function_Constant,  
				N.Name		Function_Name,  
				NS.MUID MUID,  
				NS.Permission_ID  
			FROM  
				mdm.tblNavigation N  
					LEFT JOIN mdm.tblNavigationSecurity NS ON NS.Navigation_ID = N.ID  
						AND NS.Foreign_ID = @Foreign_ID  
						AND NS.ForeignType_ID = @ForeignType_ID  
			WHERE  
				NS.Navigation_ID IS NULL  
		END  
  
	SET NOCOUNT OFF  
END --proc
GO
