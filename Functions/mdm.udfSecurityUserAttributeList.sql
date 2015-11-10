SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, May 09, 2006  
Function   : mdm.udfSecurityUserAttributeList  
Component  : Security  
Description: mdm.udfSecurityUserAttributeList returns a list of attributes and privileges available for a user (read or update).  
Parameters : User ID, Model ID (optional), Entity ID (optional)  
Return     : Table: User_ID (INT), Model_ID (INT), Entity_ID (INT), ID (INT), Privilege_ID (INT)  
  
             ID is a foreign key to mdm.tblAttribute; Privilege_ID is a foreign key to mdm.tblSecurityPrivilege  
Example 1  : SELECT * FROM mdm.udfSecurityUserAttributeList(1, 5, 23, NULL)   --All attributes and privileges for UserID = 1, ModelID = 5, and Entity ID = 23  
Example 2  : SELECT * FROM mdm.udfSecurityUserAttributeList(1, 5, 23, 1)      --All attributes and privileges for UserID = 1, ModelID = 5, and Entity ID = 23 and MemberType_ID = 1  
Example 3  : SELECT * FROM mdm.udfSecurityUserAttributeList(1, NULL, NULL, 5) --All attributes and privileges for UserID = 1 and MemberType_ID = 5  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSecurityUserAttributeList]   
(  
	@User_ID INT,   
	@Model_ID INT = NULL,   
	@Entity_ID INT = NULL,   
	@MemberType_ID TINYINT = NULL  
)   
RETURNS @tblReturn TABLE  
(  
	User_ID int,   
	Model_ID int,   
	Entity_ID int,   
	MemberType_ID int,   
	ID int,   
	Privilege_ID int  
)    
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
DECLARE @tblAtt TABLE(User_ID int, Entity_ID int, MemberType_ID int, ID int, Rank int, Privilege_ID int)  
  
INSERT INTO @tblAtt  
	SELECT   
		User_ID, Entity_ID, MemberType_ID, ID, Rank, Privilege_ID   
	FROM  
		mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTE tSec  
	WHERE   
	   tSec.User_ID = @User_ID   
	   AND tSec.Entity_ID = ISNULL(@Entity_ID, tSec.Entity_ID)  
	   AND tSec.MemberType_ID = ISNULL(@MemberType_ID, tSec.MemberType_ID)  
  
INSERT INTO @tblReturn  
	SELECT  
	   tSec.User_ID,   
	   tEnt.Model_ID,   
	   tSec.Entity_ID,   
	   tSec.MemberType_ID,  
	   tSec.ID,   
	   tSec.Privilege_ID  
	FROM   
		@tblAtt tSec JOIN mdm.tblEntity tEnt ON tSec.Entity_ID = tEnt.ID   
	WHERE  
		tEnt.Model_ID  = ISNULL(@Model_ID, tEnt.Model_ID)  
		-- Return the permission with the highest ranking (lower number is higher ranking).  
		AND tSec.Rank <= (SELECT MIN(Rank) FROM @tblAtt tSec2 WHERE tSec.User_ID = tSec2.User_ID AND tSec.Entity_ID = tSec2.Entity_ID AND tSec.MemberType_ID = tSec2.MemberType_ID AND tSec.ID = tSec2.ID)  
		AND tSec.Privilege_ID <> 1  
	RETURN   
  
END --fn
GO
