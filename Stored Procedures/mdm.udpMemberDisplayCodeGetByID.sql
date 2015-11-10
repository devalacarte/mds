SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
  
DECLARE @Tempvar NVARCHAR(250)  
EXEC mdm.udpMemberDisplayCodeGetByID 'admin',1,9,'7',1,@TempVar OUTPUT  
select @Tempvar  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMemberDisplayCodeGetByID]  
(  
	@Version_ID		INTEGER,  
	@Entity_ID     	INTEGER,  
	@Member_ID		INTEGER,  
	@MemberType_ID	TINYINT,  
	@DisplayType	INT,  
	@ReturnCode		NVARCHAR(1000) OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @SQL 			NVARCHAR(MAX)  
	DECLARE @TempCount 		INTEGER  
	DECLARE @TempTableName 	sysname  
	DECLARE @TempCode		NVARCHAR(502)  
	DECLARE @TempName		NVARCHAR(250)  
  
	SELECT @TempTableName = mdm.udfTableNameGetByID(@Entity_ID,@MemberType_ID);  
  
	SET @ReturnCode = CAST(N'0' AS NVARCHAR(1000)) ;  
	   
		SET @SQL = N'  
			SELECT   
				@TempCode = Code,   
				@TempName = ISNULL(Name,'''')  
			FROM mdm.' + quotename(@TempTableName) + N'   
			WHERE Version_ID = @Version_ID   
			AND ID = @Member_ID';  
		EXEC sp_executesql @SQL, N'@Version_ID INT, @Member_ID INT, @TempCode NVARCHAR(502) OUTPUT, @TempName NVARCHAR(250) OUTPUT', @Version_ID, @Member_ID, @TempCode OUTPUT, @TempName OUTPUT;  
		  
		IF @@ROWCOUNT = 1 BEGIN  
			IF @DisplayType = 1 BEGIN  
				SET @ReturnCode = CAST(@TempCode	 AS NVARCHAR(1000))  
			END ELSE IF @DisplayType = 2 BEGIN  
				SET @ReturnCode = CAST(@TempCode	+ N'{' + @TempName + N'}' AS NVARCHAR(1000))  
			END ELSE IF @DisplayType = 3 BEGIN  
				SET @ReturnCode = CAST(@TempName	+ N'{' + @TempCode + N'}' AS NVARCHAR(1000))  
			END ELSE BEGIN  
				SET @ReturnCode = CAST(N'0' AS NVARCHAR(1000))  
			END; --if  
		END ELSE BEGIN  
			SET @ReturnCode = CAST(N'0' AS NVARCHAR(1000));  
		END; --if  
  
	SET NOCOUNT OFF;  
END; --proc
GO
