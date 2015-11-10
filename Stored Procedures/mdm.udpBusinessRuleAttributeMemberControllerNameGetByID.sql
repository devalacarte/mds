SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
declare @res NVARCHAR(200)  
exec mdm.udpBusinessRuleAttributeMemberControllerNameGetByID 1,1,@res output  
select @res  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleAttributeMemberControllerNameGetByID]  
(  
	@Entity_ID			INT,  
	@MemberType_ID		TINYINT,  
	@BRControllerName	NVARCHAR(200) OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SELECT @BRControllerName = mdm.udfBusinessRuleAttributeMemberControllerNameGetByID(@Entity_ID, @MemberType_ID)   
  
	SET NOCOUNT OFF  
END --proc
GO
