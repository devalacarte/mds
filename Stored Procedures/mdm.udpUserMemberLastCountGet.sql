SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
DECLARE @Count INT  
EXEC mdm.udpUserMemberLastCountGet 1,1,1,1,@Count OUTPUT  
SELECT @Count  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserMemberLastCountGet]  
(  
	@User_ID		INT,  
	@Version_ID		INT,   
	@Entity_ID		INT,   
	@MemberType_ID	TINYINT,  
	@Count			INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SELECT   
		@Count=LastCount  
	FROM  
		mdm.tblUserMemberCount  
	WHERE  
		Version_ID = @Version_ID AND  
		User_ID = @User_ID AND  
		Entity_ID = @Entity_ID AND  
		MemberType_ID = @MemberType_ID  
  
	SELECT @Count=ISNULL(@Count,-1)  
  
	SET NOCOUNT OFF  
END --proc
GO
