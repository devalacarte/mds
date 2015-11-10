SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
	DECLARE @SecurityLevel TINYINT;  
	EXEC mdm.udpSecurityLevelGet 2, 6, @SecurityLevel OUTPUT;  
	SELECT @SecurityLevel;  
*/  
CREATE PROCEDURE [mdm].[udpSecurityLevelGet]  
(  
	@User_ID INT,   
	@Entity_ID INT,   
	@SecurityLevel TINYINT=0 OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS    
BEGIN    
	SET NOCOUNT ON;  
	DECLARE @SQL			NVARCHAR(MAX),  
			@SecurityTable		sysname  
	  
/*  
This procedure calculates Security Level for a User_ID against a specific area of influence  
Current Valid Return Values are:  
0 - No access to this influence area  
1 - Object Level Security should be enforced  
2 - Member Level Security should be enforced  
3 - Both Object Level and Member Level Security should be enforced  
4 - All access to this area of influence  
  
*/	  
  
SELECT @SecurityLevel = 0  
  
--If Model Administrator then Return 4 - All Access  
IF EXISTS(                      
	SELECT acl.ID  
	FROM mdm.tblEntity AS ent  
	INNER JOIN mdm.udfSecurityUserModelList(@User_ID) AS acl  
		ON ent.Model_ID = acl.ID  
		AND ent.ID = @Entity_ID  
		AND acl.IsAdministrator = 1  
) BEGIN  
	SET @SecurityLevel = 4;  
	RETURN(0);  
END;  
  
--Determine if any object level security exists for the current user's groups or user account - add 1 to SL  
IF EXISTS(  
	SELECT 1   
	FROM mdm.tblSecurityRoleAccess ra  
	INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_ROLE ur  
		ON ra.Role_ID = ur.Role_ID  
		AND ur.User_ID = @User_ID  
	INNER JOIN mdm.tblEntity ent  
		ON ent.Model_ID = ra.Model_ID  
		AND ent.ID = @Entity_ID  
) BEGIN  
	SELECT @SecurityLevel = @SecurityLevel | 1;  
END;  
  
--Determine if any member level security exists for the current user's groups or user account - add 2 to SL  
SELECT @SecurityTable = QuoteName(SecurityTable) from mdm.tblEntity WHERE ID = @Entity_ID;  
  
SELECT @SQL = N'  
	IF EXISTS(  
		Select ms.SecurityRole_ID  
		FROM mdm.' + @SecurityTable  + N' ms  
		INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_ROLE ur  
		ON ms.SecurityRole_ID = ur.Role_ID  
		AND ur.User_ID = @User_ID  
	) BEGIN  
		SELECT @SecurityLevel = @SecurityLevel | 2;  
	END;'  
  
--Execute the dynamic SQL    
EXEC sp_executesql @SQL, N'@User_ID INT, @SecurityLevel INT OUTPUT', @User_ID, @SecurityLevel OUTPUT;  
  
RETURN(0);  
  
END;
GO
