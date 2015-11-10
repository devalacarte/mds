SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	EXEC mdm.udpMemberNextIDGet 1,'tbl_1_1_EN',@ID OUTPUT;  
	PRINT @ID;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMemberNextIDGet]  
(  
	@Version_ID	INT,  
	@TableName	sysname,  
	@NextMember_ID	INT = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @SQL NVARCHAR(MAX);  
  
	SELECT @SQL = N'SELECT @TempID = ISNULL(MAX(ID),0) + 1 FROM mdm.' + quotename(@TableName);  
	EXEC sp_executesql @SQL, N'@TempID INT OUTPUT', @NextMember_ID OUTPUT;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
