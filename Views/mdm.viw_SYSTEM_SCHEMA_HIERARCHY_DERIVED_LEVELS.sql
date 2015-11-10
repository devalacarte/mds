SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS]  
/*WITH SCHEMABINDING*/  
AS  
  
SELECT  
   tMod.ID            Model_ID,   
   tMod.MUID          Model_MUID,   
   tMod.Name          Model_Name,    
   tMod.IsSystem      Model_IsSystem,    
   tHir.ID            Hierarchy_ID,   
   tHir.MUID          Hierarchy_MUID,   
   tHir.Name          Hierarchy_Name,   
   Hierarchy_Label  = N'Derived: ' + tMod.Name + ': ' + tHir.Name,   
   --  
    usrE.ID EnteredUser_ID,  
    usrE.MUID EnteredUser_MUID,  
    usrE.UserName EnteredUser_UserName,  
    tHir.EnterDTM EnteredUser_DTM,  
    usrL.ID LastChgUser_ID,  
    usrL.MUID LastChgUser_MUID,  
    usrL.UserName LastChgUser_UserName,  
    tHir.LastChgDTM LastChgUser_DTM,  
   ---  
   tDet.ID,  
   tDet.MUID,  
   tDet.Name,   
   tDet.DisplayName,   
   ISNULL(tDet.Object_ID, 1) Object_ID,   
   ISNULL(tObj.Name, N'< Model >') Object_Name,  
   ISNULL(tDet.ForeignType_ID, 0) ForeignType_ID,  
   ISNULL(tDet.ForeignType_Name, '') ForeignType_Name,  
   ISNULL(tDet.Foreign_ID, tMod.ID) Foreign_ID,  
   ISNULL(tDet.Foreign_MUID, tMod.MUID) Foreign_MUID,  
   ISNULL(tDet.Foreign_Name, tMod.MUID) Foreign_Name,  
   ISNULL(tDet.ForeignEntity_ID, 0) ForeignEntity_ID,  
   ISNULL(tDet.ForeignEntity_MUID, CAST(0x0 AS UNIQUEIDENTIFIER)) ForeignEntity_MUID,  
   ISNULL(tDet.ForeignEntity_Name, '') ForeignEntity_Name,  
   ISNULL(tDet.ForeignParent_ID, 0) ForeignParent_ID,  
   LevelNumber = ABS(LevelNumber - tLevels.Levels),   
   tDet.LevelNumber dhLevelNumber,   
   tDet.IsLevelVisible,  
   tDet.MemberType_ID,  
   tDet.MemberType_Name,  
   tDet.IsRecursive,  
   ---  
    usrDetE.ID Detail_EnteredUser_ID,  
    usrDetE.MUID Detail_EnteredUser_MUID,  
    usrDetE.UserName Detail_EnteredUser_UserName,  
    tDet.EnterDTM Detail_EnteredUser_DTM,  
    usrDetL.ID Detail_LastChgUser_ID,  
    usrDetL.MUID Detail_LastChgUser_MUID,  
    usrDetL.UserName Detail_LastChgUser_UserName,  
    tDet.LastChgDTM Detail_LastChgUser_DTM  
