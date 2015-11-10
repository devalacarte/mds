SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpValidationLogClearByMemberID 7,5,191,1  
select * from mdm.tblValidationLog  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpValidationLogClearByMemberID]  
(  
	@Version_ID	INT,  
	@Entity_ID	INT,  
	@Member_ID	INT,  
	@MemberType_ID	INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DELETE   
	FROM 	mdm.tblValidationLog  
	WHERE	ID IN  
		(SELECT	vl.ID  
		FROM 	mdm.viw_SYSTEM_ISSUE_VALIDATION vl   
		WHERE	vl.Member_ID = @Member_ID AND  
			vl.MemberType_ID = @MemberType_ID AND  
			vl.Version_ID = @Version_ID AND  
			vl.Entity_ID = @Entity_ID)  
  
	SET NOCOUNT OFF  
END --proc
GO
