SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
select * from mdm.tblSubscriptionView  
EXEC [mdm].[udpSubscriptionViewGet]  
*/  
  
CREATE PROCEDURE [mdm].[udpSubscriptionViewGet]  
  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	SELECT	  
		S.ID				AS View_ID  
		,S.MUID				AS View_Muid  
		,S.Name				AS View_Name  
		,S.Levels			AS View_Levels			  
		,S.IsDirty			AS View_IsDirty  
		,S.ViewFormat_ID	AS View_Format    
		,M.ID				AS Model_ID  
		,M.MUID				AS Model_Muid  
		,M.Name				AS MOdel_Name  
		,E.ID				AS Entity_ID  
		,E.MUID				AS Entity_Muid				  
		,E.Name				AS Entity_Name  
		,MV.ID				AS Version_ID  
		,MV.MUID			AS Version_Muid  
		,MV.Name			AS Version_Name  
		,D.ID				AS DerivedHierarchy_ID  
		,D.MUID				AS DerivedHierarchy_Muid  
		,D.Name				AS DerivedHierarchy_Name			  
		,MVF.ID				AS VersionFlag_ID  
		,MVF.MUID			AS VersionFlag_Muid  
		,MVF.Name			AS VersionFlag_Name  
			  
	FROM mdm.tblSubscriptionView S  
		LEFT OUTER JOIN mdm.tblEntity E ON S.Entity_ID = E.ID  
		INNER JOIN mdm.tblModel M ON S.Model_ID = M.ID  
		LEFT JOIN mdm.tblModelVersion MV ON S.ModelVersion_ID = MV.ID  
		LEFT OUTER JOIN mdm.tblModelVersionFlag MVF ON S.ModelVersionFlag_ID = MVF.ID	  
		LEFT OUTER JOIN mdm.tblDerivedHierarchy D ON S.DerivedHierarchy_ID = D.ID  
				  
	SET NOCOUNT OFF;  
END;
GO
