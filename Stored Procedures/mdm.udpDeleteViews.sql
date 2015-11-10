SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
  
	EXEC mdm.udpDeleteViews 1;  
	EXEC mdm.udpDeleteViews 2;  
	EXEC mdm.udpDeleteViews 3;  
	EXEC mdm.udpDeleteViews 4;  
	EXEC mdm.udpDeleteViews 5;  
  
	EXEC mdm.udpCreateAllViews;  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpDeleteViews]  
(  
   @Item_ID     INT,  
   @ItemType_ID TINYINT = 1 --1=Model; 2=Entity (All views); 3=Entity (Hierarchy views)  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @SQL		NVARCHAR(MAX),  
			@ViewName	sysname;  
  
	SET @ItemType_ID = ISNULL(@ItemType_ID, 1);  
  
  
	DECLARE @ViewTable TABLE(RowNumber INT IDENTITY (1, 1) PRIMARY KEY CLUSTERED NOT NULL , ViewName sysname COLLATE database_default);  
	INSERT INTO @ViewTable EXEC mdm.udpViewNamesGetByID @Item_ID, @ItemType_ID;  
  
  
	SET @SQL = CAST(N'' AS NVARCHAR(max));  
	DECLARE @Counter INT = 1;   
	DECLARE @MaxCounter INT = (SELECT MAX(RowNumber) FROM @ViewTable);  
		  
	WHILE @Counter <= @MaxCounter  
	BEGIN  
		SELECT @ViewName = ViewName FROM @ViewTable WHERE [RowNumber] = @Counter;  
        SET @SQL = @SQL + N'  
	        IF (SELECT OBJECT_ID(N''mdm.' + quotename(@ViewName) +''',''V'' )) IS NOT NULL  
	            DROP VIEW mdm.' + quotename(@ViewName) + N';'  
		SET @Counter = @Counter +1;  
	END; --while  
  
	--PRINT(@SQL);  
	EXEC sp_executesql @SQL;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
