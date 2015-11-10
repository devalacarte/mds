SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfTableNameGetByID(6, 1);  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfTableNameGetByID]  
(  
	@Entity_ID	INT,  
	@EntityType_ID	TINYINT  
)   
RETURNS sysname  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @TableName sysname;  
  
	SELECT @TableName = CASE @EntityType_ID  
		WHEN 1 THEN EntityTable   
		WHEN 2 THEN HierarchyParentTable   
		WHEN 3 THEN CollectionTable   
		WHEN 4 THEN HierarchyTable   
		WHEN 5 THEN CollectionMemberTable   
		WHEN 6 THEN SecurityTable   
		ELSE NULL  
	END --case  
	FROM mdm.tblEntity   
	WHERE ID = @Entity_ID;  
	  
	RETURN @TableName;  
END; --fn
GO
