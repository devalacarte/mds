SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	Inserts a record into the tblDBUpgradeHistory  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpDBUpgradeHistorySave]  
(  
	@DBVersion			INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	--Insert the Data  
	INSERT INTO [mdm].[tblDBUpgradeHistory]  
	(  
		[DBVersion]  
	)  
	VALUES  
	(  
		@DBVersion  
	)  
  
	RETURN (SCOPE_IDENTITY())  
  
	SET NOCOUNT OFF  
END --proc
GO
