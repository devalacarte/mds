SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.udfEntityAttributesGetList(1, 1);  
	SELECT * FROM mdm.udfEntityAttributesGetList(1, 2);  
	SELECT * FROM mdm.udfEntityAttributesGetList(1, 3);  
	SELECT * FROM mdm.udfEntityAttributesGetList(23, 1);  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfEntityAttributesGetList]  
(  
	@Entity_ID		INT,  
	@MemberType_ID	TINYINT  
)   
RETURNS TABLE  
/*WITH SCHEMABINDING*/  
AS RETURN	  
	SELECT   
		DISTINCT -- OR clause in predicate brings back duplicate rows  
		A.Name AS ViewColumn,  
		A.TableColumn,  
		A.IsSystem,  
		A.IsReadOnly,  
		A.AttributeType_ID,  
		A.DataType_ID,  
		A.DomainEntity_ID,  
		E.EntityTable AS DomainTable,  
		A.SortOrder  
	FROM   
		mdm.tblAttribute A LEFT OUTER JOIN   
		mdm.tblEntity E ON A.DomainEntity_ID = E.ID  
	WHERE  
		A.Entity_ID = @Entity_ID AND  
		A.MemberType_ID = @MemberType_ID AND  
		--A.AttributeType_ID <> 3;  
		(A.IsSystem = 0 OR A.IsReadOnly = 0);
GO
