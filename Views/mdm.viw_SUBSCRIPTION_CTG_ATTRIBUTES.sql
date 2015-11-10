SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SUBSCRIPTION_CTG_ATTRIBUTES]    
AS    
--This view displays all attributes that are assigned to a change tracking group.  
SELECT 	mdl.Name AS Model_Name,   
	ent.Name AS Entity_Name,   
	CASE atb.MemberType_ID  
		WHEN 1 THEN N'Leaf'  
		WHEN 2 THEN N'Consolidated'  
	END AS MemberType,   
	atb.DisplayName AS Attribute_Name,   
	atb.ChangeTrackingGroup   
FROM mdm.tblAttribute atb   
    INNER JOIN mdm.tblEntity ent ON ent.ID = atb.Entity_ID   
    INNER JOIN mdm.tblModel mdl ON mdl.ID = ent.Model_ID   
    WHERE atb.ChangeTrackingGroup BETWEEN 1 AND 31
GO
