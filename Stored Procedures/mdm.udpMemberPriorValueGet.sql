SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @var NVARCHAR(MAX);  
	EXEC mdm.udpMemberPriorValueGet 1,'tbl_1_1_EN','uda_1_72',2,@var OUTPUT;  
	SELECT @var;  
	SELECT * FROM mdm.tbl_1_1_EN;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMemberPriorValueGet]  
(  
	@Version_ID	INT,  
	@TableName	sysname,  
	@ColumnName	sysname,  
	@Member_ID	INT,	  
	@PriorValue	NVARCHAR(MAX) = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @SQL	NVARCHAR(MAX),  
			@Value	NVARCHAR(MAX);  
  
	SET @SQL = N'  
		SELECT @Value = ' + quotename(@ColumnName) + N'   
		FROM mdm.' + quotename(@TableName) + N'   
		WHERE Version_ID = @Version_ID  
		AND ID = @Member_ID';  
  
	EXEC sp_executesql @SQL, N'@Version_ID INT, @Member_ID INT, @Value NVARCHAR(MAX) OUTPUT', @Version_ID, @Member_ID, @Value OUTPUT;  
	SET @PriorValue = @Value;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
