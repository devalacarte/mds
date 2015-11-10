SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMemberStatusIDGetByMemberID]  
(  
   @Version_ID    INT,  
   @Entity_ID     INT,  
   @Member_ID     INT,  
   @MemberType_ID TINYINT,  
   @Status_ID     TINYINT = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @TableName sysname,  
			@SQL       NVARCHAR(MAX),  
			@ReturnID  TINYINT;  
  
	SET @TableName = mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID);  
	SET @SQL = N'  
		SELECT @ReturnID = Status_ID FROM mdm.' + quotename(@TableName) + N'   
		WHERE Version_ID = @Version_ID  
		AND ID = @Member_ID';  
  
  
	EXEC sp_executesql @SQL, N'@Version_ID INT, @Member_ID INT, @ReturnID INT OUTPUT', @Version_ID, @Member_ID, @ReturnID OUTPUT;  
  
	SET @Status_ID = @ReturnID;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
