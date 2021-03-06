SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_VIEWS]  
/*WITH SCHEMABINDING*/   
AS   
	WITH Integers1_5 (num) AS   
	(  
		SELECT 1 num   
		UNION ALL   
		SELECT  num +1 FROM Integers1_5   
		WHERE num < 5  
	      
	)  
   
	SELECT 0 DisplayType_ID,  
	num MemberType_ID,  
	ID Entity_ID,   
	N'viw_SYSTEM_'    
	+ CONVERT(NVARCHAR(30), Model_ID) + N'_'   
		+ CONVERT(NVARCHAR(30), ID)   
		+ CASE num  
			WHEN 1 THEN N'_CHILDATTRIBUTES'   
			WHEN 2 THEN N'_PARENTATTRIBUTES'   
			WHEN 3 THEN N'_COLLECTIONATTRIBUTES'   
			WHEN 4 THEN N'_PARENTCHILD'  
			WHEN 5 THEN N'_COLLECTIONPARENTCHILD'  
		END ViewName --case  
	FROM mdm.tblEntity  
	CROSS JOIN  Integers1_5  
	  
	UNION ALL  
	SELECT 1 DisplayType_ID,  
	num MemberType_ID,  
	ID Entity_ID,  
	N'viw_SYSTEM_'    
	+ CONVERT(NVARCHAR(30), Model_ID) + N'_'   
		+ CONVERT(NVARCHAR(30), ID)   
		+ CASE num  
			WHEN 1 THEN N'_CHILDATTRIBUTES_CODE'   
			WHEN 2 THEN N'_PARENTATTRIBUTES_CODE'   
			WHEN 3 THEN N'_COLLECTIONATTRIBUTES_CODE'   
			WHEN 4 THEN N'_PARENTCHILD'  
			WHEN 5 THEN N'_COLLECTIONPARENTCHILD'  
		END ViewName --case  
	FROM mdm.tblEntity  
	CROSS JOIN  Integers1_5  
	UNION ALL  
	  
	SELECT 2 DisplayType_ID,  
	num MemberType_ID,  
	ID Entity_ID,  
	N'viw_SYSTEM_'    
	+ CONVERT(NVARCHAR(30), Model_ID) + N'_'   
		+ CONVERT(NVARCHAR(30), ID)   
		+ CASE num  
			WHEN 1 THEN N'_CHILDATTRIBUTES_CODENAME'   
			WHEN 2 THEN N'_PARENTATTRIBUTES_CODENAME'   
			WHEN 3 THEN N'_COLLECTIONATTRIBUTES_CODENAME'   
			WHEN 4 THEN N'_PARENTCHILD'  
			WHEN 5 THEN N'_COLLECTIONPARENTCHILD'  
		END ViewName--case  
	FROM mdm.tblEntity  
	CROSS JOIN  Integers1_5  
	UNION ALL  
	SELECT 3 DisplayType_ID,  
	num MemberType_ID,  
	ID Entity_ID,  
	N'viw_SYSTEM_'    
	+ CONVERT(NVARCHAR(30), Model_ID) + N'_'   
		+ CONVERT(NVARCHAR(30), ID)   
		+ CASE num  
			WHEN 1 THEN N'_CHILDATTRIBUTES_NAMECODE'   
			WHEN 2 THEN N'_PARENTATTRIBUTES_NAMECODE'   
			WHEN 3 THEN N'_COLLECTIONATTRIBUTES_NAMECODE'   
			WHEN 4 THEN N'_PARENTCHILD'  
			WHEN 5 THEN N'_COLLECTIONPARENTCHILD'  
		END ViewName--case  
	FROM mdm.tblEntity  
	CROSS JOIN  Integers1_5  
	UNION ALL  
	SELECT 3 DisplayType_ID,  
	num MemberType_ID,  
	ID Entity_ID,  
	N'viw_SYSTEM_'    
	+ CONVERT(NVARCHAR(30), Model_ID) + N'_'   
		+ CONVERT(NVARCHAR(30), ID)   
		+ CASE num  
			WHEN 1 THEN N'_CHILDATTRIBUTES_EXP'   
			WHEN 2 THEN N'_PARENTATTRIBUTES_EXP'   
			WHEN 3 THEN N'_COLLECTIONATTRIBUTES_EXP'   
			WHEN 4 THEN N'_PARENTCHILD'  
			WHEN 5 THEN N'_COLLECTIONPARENTCHILD'  
		END ViewName--case  
	FROM mdm.tblEntity  
	CROSS JOIN  Integers1_5
GO
