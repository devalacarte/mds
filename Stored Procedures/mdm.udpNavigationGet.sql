SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpNavigationGet 11  
EXEC mdm.udpNavigationGet 11,1  
EXEC mdm.udpNavigationGet 11,2  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpNavigationGet]  
(  
	@User_ID			INT,  
	@SecurityStatus_ID	INT = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	IF IsNull(@SecurityStatus_ID,1) = 1 BEGIN  
		----Member of   
		----We omit MUID here because this is an Effective permission  
		----evaluation and the application of this doesn't care about the  
		----specific records functional privilege records, just that they  
		----exist.  Using SELECT DISTINCT prohibits the use of MUID.  
	    SELECT DISTINCT   
            N.User_ID,  
            N.Function_ID,  
            N.Function_Constant,  
            MAX(CAST(N.Permission_ID AS TINYINT)) AS Permission_ID ,  
            CASE WHEN IsExplicit = 0 THEN N.Function_Name + N' *' ELSE N.Function_Name END Function_Name  
        FROM   
            mdm.udfSecurityUserFunctionList(@User_ID) N  
        GROUP BY  
            N.User_ID, N.Function_ID, N.Function_Constant, N.Function_Name, N.IsExplicit  
        ORDER BY N.Function_ID  
  
	END ELSE BEGIN  
		--Not Member of  
		SELECT  
			@User_ID	User_ID,  
			N.ID		Function_ID,  
			N.Constant	Function_Constant,  
			N.Name		Function_Name,  
			 0 Permission_ID  
		FROM  
			mdm.tblNavigation N  
		WHERE  
			N.ID NOT IN (SELECT DISTINCT Function_ID FROM mdm.udfSecurityUserFunctionList(@User_ID))  
	END  
	  
	SET NOCOUNT OFF  
END --proc
GO
