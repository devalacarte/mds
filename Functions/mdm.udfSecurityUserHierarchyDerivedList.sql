SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Function   : mdm.udfSecurityUserHierarchyDerivedList  
Component  : Security  
Description: mdm.udfSecurityUserHierarchyDerivedList returns a list of Derived Hierarchies available for a user.  
Parameters : User ID, Model ID  
Return     : Table - list of Derived Hierachies and privileges for the selected user and Model  
Example 1  : SELECT * FROM mdm.udfSecurityUserHierarchyDerivedList(10, 7)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityUserHierarchyDerivedList]   
(  
	@User_ID INT,   
	@Model_ID INT  
)  
RETURNS @tblSecurity TABLE   
(  
	ID INT,   
	Privilege_ID INT  
) --ID represents the Hierarchy_ID  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
	/*  
	Ensure that that the user possesses Grant privileges to each object participating in each Derived Hierarchy.   
	Collect entity, explicit hierarchy, and attribute privileges (consolidated DBAs map to entities).  
	*/  
	   
	INSERT INTO @tblSecurity  
	SELECT   
		Hierarchy_ID,   
		Privilege_ID  
	FROM  
		(  
		SELECT   
			Hierarchy_ID,   
			MIN(Privilege_ID) Privilege_ID  
		FROM   
			(  
			SELECT   
				tSchema.Hierarchy_ID,   
				Privilege_ID = CASE WHEN (ue.Privilege_ID = 1 OR ua.Privilege_ID = 1 OR uh.Privilege_ID = 1) THEN 1 ELSE udh.Privilege_ID END  
			FROM   
				mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS tSchema   
								LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ENTITY ue ON ue.User_ID = @User_ID   
				    AND tSchema.Object_ID = 3   
					AND tSchema.Foreign_ID = ue.ID  
				LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTE ua ON ua.User_ID = @User_ID   
				    AND tSchema.Object_ID = 4   
					AND tSchema.Foreign_ID = ua.ID  
				LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY uh ON uh.User_ID = @User_ID   
				    AND tSchema.Object_ID = 6  
					AND tSchema.Foreign_ID = uh.ID  
				JOIN mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY_DERIVED udh ON udh.ID = tSchema.Hierarchy_ID  
					AND udh.User_ID = @User_ID  
					AND udh.Model_ID = tSchema.Model_ID      
			WHERE   
				tSchema.Model_ID = ISNULL(@Model_ID, tSchema.Model_ID)  
				AND (ue.Privilege_ID IS NOT NULL OR ua.Privilege_ID IS NOT NULL OR uh.Privilege_ID IS NOT NULL)  
			  
			UNION      
			SELECT   
				ID as Hierarchy_ID,   
				Privilege_ID   
			FROM   
				mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY_DERIVED   
			WHERE   
				User_ID = @User_ID  
				AND Model_ID = ISNULL(@Model_ID, Model_ID)   
	    
			) tSec  
		GROUP BY   
			tSec.Hierarchy_ID  
		) tSec  
	WHERE   
		tSec.Privilege_ID IN (2, 3)      
  
	RETURN  
END --fn
GO
