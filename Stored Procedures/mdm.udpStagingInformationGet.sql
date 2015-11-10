SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
--This gets the counts of all the records that are NOT associated with a batch(Unbatched) per Model  
--It will get the counts for the supplied user AND records that are not associated with a user  
  
EXEC mdm.udpStagingInformationGet 1  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpStagingInformationGet]  
(  
    @User_ID		INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @UserName AS NVARCHAR(100);  
	SET @UserName = mdm.udfUserNameGetByUserID(@User_ID);  
  
	SELECT  
		M.MUID Model_Muid  
		,ISNULL(X.Model,'') Model_Name  
		,Sum(X.MemberCount) MemberCount  
		,Sum(X.MemberAttributeCount) MemberAttributeCount  
		,Sum(X.MemberRelationshipCount) MemberRelationshipCount  
	FROM  
	(  
		SELECT  
			tStg.ModelName AS Model,COUNT(*) AS MemberCount,0 AS MemberAttributeCount,0 AS MemberRelationshipCount   
		FROM      
			mdm.tblStgMember tStg  
		WHERE  
			@UserName = COALESCE(NULLIF(LTRIM(RTRIM(UserName)), N''), @UserName)  
			AND Batch_ID IS NULL  
		GROUP BY  
			ModelName  
  
		UNION ALL  
  
		SELECT  
			tStg.ModelName AS Model,0 AS MemberCount,COUNT(*) AS MemberAttributeCount,0 AS MemberRelationshipCount   
		FROM      
			mdm.tblStgMemberAttribute tStg  
		WHERE  
			@UserName = COALESCE(NULLIF(LTRIM(RTRIM(UserName)), N''), @UserName)  
			AND Batch_ID IS NULL  
		GROUP BY  
			ModelName  
  
		UNION ALL  
  
		SELECT  
			tStg.ModelName AS Model,0 AS MemberCount,0 AS MemberAttributeCount,COUNT(*) AS MemberRelationshipCount   
		FROM      
			mdm.tblStgRelationship tStg  
		WHERE  
			@UserName = COALESCE(NULLIF(LTRIM(RTRIM(UserName)), N''), @UserName)  
			AND Batch_ID IS NULL  
		GROUP BY  
			ModelName  
	) X  
	LEFT JOIN mdm.tblModel M ON UPPER(M.Name) = UPPER(X.Model)  
	GROUP BY M.MUID,X.Model  
  
  
	SET NOCOUNT OFF;  
END; --proc
GO
