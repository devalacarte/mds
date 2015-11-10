SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpSecurityPrivilegesSummaryEffectiveGet 1,1,1,NULL  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesSummaryEffectiveGet]  
   (  
	@SystemUser_ID				INT,  
	@Principal_ID				INT,  
	@PrincipalType_ID			INT,  
	@Model_ID				    INT = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON  
    DECLARE @Object_ID  INT  
    DECLARE @ViewName   sysname  
      
    CREATE TABLE #tblOutput (  
        Model_ID        int  
		,Model_MUID        UNIQUEIDENTIFIER  
		,Model_Name        nvarchar(50)  
        , [Object_ID]   int  
        , Securable_ID  int  
		, Securable_MUID  UNIQUEIDENTIFIER  
        , ViewName sysname COLLATE database_default  
        , Privilege_ID int NULL)  
  
    CREATE TABLE #tblSQL (  
        ID INT IDENTITY (1, 1) NOT NULL  
        , SQL NVARCHAR(2000) COLLATE database_default  
         ,[Object_ID]   int  
         , ViewName sysname COLLATE database_default  
        )  
  
    INSERT INTO #tblOutput  
    SELECT  
    Model_ID,  
	Model_MUID,  
	Model_Name,  
    Object_ID,  
    Securable_ID,  
	Securable_MUID,  
    ViewName,  
    NULL  
    FROM	mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL rac   
    INNER JOIN mdm.tblSecurityObject so ON rac.Object_ID = so.ID  
    WHERE	rac.PrincipalType_ID = 1  
    AND		rac.Principal_ID = @Principal_ID  
    AND		((@Model_ID IS NULL) OR (rac.Model_ID = @Model_ID))  
  
    UNION  
  
    SELECT  
    Model_ID,  
	Model_MUID,  
	Model_Name,  
    [Object_ID],  
    Securable_ID,  
	Securable_MUID,  
    ViewName,  
    NULL  
    FROM	mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL rac INNER JOIN mdm.tblSecurityObject so ON rac.Object_ID = so.ID  
    WHERE	rac.PrincipalType_ID = 2  
    AND		EXISTS (SELECT   
			Role_ID FROM mdm.viw_SYSTEM_SECURITY_USER_ROLE   
			WHERE User_ID = @Principal_ID  
			and Role_ID = rac.Role_ID   
			)  
    AND		((@Model_ID IS NULL) OR (rac.Model_ID = @Model_ID))  
  
    --Update Privilege_ID  
    INSERT INTO #tblSQL  
    select  
	    DISTINCT   
	    N'Update	#tblOutput Set Privilege_ID = v.Privilege_ID FROM	mdm.{0} v INNER JOIN #tblOutput t ON v.User_ID = @Principal_IDx and t.Object_ID = @Object_IDx AND t.Securable_ID = v.ID' SQL  
	    ,[Object_ID]  
	    ,ViewName  
    from #tblOutput  
    where ( [Object_ID] <> 8 AND [Object_ID] <> 9 AND [Object_ID] <> 10)  
  
    INSERT INTO #tblSQL  
    select  
	    DISTINCT   
	    N'Update	#tblOutput Set Privilege_ID = v.Privilege_ID FROM	mdm.{0} v INNER JOIN #tblOutput t ON v.User_ID = @Principal_IDx and t.Object_ID = @Object_IDx AND t.Securable_ID = v.Entity_ID' SQL  
	    ,[Object_ID]  
	    ,ViewName  
    from #tblOutput  
    where ( [Object_ID] = 8 OR [Object_ID] = 9 OR [Object_ID]=10)  
  
    --CASE WHEN Object_ID IN (8,9,10) THEN Entity_ID ELSE ID END   
    DECLARE @ID int  
    DECLARE @SQLFinal NVARCHAR(MAX), @ParamList NVARCHAR(MAX), @SQL NVARCHAR(4000)  
  
    SET @ParamList = N' @Principal_IDx int, @Object_IDx INT  ';  
  
    WHILE EXISTS(SELECT 1 FROM #tblSQL)  
    BEGIN  
    SELECT TOP 1   
      @ID = ID,   
      @SQL= SQL,  
      @Object_ID = [Object_ID],  
	  @ViewName = ViewName  
    FROM #tblSQL ORDER BY ID  
      
    SET @SQLFinal = REPLACE(@SQL,'{0}', quotename(@ViewName));  
  
    EXEC sp_executesql @SQLFinal, @ParamList , @Principal_ID, @Object_ID  
  
    DELETE FROM #tblSQL WHERE ID = @ID  
    END  
  
    SELECT   
    (SELECT	Top 1 RoleAccess_ID FROM mdm.udfSecurityUserExplicitPermissions(@Principal_ID, @PrincipalType_ID, 1, NULL) WHERE Model_ID = xp.Model_ID AND Object_ID = xp.Object_ID AND ID = xp.Securable_ID AND Privilege_ID = xp.Privilege_ID order by Object_ID, ID, SourceUserGroup_ID) RoleAccess_ID,  
	(SELECT	Top 1 Model_MUID FROM mdm.udfSecurityUserExplicitPermissions(@Principal_ID, @PrincipalType_ID, 1, NULL) WHERE Model_ID = xp.Model_ID AND Object_ID = xp.Object_ID AND ID = xp.Securable_ID AND Privilege_ID = xp.Privilege_ID order by Object_ID, ID, SourceUserGroup_ID) Model_MUID,  
	xp.Model_ID Model_ID,  
	xp.Model_Name,  
	(SELECT	Top 1 RoleAccess_MUID FROM mdm.udfSecurityUserExplicitPermissions(@Principal_ID, @PrincipalType_ID, 1, NULL) WHERE Model_ID = xp.Model_ID AND Object_ID = xp.Object_ID AND ID = xp.Securable_ID AND Privilege_ID = xp.Privilege_ID order by Object_ID, ID, SourceUserGroup_ID) RoleAccess_MUID,  
    sp.ID                   Privilege_ID,  
    sp.Name					Privilege_Name,  
    so.ID                   ObjectType_ID,  
    so.Name                 ObjectType_Name,  
    xp.Securable_ID,  
	xp.Securable_MUID,  
    mdm.udfSecurableNameGetByObjectID(xp.Object_ID, xp.Securable_ID) Securable_Name,  
    CASE WHEN (SELECT Top 1 RoleAccess_ID FROM mdm.udfSecurityUserExplicitPermissions(@Principal_ID, @PrincipalType_ID, 1, NULL) WHERE Model_ID = xp.Model_ID AND Object_ID = xp.Object_ID AND ID = xp.Securable_ID AND Privilege_ID = xp.Privilege_ID order by Object_ID, ID, SourceUserGroup_ID) IS NULL THEN ' ** Inherited from a parent assignment **'  ELSE (SELECT Top 1 SourceUserGroup_Name FROM mdm.udfSecurityUserExplicitPermissions(@Principal_ID, @PrincipalType_ID, 1, NULL) WHERE Model_ID = xp.Model_ID AND Object_ID = xp.Object_ID AND ID = xp.Securable_ID AND Privilege_ID = xp.Privilege_ID order by Object_ID, ID, SourceUserGroup_ID) END SourceUserGroup_Name,  
    modSec.IsAdministrator	IsModelAdministrator  
    FROM  
    #tblOutput xp  
    INNER JOIN mdm.tblSecurityObject so   
	    ON	xp.Object_ID = so.ID  
    INNER JOIN mdm.tblSecurityPrivilege sp  
	    ON xp.Privilege_ID = sp.ID  
    INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL modSec  
	    ON modSec.User_ID = @SystemUser_ID AND modSec.ID = xp.Model_ID AND modSec.IsAdministrator=1  
    ORDER BY so.ID, Securable_Name, sp.ID  
  
	    SET NOCOUNT OFF  
END --proc
GO
