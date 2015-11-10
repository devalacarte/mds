SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpVersionGetByID 1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpVersionGetByID]  
(  
	@Version_ID	INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SELECT  
		vVer.ID,  
		vVer.MUID,  
		vVer.Name,  
		vVer.Model_ID,  
		vVer.Model_MUID,  
		vVer.Model_Name,  
		vVer.Model_IsSystem,  
		vVer.[Description],  
		vVer.Status_ID,  
		vVer.[Status],  
		vVer.VersionNbr Display_ID,  
		vVer.Flag_MUID,  
		vVer.Flag VersionFlag,  
		vVer.CopiedFrom_ID AS AsOfVersionID,  
		vVer.CopiedFrom_MUID AS AsOfVersionMUID,  
		vVer.CopiedFrom AS AsOfVersionName,  
		3 AS Privilege_ID,  
		vVer.EnteredUser_MUID,  
		vVer.EnteredUser_UserName,  
		vVer.EnteredUser_DTM,  
		vVer.LastChgUser_MUID,  
		vVer.LastChgUser_UserName,  
		vVer.LastChgUser_DTM  
	FROM  
		mdm.viw_SYSTEM_SCHEMA_VERSION AS vVer   
	WHERE  
		vVer.ID = @Version_ID;  
  
	SET NOCOUNT OFF  
END --proc
GO
