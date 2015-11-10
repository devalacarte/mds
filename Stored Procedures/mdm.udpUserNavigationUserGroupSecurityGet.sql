SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Exec mdm.[udpUserNavigationUserGroupSecurityGet]  @Foreign_ID = 1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserNavigationUserGroupSecurityGet]  
(  
	@User_ID			INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
			  
SELECT   
    [User_ID]  
    ,Foreign_ID  
    ,ForeignType_ID  
    ,Foreign_MUID  
    ,Function_ID  
    ,Function_Constant  
    ,Function_Name  
    ,IsExplicit  
    ,MUID  
	,Permission_ID  
FROM [mdm].[udfSecurityUserFunctionList] (@User_ID)  
					  
  
	SET NOCOUNT OFF  
END --proc
GO
