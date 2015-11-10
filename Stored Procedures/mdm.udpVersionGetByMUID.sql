SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpVersionGetByMUID '9EC759AA-459D-4807-8774-AAE02B9F04F8'  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpVersionGetByMUID]  
(  
	@MUID		UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @ID INT  
	SELECT @ID = ID FROM mdm.tblModelVersion WHERE MUID = @MUID  
  
	EXEC mdm.udpVersionGetByID @ID  
  
	SET NOCOUNT OFF  
END --proc
GO
