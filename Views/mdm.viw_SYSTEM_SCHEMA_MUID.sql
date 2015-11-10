SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_MUID  
	WHERE ObjectTypeID = 4;  
  
ObjectTypeID  
 1=Model  
 2=DerivedHierarchy  
 3=DerivedHierarchyDetail  
 4=Version  
 5=Entity  
 6=ExplicitHierarchy  
 7=Attribute  
 8=AttributeGroup  
 9=Staging Batch  
10=Version Flag  
20 = ExportView(SubscriptionView)  
  
ObjectSubTypeID  
NULL=Not Applicable  
1=Leaf  
2=Consolidated  
3=Collection  
*/  
  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_MUID]   
/*WITH SCHEMABINDING*/  
AS   
	SELECT   
		1		AS ObjectTypeID,   
		NULL	AS ObjectSubTypeID,  
		NULL	AS ParentObjectTypeID,   
		M.ID	AS ObjectID,   
		NULL	AS ParentObjectID,  
        NULL    AS ParentObjectMUID,   
		M.[Name] ,   
		M.MUID,  
		S.User_ID AS UserID,  
		CASE S.Privilege_ID WHEN 99 THEN 3 ELSE S.Privilege_ID END AS PrivilegeID		  
	FROM mdm.tblModel M  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL S ON S.ID=M.ID  
  
	UNION ALL  
		  
	SELECT 2, NULL,1, dh.ID, dh.Model_ID, mdl.MUID, dh.[Name], dh.MUID,S.User_ID,S.Privilege_ID   
	FROM mdm.tblDerivedHierarchy dh INNER JOIN mdm.tblModel mdl ON dh.Model_ID = mdl.ID  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY_DERIVED S ON S.ID=dh.ID  
	  
	UNION ALL  
	  
	SELECT 3, NULL,2, dhd.ID, DerivedHierarchy_ID, dh.MUID, dhd.[Name], dhd.MUID,null,2   
	FROM mdm.tblDerivedHierarchyDetail dhd   
	INNER JOIN mdm.tblDerivedHierarchy dh ON dhd.DerivedHierarchy_ID = dh.ID	  
	  
	UNION ALL  
	  
	SELECT 4, NULL,1, ver.ID, Model_ID, mdl.MUID, ver.[Name], ver.MUID,S.User_ID,CASE WHEN Status_ID = 3 THEN 3 WHEN Status_ID = 2 AND S.IsAdministrator=1 THEN 2 WHEN Status_ID = 2 AND S.IsAdministrator<>1 THEN 3 ELSE 2 END   
	FROM mdm.tblModelVersion ver INNER JOIN mdm.tblModel mdl ON ver.Model_ID = mdl.ID	  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL S ON S.ID=ver.Model_ID  
	  
	UNION ALL  
	  
	SELECT 5, ST.ID,1, ent.ID, ent.Model_ID, mdl.MUID, ent.[Name], ent.MUID,S.User_ID,S.Privilege_ID   
	FROM mdm.tblEntity ent   
	INNER JOIN mdm.tblModel mdl ON ent.Model_ID = mdl.ID  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ENTITY S ON S.ID=ent.ID  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE ST ON ST.Entity_ID=S.ID --AND ST.ID=1  
	  
	UNION ALL  
/*  
	SELECT 6, 1, ent.ID, ent.Model_ID, mdl.MUID, ent.[Name], ent.MUID,S.User_ID,S.Privilege_ID   
	FROM mdm.tblEntity ent   
	INNER JOIN mdm.tblModel mdl ON ent.Model_ID = mdl.ID  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ENTITY S ON S.ID=ent.ID  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE ST ON ST.Entity_ID=S.ID AND ST.ID=2  
	  
	UNION ALL  
  
	SELECT 7, 1, ent.ID, ent.Model_ID, mdl.MUID, ent.[Name], ent.MUID,S.User_ID,S.Privilege_ID   
	FROM mdm.tblEntity ent   
	INNER JOIN mdm.tblModel mdl ON ent.Model_ID = mdl.ID  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ENTITY S ON S.ID=ent.ID  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE ST ON ST.Entity_ID=S.ID AND ST.ID=3  
	  
	UNION ALL  
*/  
	  
	SELECT 6, NULL,5, hir.ID, hir.Entity_ID, ent.MUID, hir.[Name], hir.MUID,S.User_ID,S.Privilege_ID   
	FROM mdm.tblHierarchy hir   
	INNER JOIN mdm.tblEntity ent ON hir.Entity_ID = ent.ID  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY S ON S.ID=hir.ID  
  
	UNION ALL  
	  
	SELECT 7, att.MemberType_ID,5, att.ID, att.Entity_ID, ent.MUID, att.[Name], att.MUID,S.User_ID,S.Privilege_ID   
	FROM mdm.tblAttribute att   
	INNER JOIN mdm.tblEntity ent ON att.Entity_ID = ent.ID AND AttributeType_ID <> 3 --AND att.MemberType_ID=1  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTE S ON S.ID=att.ID  
		  
	UNION ALL  
/*  
	SELECT 10, 5, att.ID, att.Entity_ID, ent.MUID, att.[Name], att.MUID,S.User_ID,S.Privilege_ID   
	FROM mdm.tblAttribute att   
	INNER JOIN mdm.tblEntity ent ON att.Entity_ID = ent.ID AND AttributeType_ID <> 3 AND att.MemberType_ID=2  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTE S ON S.ID=att.ID  
		  
	UNION ALL  
  
	SELECT 11, 5, att.ID, att.Entity_ID, ent.MUID, att.[Name], att.MUID,S.User_ID,S.Privilege_ID   
	FROM mdm.tblAttribute att   
	INNER JOIN mdm.tblEntity ent ON att.Entity_ID = ent.ID AND AttributeType_ID <> 3 AND att.MemberType_ID=3  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTE S ON S.ID=att.ID  
	  
	UNION ALL  
*/		  
	SELECT 8, NULL,5, grp.ID, grp.Entity_ID, ent.MUID, grp.[Name], grp.MUID,S.User_ID,S.Privilege_ID   
	FROM mdm.tblAttributeGroup grp   
	INNER JOIN mdm.tblEntity ent ON grp.Entity_ID = ent.ID  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTEGROUP S ON S.ID=grp.ID  
	  
	UNION ALL  
	SELECT 9, NULL,NULL, btc.ID, NULL, NULL, btc.[Name], btc.MUID,null,2   
	FROM mdm.tblStgBatch btc  
  
	UNION ALL  
	  
	SELECT 10, NULL,1, flg.ID, Model_ID, mdl.MUID, flg.[Name], flg.MUID,S.User_ID,CASE WHEN Status_ID = 3 THEN 3 WHEN Status_ID = 2 AND S.IsAdministrator=1 THEN 2 WHEN Status_ID = 2 AND S.IsAdministrator<>1 THEN 3 ELSE 2 END   
	FROM mdm.tblModelVersionFlag flg INNER JOIN mdm.tblModel mdl ON flg.Model_ID = mdl.ID	  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL S ON S.ID=flg.Model_ID  
	  
	UNION ALL  
	  
	SELECT 20,NULL,NULL,ID,NULL,NULL,Name,MUID,NULL,2  
	FROM mdm.tblSubscriptionView
GO
