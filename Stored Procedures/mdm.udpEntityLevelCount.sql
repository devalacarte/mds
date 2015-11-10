SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @i INT;  
	EXEC mdm.udpEntityLevelCount 6, @i OUTPUT;  
	SELECT @i;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpEntityLevelCount]  
(  
   @Entity_ID INT,  
   @Levels    SMALLINT OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @SQL            NVARCHAR(MAX) ,  
			@HierarchyTable sysname;  
  
	SET @Levels = CAST(-1 AS SMALLINT);  
  
	SELECT   
	   @HierarchyTable = HierarchyTableName  
	FROM    
	   [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Entity_ID AND IsFlat = 0;  
	     
	IF @HierarchyTable IS NULL RETURN;  
  
	SET @SQL = N'SELECT @Levels = ISNULL((SELECT MAX(LevelNumber) FROM mdm.' + quotename(@HierarchyTable) + N'), 0);';  
	EXEC sp_executesql @SQL, N'@Levels INT OUTPUT', @Levels OUTPUT;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
