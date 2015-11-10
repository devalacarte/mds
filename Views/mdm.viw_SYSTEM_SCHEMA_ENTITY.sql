SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ENTITY  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ENTITY WHERE ID = 31  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_ENTITY]  
/*WITH SCHEMABINDING*/  
AS  
SELECT	  
	 ent.ID  
	,ent.ID Entity_ID  
	,ent.MUID  
	,ent.Name  
	,ent.IsBase  
	,ent.EntityTable  
	,ent.HierarchyTable  
	,ent.HierarchyParentTable  
	,ent.CollectionTable  
	,ent.CollectionMemberTable  
	,ent.StagingBase  
	,ent.StagingBase + N'_Leaf' AS StagingLeafTable  
	,CASE ent.IsFlat  
		WHEN 0 THEN	ent.StagingBase + N'_Consolidated'  
		ELSE NULL  
	 END AS StagingConsolidatedTable  
	 ,CASE ent.IsFlat  
		WHEN 0 THEN	ent.StagingBase + N'_Relationship'  
		ELSE NULL  
	 END AS StagingRelationshipTable  
	,CONVERT(BIT, 1 - ent.IsFlat) AS HierarchyInd --Redundant  
	,ent.IsFlat  
	,ent.IsSystem  
	,ent.Model_ID  
	,mdl.MUID AS Model_MUID  
	,mdl.Name AS Model_Name  
	,usrE.ID AS EnteredUser_ID  
	,usrE.MUID AS EnteredUser_MUID  
	,usrE.UserName AS EnteredUser_UserName  
	,ent.EnterDTM AS EnteredUser_DTM  
	,usrL.ID AS LastChgUser_ID  
	,usrL.MUID AS LastChgUser_MUID  
	,usrL.UserName AS LastChgUser_UserName  
	,ent.LastChgDTM AS LastChgUser_DTM  
    ,CASE WHEN codegen.Seed IS NULL THEN 0 ELSE 1 END AS IsCodeGenerationEnabled  
    ,CASE WHEN codegen.Seed IS NULL THEN 0 ELSE codegen.Seed END as CodeGenerationSeed  
FROM  
	mdm.tblEntity AS ent   
	INNER JOIN mdm.tblModel AS mdl  
		ON mdl.ID = ent.Model_ID   
	INNER JOIN mdm.tblUser AS usrE  
		ON ent.EnterUserID = usrE.ID  
	INNER JOIN mdm.tblUser AS usrL  
		ON ent.LastChgUserID = usrL.ID  
    LEFT OUTER JOIN mdm.tblCodeGenInfo AS codegen  
        ON codegen.EntityId = ent.ID  
;
GO
