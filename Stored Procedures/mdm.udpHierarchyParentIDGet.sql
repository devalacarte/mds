SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	mdm.udpHierarchyParentIDGet 20,9,32,1,1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpHierarchyParentIDGet]  
(  
	@Version_ID			INT,  
	@Hierarchy_ID		INT,  
	@Entity_ID			INT,  
	@ChildMember_ID		INT,  
	@ChildType_ID		TINYINT,  
	@Parent_ID			INT = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	--Get the Hierarchy RelationShip Table Name  
	DECLARE @HierarchyTable AS sysname;  
	SET @HierarchyTable = mdm.udfTableNameGetByID(@Entity_ID, 4);  
  
	--Get The Target SortOrder  
	DECLARE @SQL AS NVARCHAR(MAX);  
	SET @Parent_ID = NULL; --In case a value was passed-in by mistake  
	  
	SET @SQL = N'  
		SELECT @Parent_ID = [Parent_HP_ID]  
		FROM mdm.' + quotename(@HierarchyTable) + N'   
		WHERE   
			Version_ID = @Version_ID AND  
			Hierarchy_ID = @Hierarchy_ID AND  
			ChildType_ID = @ChildType_ID AND  
			@ChildMember_ID = CASE ChildType_ID WHEN 1 THEN Child_EN_ID WHEN 2 THEN Child_HP_ID END;';  
			  
	EXEC sp_executesql @SQL,   
	    N'@Version_ID INT, @Hierarchy_ID INT, @ChildType_ID TINYINT, @ChildMember_ID INT, @Parent_ID INT OUTPUT',   
	    @Version_ID, @Hierarchy_ID, @ChildType_ID, @ChildMember_ID, @Parent_ID OUTPUT;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
