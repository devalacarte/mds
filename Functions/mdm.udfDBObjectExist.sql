SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfDBObjectExist('tblEntity', 'T')  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfDBObjectExist]  
(  
	@DBObjectName	sysname,  
	@DBObjectType	NCHAR(1)  
)   
RETURNS BIT  
/*WITH*/  
AS BEGIN  
	SET @DBObjectType = UPPER(@DBObjectType);  
	  
	IF @DBObjectType = N'P' BEGIN  
		IF EXISTS(  
			SELECT	1  
			FROM	INFORMATION_SCHEMA.ROUTINES  
			WHERE	ROUTINE_SCHEMA = N'mdm'  
			AND ROUTINE_NAME = @DBObjectName  
			AND	ROUTINE_TYPE = N'PROCEDURE'  
			AND	SPECIFIC_CATALOG = DB_NAME()  
		) RETURN 1;  
	  
	END ELSE IF @DBObjectType = N'F' BEGIN  
		IF EXISTS(  
			SELECT	1  
			FROM	INFORMATION_SCHEMA.ROUTINES  
			WHERE	ROUTINE_SCHEMA = N'mdm'  
			AND ROUTINE_NAME = @DBObjectName  
			AND	ROUTINE_TYPE = N'FUNCTION'  
			AND	SPECIFIC_CATALOG = DB_NAME()  
		) RETURN 1;  
  
	END ELSE IF @DBObjectType = N'T' BEGIN  
		IF EXISTS(  
			SELECT 	1  
			FROM	INFORMATION_SCHEMA.TABLES  
			WHERE	TABLE_NAME = @DBObjectName  
			AND TABLE_SCHEMA = N'mdm'  
			AND	TABLE_TYPE = N'BASE TABLE'  
			AND	TABLE_CATALOG = DB_NAME()  
		) RETURN 1;  
  
	END ELSE IF @DBObjectType = N'V' BEGIN  
		IF EXISTS(  
			SELECT 	1  
			FROM	INFORMATION_SCHEMA.TABLES  
			WHERE	TABLE_NAME = @DBObjectName  
			AND TABLE_SCHEMA = N'mdm'  
			AND	TABLE_TYPE = N'VIEW'  
			AND	TABLE_CATALOG = DB_NAME()  
		) RETURN 1;  
  
	END; --if  
	  
	RETURN 0;  
END --fn
GO
