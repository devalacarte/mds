SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    A simple stored procedure that the API can call to determine  
      1) Is the connection to the database still alive  
      2) If so (this sproc will get called) are the system tables populated.  
  
	DECLARE @RET AS INT;  
	EXEC mdm.udpIsSystemInValidState @RET OUTPUT;  
	SELECT @RET;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpIsSystemInValidState]  
(  
	@Return_ID BIT OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
    --Check core system tables for the existence of records  
    IF  EXISTS (SELECT 1 FROM mdm.tblSystemSetting)   
		AND EXISTS (SELECT 1 FROM mdm.tblUser)  
		AND EXISTS (SELECT 1 FROM mdm.tblList)  
		AND EXISTS (SELECT 1 FROM mdm.tblUserGroupType)  
		AND EXISTS (SELECT 1 FROM mdm.tblEntityMemberType)  
		AND EXISTS (SELECT 1 FROM mdm.tblNavigation)  
		AND EXISTS (SELECT 1 FROM mdm.tblSecurityObject)  
		AND EXISTS (SELECT 1 FROM mdm.tblSecurityPrivilege)  
		AND EXISTS (SELECT 1 FROM mdm.tblBRItemType)  
        SET @Return_ID = 1;  
    ELSE  
		SET @Return_ID = 0;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
