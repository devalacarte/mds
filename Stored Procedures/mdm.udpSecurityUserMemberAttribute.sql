SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityUserMemberAttribute]  
(  
	@User_ID INT,   
	@Item_ID INT,   
	@MemberType_ID TINYINT,   
	@Privilege_ID INT OUTPUT  
)    
AS    
BEGIN     
  
	SELECT TOP 1 @Privilege_ID = Privilege_ID   
	FROM mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTE   
	WHERE User_ID = @User_ID AND ID = @Item_ID AND MemberType_ID = @MemberType_ID   
	ORDER BY Rank ASC;  
	   
	--from tblSecurityPrivilege, 99 = -NA-  
	SET @Privilege_ID = ISNULL(@Privilege_ID, 99);   
	  
END
GO
