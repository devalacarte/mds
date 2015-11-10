SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
mdm.udpSortOrderGetByTarget 1,1,1,'dm_HR_BankCenter',1,1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSortOrderGetByTarget]  
(  
	@Version_ID				INT,  
	@Hierarchy_ID			INT,  
	@TableName				sysname,  
	@Target_ID				INT,  
	@TargetMemberType_ID	INT,  
	@TargetType_ID			INT,  
	@SortOrder_ID			INT = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @SQL	NVARCHAR(MAX);	  
	DECLARE @TempID	INT;  
  
	IF @TargetType_ID = 1 BEGIN --Parent  
	  
		SET @SQL = N'  
			SELECT @TempID = ISNULL(MAX(SortOrder), 0)   
			FROM mdm.' + quotename(@TableName) + N'   
			WHERE Version_ID = @Version_ID' + N'  
			AND Hierarchy_ID = @Hierarchy_ID' + N'  
			AND (((@Target_ID IS NULL OR @Target_ID = 0) AND Parent_HP_ID IS NULL) OR (@Target_ID = Parent_HP_ID))';  
  
			--PRINT @SQL;  
			EXEC sp_executesql @SQL, N'@Version_ID INT, @Hierarchy_ID INT, @Target_ID INT, @TempID INT OUTPUT',  
									   @Version_ID, @Hierarchy_ID, @Target_ID, @TempID OUTPUT;  
	  
	END	ELSE IF @TargetType_ID = 2 BEGIN --Sibling/Child  
		  
		SET @SQL = N'  
			SELECT @TempID = ISNULL(MAX(SortOrder), 0)   
			FROM mdm.' + quotename(@TableName) + N'   
			WHERE Version_ID = @Version_ID' + N'  
			AND Hierarchy_ID = @Hierarchy_ID' + N'  
			AND ChildType_ID = @TargetMemberType_ID' + N'  
			AND ((@Target_ID IS NULL AND CASE ChildType_ID WHEN 1 THEN Child_EN_ID WHEN 2 THEN Child_HP_ID END IS NULL)' + N'  
			OR (@Target_ID = CASE ChildType_ID WHEN 1 THEN Child_EN_ID WHEN 2 THEN Child_HP_ID END))';  
  
			--PRINT @SQL;  
			EXEC sp_executesql @SQL, N'@Version_ID INT, @Hierarchy_ID INT, @TargetMemberType_ID INT, @Target_ID INT, @TempID INT OUTPUT',  
									   @Version_ID, @Hierarchy_ID, @TargetMemberType_ID, @Target_ID, @TempID OUTPUT;  
  
	END; --if  
  
	SET @SortOrder_ID = @TempID;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
