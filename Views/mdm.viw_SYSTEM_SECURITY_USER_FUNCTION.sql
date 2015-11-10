SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_FUNCTION]  
/*WITH SCHEMABINDING*/  
AS  
SELECT       
	tUser.ID AS User_ID,   
	tUser.ID AS Foreign_ID,   
	tUser.MUID AS Foreign_MUID,   
	tUser.UserName, tUser.Status_ID,   
	tNav.ID AS Function_ID,   
    tNav.Constant AS Function_Constant,   
	tNav.Name AS Function_Name,   
	1 AS IsExplicit,   
	tNavSec.MUID,   
	tNavSec.Permission_ID Permission_ID,  
	1 AS ForeignType_ID  
FROM         mdm.tblUser AS tUser INNER JOIN  
                      mdm.tblNavigationSecurity AS tNavSec ON tUser.ID = tNavSec.Foreign_ID AND tNavSec.ForeignType_ID = 1 And tNavSec.Permission_ID = 1 INNER JOIN  
                      mdm.tblNavigation AS tNav ON tNavSec.Navigation_ID = tNav.ID  
UNION  
SELECT    
   tUser.ID AS User_ID,   
	tGroup.ID AS Foreign_ID,   
	tGroup.MUID AS Foreign_MUID,   
	tUser.UserName,   
	tUser.Status_ID,   
	tNav.ID,   
	tNav.Constant,   
	tNav.Name,   
	0 AS Expr1,   
	tNavSec.MUID,   
	tNavSec.Permission_ID as Permission_ID,  
	2 AS ForeignType_ID  
FROM         mdm.tblUserGroupAssignment AS tAssign INNER JOIN  
                      mdm.tblUser AS tUser ON tAssign.User_ID = tUser.ID INNER JOIN  
                      mdm.tblUserGroup AS tGroup ON tAssign.UserGroup_ID = tGroup.ID INNER JOIN  
                      mdm.tblNavigationSecurity AS tNavSec ON tGroup.ID = tNavSec.Foreign_ID AND tNavSec.ForeignType_ID = 2 INNER JOIN  
                      mdm.tblNavigation AS tNav ON tNavSec.Navigation_ID = tNav.ID
GO
