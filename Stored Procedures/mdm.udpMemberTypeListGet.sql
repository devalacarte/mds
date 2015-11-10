SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpMemberTypeListGet 1,26  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMemberTypeListGet]  
(  
	@User_ID		INT,  
	@Entity_ID		INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SELECT	mt.ID,  
			0x0 AS MUID,  
			vObj.Model_ID,  
			vObj.Entity_ID,  
			mt.Name,  
			vObj.Privilege_ID   
  
	FROM	mdm.udfSecurityUserMemberTypeList(@User_ID, NULL, @Entity_ID) vObj  
			INNER JOIN mdm.tblEntityMemberType mt ON vObj.ID = mt.ID  
	ORDER BY Model_ID, Entity_ID, mt.ID   
  
	SET NOCOUNT OFF  
END --proc
GO
