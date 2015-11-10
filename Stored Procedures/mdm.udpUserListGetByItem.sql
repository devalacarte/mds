SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpUserListGetByItem 1,6   -- Model  
exec mdm.udpUserListGetByItem 2,6   -- Should return an empty resultset  
exec mdm.udpUserListGetByItem 3,1   -- Entity  
exec mdm.udpUserListGetByItem 4,158 -- Attribute  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserListGetByItem]  
(  
	@Object_ID	INT,  
	@Securable_ID	INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @SQL            NVARCHAR(MAX)  
	DECLARE @ViewName		sysname;  
    DECLARE @ParamList		NVARCHAR(MAX)  
	SET @ParamList = N'@Securable_IDx	INT ';  
	  
	SELECT @ViewName = ViewName FROM mdm.tblSecurityObject WHERE ID = @Object_ID  
	IF @ViewName IS NULL BEGIN  
		SET  @Securable_ID = -11111  
		SELECT @ViewName = ViewName FROM mdm.tblSecurityObject WHERE ID = 1  
	END; --if  
	  
	SELECT @SQL =  
				N'  
				SELECT   
						u.ID,  
						u.UserName,  
						u.UserName + '' ('' + u.DisplayName + '')'' AS Name,  
						u.Description,  
						u.EmailAddress,  
						p.ID AS Privilege_ID,  
						p.Name AS Privilege_Name  
  
				FROM	mdm.' +  QUOTENAME(@ViewName) + N' sec  
						INNER JOIN mdm.tblUser u  
							ON sec.User_ID = u.ID AND sec.ID = @Securable_IDx AND u.Status_ID = 1  
						INNER JOIN mdm.tblSecurityPrivilege p  
							ON sec.Privilege_ID = p.ID   
				ORDER BY u.UserName;'  
	EXEC sp_executesql @SQL, @ParamList,@Securable_ID;  
  
	SET NOCOUNT OFF  
END --proc
GO
