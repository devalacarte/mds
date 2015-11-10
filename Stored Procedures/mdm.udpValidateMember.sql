SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
 A wrapper to the udpValidateMembers sproc allowing a caller to pass in a   
 single Member Id to validate.  
    EXEC mdm.udpValidateMember 1, 20, 32, 880, 1, 0;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpValidateMember]  
(  
	@User_ID INT,   
	@Version_ID INT,  
    @Entity_ID INT,  
	@Member_ID INT,   
	@MemberType_ID INT,  
	@ProcessUIRulesOnly BIT = 0  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
    DECLARE	@MemberIdList mdm.IdList;   
      
    --Add the single Member_ID into the Id list table.  
    INSERT INTO @MemberIdList (ID) VALUES (@Member_ID);  
      
	EXEC mdm.udpValidateMembers @User_ID,@Version_ID, @Entity_ID, @MemberIdList, @MemberType_ID, @ProcessUIRulesOnly  
  
	SET NOCOUNT OFF  
END --proc
GO
