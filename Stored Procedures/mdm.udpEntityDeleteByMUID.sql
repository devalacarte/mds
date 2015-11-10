SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
	EXEC mdm.udpEntityDeleteByMUID 'AE6F63FB-6C08-4CF6-9CCC-1E56EF75F4C6';  
	select * from mdm.tblEntity;  
*/  
CREATE PROCEDURE [mdm].[udpEntityDeleteByMUID]  
(  
	@Entity_MUID	UNIQUEIDENTIFIER,  
	@CreateViewsInd	BIT = NULL --1=Create,0=DoNot Create  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
    DECLARE @Entity_ID INT;  
    SELECT  @Entity_ID = ID FROM mdm.tblEntity WHERE MUID = @Entity_MUID and IsSystem = 0;  
  
	--Test for invalid parameters  
	IF @Entity_ID IS NULL --Invalid Entity_MUID  
	BEGIN  
		RAISERROR('MDSERR200022|The entity cannot be deleted. The entity ID is not valid.', 16, 1);  
		RETURN;  
	END;  
  
	EXEC mdm.udpEntityDelete @Entity_ID, @CreateViewsInd  
  
	SET NOCOUNT OFF;  
END; --proc
GO