FROM  
   mdm.tblModel tMod   
   JOIN mdm.tblDerivedHierarchy tHir ON tMod.ID = tHir.Model_ID   
   JOIN (SELECT DerivedHierarchy_ID, MAX(Level_ID) Levels FROM mdm.tblDerivedHierarchyDetail GROUP BY DerivedHierarchy_ID) tLevels ON tHir.ID = tLevels.DerivedHierarchy_ID  
    JOIN mdm.tblUser usrE ON tHir.EnterUserID = usrE.ID  
    JOIN mdm.tblUser usrL ON tHir.LastChgUserID = usrL.ID  
   LEFT JOIN    
   (  
   --Derived Hierarchy: Entities  
   SELECT tDet.ID, tDet.MUID, DerivedHierarchy_ID, 3 Object_ID, ForeignType_ID, 'Entity' ForeignType_Name, Foreign_ID, tEnt.MUID [Foreign_MUID], tEnt.Name [Foreign_Name], NULL [ForeignEntity_ID], NULL [ForeignEntity_MUID], NULL [ForeignEntity_Name], ForeignParent_ID, tDet.Name, tDet.DisplayName, Level_ID LevelNumber, tDet.IsVisible IsLevelVisible, tMt.ID MemberType_ID, tMt.Name MemberType_Name, 0 AS IsRecursive, tDet.EnterUserID, tDet.EnterDTM, tDet.LastChgUserID, tDet.LastChgDTM   
   FROM mdm.tblDerivedHierarchyDetail tDet   
    INNER JOIN mdm.tblEntity tEnt ON tDet.Foreign_ID = tEnt.ID AND ForeignType_ID = 0   
    INNER JOIN mdm.tblEntityMemberType tMt ON tMt.ID = 1  
   UNION  
   --Derived Hierarchy: Attributes  
   SELECT tDet.ID, tDet.MUID, DerivedHierarchy_ID, 4 Object_ID, ForeignType_ID, 'Dba' ForeignType_Name, Foreign_ID, tAtt.MUID [Foreign_MUID], tAtt.Name [Foreign_Name], tEnt.ID [ForeignEntity_ID], tEnt.MUID [ForeignEntity_MUID], tEnt.Name [ForeignEntity_Name], ForeignParent_ID Attribute_ID, tDet.Name, tDet.DisplayName, Level_ID LevelNumber, tDet.IsVisible IsLevelVisible, tMt.ID MemberType_ID, tMt.Name MemberType_Name, CASE tAtt.Entity_ID  WHEN tAtt.DomainEntity_ID THEN 1 ELSE 0 END AS IsRecursive, tDet.EnterUserID, tDet.EnterDTM, tDet.LastChgUserID, tDet.LastChgDTM   
   FROM mdm.tblDerivedHierarchyDetail tDet   
    INNER JOIN mdm.tblAttribute tAtt ON tDet.Foreign_ID = tAtt.ID AND ForeignType_ID = 1   
    INNER JOIN mdm.tblEntityMemberType tMt ON tMt.ID = 1  
    INNER JOIN mdm.tblEntity tEnt ON tAtt.Entity_ID = tEnt.ID  
   UNION  
   --Derived Hierarchy: Domain Entity (associated with the attributes)  
   SELECT tDet.ID, tDet.MUID, DerivedHierarchy_ID, 3 Object_ID, ForeignType_ID, 'Dba' ForeignType_Name, tAtt.DomainEntity_ID, tEnt.MUID [Foreign_MUID], tEnt.Name [Foreign_Name], NULL, NULL, NULL,  -1, tEnt.Name, tDet.DisplayName, Level_ID LevelNumber, tDet.IsVisible IsLevelVisible, tMt.ID MemberType_ID, tMt.Name MemberType_Name, CASE tAtt.Entity_ID  WHEN tAtt.DomainEntity_ID THEN 1 ELSE 0 END AS IsRecursive, tDet.EnterUserID, tDet.EnterDTM, tDet.LastChgUserID, tDet.LastChgDTM   
   FROM mdm.tblDerivedHierarchyDetail tDet   
    INNER JOIN mdm.tblAttribute tAtt ON tDet.Foreign_ID = tAtt.ID   
    INNER JOIN mdm.tblEntity tEnt ON tAtt.DomainEntity_ID = tEnt.ID AND tDet.ForeignType_ID = 1   
    INNER JOIN mdm.tblEntityMemberType tMt ON tMt.ID = 1  
   UNION  
   --Derived Hierarchy: Explicit Hierarchies  
   SELECT tDet.ID, tDet.MUID, DerivedHierarchy_ID, 6 Object_ID, ForeignType_ID, 'Hierarchy' ForeignType_Name, Foreign_ID, tHir.MUID [Foreign_MUID], tHir.Name [Foreign_Name], tEnt.ID [ForeignEntity_ID], tEnt.MUID [ForeignEntity_MUID], tEnt.Name [ForeignEntity_Name], ForeignParent_ID Hierarchy_ID, tDet.Name, tDet.DisplayName, Level_ID LevelNumber, tDet.IsVisible IsLevelVisible, tMt.ID MemberType_ID, tMt.Name MemberType_Name, 0 AS IsRecursive, tDet.EnterUserID, tDet.EnterDTM, tDet.LastChgUserID, tDet.LastChgDTM   
   FROM mdm.tblDerivedHierarchyDetail tDet   
    INNER JOIN mdm.tblHierarchy tHir ON tDet.Foreign_ID = tHir.ID AND ForeignType_ID = 2   
    INNER JOIN mdm.tblEntityMemberType tMt ON tMt.ID = 2  
    INNER JOIN mdm.tblEntity tEnt ON tHir.Entity_ID = tEnt.ID  
   UNION  
   --Derived Hierarchy: Consolidations (consolidated DBAs qualify as entities)  
   SELECT tDet.ID, tDet.MUID, DerivedHierarchy_ID, 3 Object_ID, ForeignType_ID, 'ConsolidatedDba' ForeignType_Name, Foreign_ID, tEnt.MUID [Foreign_MUID],tEnt.Name [Foreign_Name], NULL, NULL, NULL, ForeignParent_ID Member_ID, tDet.Name, tDet.DisplayName, Level_ID LevelNumber, tDet.IsVisible IsLevelVisible, tMt.ID MemberType_ID, tMt.Name MemberType_Name, 0 AS IsRecursive, tDet.EnterUserID, tDet.EnterDTM, tDet.LastChgUserID, tDet.LastChgDTM  
   FROM mdm.tblDerivedHierarchyDetail tDet   
    INNER JOIN mdm.tblEntity tEnt ON tDet.Foreign_ID = tEnt.ID AND ForeignType_ID = 3   
    INNER JOIN mdm.tblEntityMemberType tMt ON tMt.ID = 2  
   ) tDet ON tHir.ID = tDet.DerivedHierarchy_ID  
    JOIN mdm.tblUser usrDetE ON tDet.EnterUserID = usrDetE.ID  
    JOIN mdm.tblUser usrDetL ON tDet.LastChgUserID = usrDetL.ID  
   LEFT JOIN mdm.tblSecurityObject tObj ON tDet.Object_ID = tObj.ID
GO
