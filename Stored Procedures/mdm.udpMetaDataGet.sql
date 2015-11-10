SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
This SPROC is used by the MasterData API to get a list of objects the user has access.  
The API used this proc to get the objects and then uses ModelsGet operation to export the requested data  
  
EXEC mdm.udpMetaDataGet 1  
exec mdm.udpMetaDataGet @User_ID=1,@ModelCriteria=N'202a5729-9fcb-4cbf-a302-dcdc1a567b08',@VersionCriteria=N'dd883ab8-ddee-4429-8460-6513471372e4,84c20604-bbc4-4884-9dac-40504ad88329',@EntityCriteria=N'7811f06e-7004-4389-bdbf-c1743d32efe2'  
  
*/  
  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMetaDataGet]  
    (  
    @User_ID					INT,  
	@ModelCriteria				NVARCHAR(MAX) = NULL,  
	@VersionCriteria			NVARCHAR(MAX) = NULL,  
	@EntityCriteria				NVARCHAR(MAX) = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON  
	  
	DECLARE @SQL	NVARCHAR(MAX)  
	DECLARE @UserID	NVARCHAR(100)  
  
	SET @UserID = CONVERT(NVARCHAR(100),@User_ID)  
	SET @SQL = CAST(N'  
				SELECT   
					X.Model_ID,  
					M.MUID as Model_MUID,  
					M.Name as Model_Name,  
					MV.ID as Version_ID,  
					MV.MUID as Version_MUID,  
					MV.Name as Version_Name,  
					X.Entity_ID,  
					E.MUID as Entity_MUID,  
					E.Name as Entity_Name,  
					X.MemberType_ID,  
					X.Hierarchy_ID,  
					X.HierarchyType_ID   
				FROM  
					(  
						--Entities  
						select E.Model_ID,E.ID as Entity_ID,MT.ID as MemberType_ID,NULL as Hierarchy_ID ,NULL as HierarchyType_ID   
						from mdm.viw_SYSTEM_SECURITY_USER_ENTITY E  
							INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE MT ON MT.Entity_ID=E.ID AND E.User_ID=MT.User_ID  
						WHERE   
							E.User_ID = @UserID AND   
							E.Privilege_ID <> 1  
  
					) X  
						INNER JOIN mdm.tblModelVersion MV ON MV.Model_ID = X.Model_ID   
						INNER JOIN mdm.tblModel M ON M.ID = X.Model_ID   
						LEFT JOIN mdm.tblEntity E ON E.ID = X.Entity_ID   
					WHERE 1=1  
				' AS NVARCHAR(max))  
				IF (@ModelCriteria IS NOT NULL) AND (LEN(@ModelCriteria) > 0) SET @SQL = @SQL + N' AND M.MUID IN (''' + REPLACE(@ModelCriteria,N',',N''',''') + N''') '  
				IF (@VersionCriteria IS NOT NULL) AND (LEN(@VersionCriteria) > 0)  SET @SQL = @SQL + N' AND MV.MUID IN (''' + REPLACE(@VersionCriteria,N',',N''',''') + N''') '  
				IF (@EntityCriteria IS NOT NULL) AND (LEN(@EntityCriteria) > 0) SET @SQL = @SQL + N' AND E.MUID IN (''' + REPLACE(@EntityCriteria,N',',N''',''') + N''') '  
  
				SET @SQL = @SQL + N'  
				ORDER BY   
					X.Model_ID,  
					MV.ID,  
					X.Entity_ID,  
					X.MemberType_ID,  
					X.Hierarchy_ID,  
					X.HierarchyType_ID  
				'  
		EXEC sp_executesql @SQL, N'@UserID INT', @UserID;  
  
		SET NOCOUNT OFF  
END --proc
GO
