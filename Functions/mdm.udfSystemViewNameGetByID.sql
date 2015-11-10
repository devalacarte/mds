SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfSystemViewNameGetByID(9, 1);  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSystemViewNameGetByID]  
(  
   @Entity_ID   INT,  
   @ViewType_ID INT = NULL --1=ChildAttributes, 2=ParentAttributes, 3=CollectionAttributes, 4=ParentChild, 5=Level, 6=Right-justified repeating parent (LEVELS_RJ_RP)  
)   
RETURNS sysname  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @ViewName sysname;  
     
  
	SELECT @ViewName = N'viw_SYSTEM_'   
		+ CAST(M.ID AS NVARCHAR(50))  
		+ N'_' + CAST(E.ID AS NVARCHAR(50))   
		+ CASE @ViewType_ID  
			WHEN 1 THEN N'_CHILDATTRIBUTES'  
			WHEN 2 THEN N'_PARENTATTRIBUTES'  
			WHEN 3 THEN N'_COLLECTIONATTRIBUTES'  
			WHEN 4 THEN N'_PARENTCHILD'  
			WHEN 5 THEN N'_LEVELS'  
		END --case		  
	FROM mdm.tblEntity E  
	INNER JOIN mdm.tblModel M ON (E.Model_ID = M.ID)  
	WHERE E.ID = @Entity_ID;  
  
     
	RETURN @ViewName;  
END; --fn
GO
