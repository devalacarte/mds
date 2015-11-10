SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_USERGROUP_USERS  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_USERGROUP_USERS]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
     ug.ID UserGroup_ID  
    ,ug.MUID UserGroup_MUID  
    ,ug.SID UserGroup_SID  
    ,ug.Name UserGroup_Name  
    ,u.ID [User_ID]  
    ,u.MUID User_MUID  
    ,u.SID [User_SID]  
    ,u.UserName [User_Name]  
FROM  
	mdm.tblUserGroup ug  
	INNER JOIN mdm.tblUserGroupAssignment uga   
	    ON uga.UserGroup_ID = ug.ID  
	    AND ug.Status_ID = 1  
	INNER JOIN mdm.tblUser u   
	    ON u.ID = uga.[User_ID]   
	    AND u.Status_ID = 1
GO
