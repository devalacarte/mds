SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfViewNameGetByID(42,NULL,0)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfViewNameGetByID]  
(  
	@Entity_ID	INT,  
	@MemberType_ID	TINYINT = NULL,  
	@DisplayType_ID TINYINT  
)   
RETURNS sysname  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @ViewName		sysname,  
			@ViewNameSuffix	sysname;  
  
	--Suffix for view name  
	SET @ViewNameSuffix = CASE @DisplayType_ID  
		WHEN 0 THEN N''  
		WHEN 1 THEN N'_CODE'  
		WHEN 2 THEN N'_CODENAME'  
		WHEN 3 THEN N'_NAMECODE'  
		WHEN 4 THEN N'_EXP'  
	END; --case  
	  
  
	SELECT @ViewName = N'viw_SYSTEM_'   
		+ CONVERT(NVARCHAR(30), Model_ID) + N'_'   
		+ CONVERT(NVARCHAR(30), @Entity_ID)   
		+ CASE @MemberType_ID  
			WHEN 1 THEN N'_CHILDATTRIBUTES' + @ViewNameSuffix  
			WHEN 2 THEN N'_PARENTATTRIBUTES' + @ViewNameSuffix  
			WHEN 3 THEN N'_COLLECTIONATTRIBUTES' + @ViewNameSuffix  
			WHEN 4 THEN N'_PARENTCHILD'  
			WHEN 5 THEN N'_COLLECTIONPARENTCHILD'  
		END --case  
	FROM mdm.tblEntity   
	WHERE ID = @Entity_ID;  
  
	  
	RETURN @ViewName;  
END; --fn
GO
