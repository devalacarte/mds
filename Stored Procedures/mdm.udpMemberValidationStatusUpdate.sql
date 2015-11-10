SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
  
EXEC mdm.udpMemberValidationStatusUpdate 1,9,7,1,2  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMemberValidationStatusUpdate]  
(  
	@Version_ID				INTEGER,  
	@Entity_ID     			INTEGER,  
	@Member_ID				INTEGER,  
	@MemberType_ID			TINYINT,  
	@ValidationStatus_ID	INTEGER  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @TempSQLString 	NVARCHAR(MAX);  
	DECLARE @TempTableName 	sysname  
  
	SELECT @TempTableName = mdm.udfTableNameGetByID(@Entity_ID,@MemberType_ID);  
  
	SELECT @TempSQLString = N'  
		UPDATE mdm.' + quotename(@TempTableName) + N'   
		SET ValidationStatus_ID = @ValidationStatus_ID  
		WHERE Version_ID = @Version_ID   
		AND ID = @Member_ID';  
	EXEC sp_executesql @TempSQLString, N'@Version_ID INT, @ValidationStatus_ID INT, @Member_ID INT', @Version_ID, @ValidationStatus_ID, @Member_ID;  
  
	SET NOCOUNT OFF  
END --proc
GO
