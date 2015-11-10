SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_MODELS]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
   -----Models, versions, and users  
   tMod.ID                 Model_ID,   
   tMod.MUID			   Model_MUID,      
   tMod.Name               Model_Name,      
   tMod.Name               Model_Label,      
   tMod.IsSystem           Model_IsSystem,    
   tVer.ID                 Version_ID,   
   tVer.MUID               Version_MUID,   
   tVer.Name               Version_Name,   
   tVer.Display_ID         Version_Number,   
   tVer.Description        Version_Description,   
   --  
   tVer.EnterUserID        Version_UserIDCreated,  
   Version_UserNameCreated = (SELECT UserName FROM mdm.tblUser WHERE ID = tVer.EnterUserID),   
   tVer.EnterDTM           Version_DateCreated,   
   tVer.LastChgUserID      Version_UserIDUpdated,   
   Version_UserNameUpdated = (SELECT UserName FROM mdm.tblUser WHERE ID = tVer.LastChgUserID),   
   tVer.LastChgDTM         Version_DateUpdated,  
   --  
   tVerStatus.ID           Version_StatusID,   
   tVerStatus.Name         Version_Status,   
   tVerFlag.ID             Version_FlagID,   
   tVerFlag.Name           Version_FlagName,   
   tVer.AsOfVersion_ID     Version_SourceVersionID,   
   -----Entities  
   tEnt.ID					Entity_ID,   
   tEnt.MUID				Entity_MUID,  
   tEnt.Name				Entity_Name,   
   Entity_Label = tMod.Name + N': ' + tEnt.Name,   
   tEnt.IsBase				Entity_IsBase,  
   tEnt.IsSystem			Entity_IsSystem,  
   Entity_HasHierarchy = CASE(LEN(tEnt.HierarchyTable)) WHEN 0 THEN 0 ELSE 1 END,   
   --  
   tEnt.EnterUserID			Entity_UserIDCreated,   
   Entity_UserNameCreated = (SELECT UserName FROM mdm.tblUser WHERE ID = tEnt.EnterUserID),   
   tEnt.EnterDTM			Entity_DateCreated,   
   tEnt.LastChgUserID		Entity_UserIDUpdated,   
   Entity_UserNameUpdated = (SELECT UserName FROM mdm.tblUser WHERE ID = tEnt.LastChgUserID),   
   tEnt.LastChgDTM			Entity_DateUpdated,  
   tEnt.LastChgVersionID	Entity_VersionIDUpdated,  
   --Tables  
   Entity_Table					= tEnt.EntityTable,  
   Entity_HierarchyTable		= tEnt.HierarchyTable,  
   Entity_HierarchyParentTable	= tEnt.HierarchyParentTable,  
   Entity_CollectionTable		= tEnt.CollectionTable,  
   Entity_CollectionMemberTable = tEnt.CollectionMemberTable,  
   -----Hierarchies  
   tHir.ID          Hierarchy_ID,   
   tHir.MUID        Hierarchy_MUID,  
   tHir.Name        Hierarchy_Name,   
   Hierarchy_Label  = N'Explicit : ' + tEnt.Name + N': ' + tHir.Name,   
   HierarchyType_ID = (SELECT OptionID FROM mdm.tblList WHERE ListCode = CAST(N'lstHierarchyType' AS NVARCHAR(50)) AND ListOption = CAST(N'Explicit' AS NVARCHAR(250))),   
   tHir.IsMandatory Hierarchy_IsMandatory,  
   --  
   tHir.EnterUserID          Hierarchy_UserIDCreated,   
   Hierarchy_UserNameCreated = (SELECT UserName FROM mdm.tblUser WHERE ID = tHir.EnterUserID),   
   tHir.EnterDTM             Hierarchy_DateCreated,   
   tHir.LastChgUserID        Hierarchy_UserIDUpdated,   
   Hierarchy_UserNameUpdated = (SELECT UserName FROM mdm.tblUser WHERE ID = tHir.LastChgUserID),   
   tHir.LastChgDTM           Hierarchy_DateUpdated,  
   tHir.LastChgVersionID     Hierarchy_VersionIDUpdated,  
   -----Member Types  
   MemberType_ID    = tType.ID,  
   MemberType_Name  = tType.Name,  
   MemberType_Label = tMod.Name + N': ' + tEnt.Name + N': ' + tType.Name  
FROM  
   mdm.tblModel AS tMod   
   INNER JOIN mdm.tblModelVersion tVer ON tMod.ID = tVer.Model_ID   
   INNER JOIN mdm.tblEntity tEnt ON tMod.ID = tEnt.Model_ID   
   INNER JOIN mdm.tblHierarchy tHir ON tEnt.ID = tHir.Entity_ID     
   INNER JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = CAST(N'lstVersionStatus' AS NVARCHAR(50))) tVerStatus ON tVer.Status_ID = tVerStatus.ID  
   LEFT OUTER JOIN (SELECT ID, Model_ID, Name FROM mdm.tblModelVersionFlag) tVerFlag ON tVer.VersionFlag_ID = tVerFlag.ID  
   --CROSS JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = N'lstAttributeMemberType' AND ListOption IN (N'Consolidated', N'Collection')) tType  
	CROSS JOIN (SELECT ID, [Name] FROM mdm.tblEntityMemberType WHERE ID = 2 OR ID = 3) AS tType  
UNION  
  
SELECT  
   -----Models, versions, and users  
   tMod.ID                 Model_ID,   
   tMod.MUID			   Model_MUID,      
   tMod.Name               Model_Name,      
   tMod.Name               Model_Label,    
   tMod.IsSystem           Model_IsSystem,    
   tVer.ID                 Version_ID,   
   tVer.MUID               Version_MUID,   
   tVer.Name               Version_Name,   
   tVer.Display_ID         Version_Number,   
   tVer.Description        Version_Description,   
   --  
   tVer.EnterUserID        Version_UserIDCreated,  
   Version_UserNameCreated = (SELECT UserName FROM mdm.tblUser WHERE ID = tVer.EnterUserID),   
   tVer.EnterDTM           Version_DateCreated,   
   tVer.LastChgUserID      Version_UserIDUpdated,   
   Version_UserNameUpdated = (SELECT UserName FROM mdm.tblUser WHERE ID = tVer.LastChgUserID),   
   tVer.LastChgDTM         Version_DateUpdated,  
   --  
   tVerStatus.ID           Version_StatusID,   
   tVerStatus.Name         Version_Status,   
   tVerFlag.ID             Version_FlagID,   
   tVerFlag.Name           Version_FlagName,   
   tVer.AsOfVersion_ID     Version_SourceVersionID,   
   -----Entities  
   tEnt.ID					Entity_ID,   
   tEnt.MUID				Entity_MUID,  
   tEnt.Name				Entity_Name,   
   Entity_Label = tMod.Name + N': ' + tEnt.Name,   
   tEnt.IsBase				Entity_IsBase,  
   tEnt.IsSystem			Entity_IsSystem,  
   Entity_HasHierarchy = CASE(LEN(tEnt.HierarchyTable)) WHEN 0 THEN 0 ELSE 1 END,   
   --  
   tEnt.EnterUserID			Entity_UserIDCreated,   
   Entity_UserNameCreated = (SELECT UserName FROM mdm.tblUser WHERE ID = tEnt.EnterUserID),   
   tEnt.EnterDTM			Entity_DateCreated,   
   tEnt.LastChgUserID		Entity_UserIDUpdated,   
   Entity_UserNameUpdated = (SELECT UserName FROM mdm.tblUser WHERE ID = tEnt.LastChgUserID),   
   tEnt.LastChgDTM			Entity_DateUpdated,  
   tEnt.LastChgVersionID	Entity_VersionIDUpdated,  
   --Tables  
   Entity_Table = tEnt.EntityTable,  
   Entity_HierarchyTable = tEnt.HierarchyTable,  
   Entity_HierarchyParentTable = tEnt.HierarchyParentTable,  
   Entity_CollectionTable = tEnt.CollectionTable,  
   Entity_CollectionMemberTable = tEnt.CollectionMemberTable,  
   -----Hierarchies  
   tHir.ID          Hierarchy_ID,   
   tHir.MUID        Hierarchy_MUID,  
   tHir.Name        Hierarchy_Name,   
   Hierarchy_Label  = N'Explicit : ' + tEnt.Name + N': ' + tHir.Name,   
   HierarchyType_ID = (SELECT OptionID FROM mdm.tblList WHERE ListCode = CAST(N'lstHierarchyType' AS NVARCHAR(50)) AND ListOption = CAST(N'Explicit' AS NVARCHAR(250))),   
   tHir.IsMandatory Hierarchy_IsMandatory,  
   --  
   tHir.EnterUserID          Hierarchy_UserIDCreated,   
   Hierarchy_UserNameCreated = (SELECT UserName FROM mdm.tblUser WHERE ID = tHir.EnterUserID),   
   tHir.EnterDTM             Hierarchy_DateCreated,   
   tHir.LastChgUserID        Hierarchy_UserIDUpdated,   
   Hierarchy_UserNameUpdated = (SELECT UserName FROM mdm.tblUser WHERE ID = tHir.LastChgUserID),   
   tHir.LastChgDTM           Hierarchy_DateUpdated,  
   tHir.LastChgVersionID     Hierarchy_VersionIDUpdated,  
   -----Member Types  
   MemberType_ID    = tType.ID,  
   MemberType_Name  = tType.Name,  
   MemberType_Label = tMod.Name + N': ' + tEnt.Name + N': ' + tType.Name  
FROM  
   mdm.tblModel tMod   
   INNER JOIN mdm.tblModelVersion tVer ON tMod.ID = tVer.Model_ID   
   INNER JOIN mdm.tblEntity tEnt ON tMod.ID = tEnt.Model_ID   
   LEFT OUTER JOIN mdm.tblHierarchy tHir ON tEnt.ID = tHir.Entity_ID     
   INNER JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = CAST(N'lstVersionStatus' AS NVARCHAR(50))) tVerStatus ON tVer.Status_ID = tVerStatus.ID  
   LEFT OUTER JOIN (SELECT ID, Model_ID, Name FROM mdm.tblModelVersionFlag) tVerFlag ON tVer.VersionFlag_ID = tVerFlag.ID  
   --CROSS JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = N'lstAttributeMemberType' AND ListOption = N'Leaf') tType   
   CROSS JOIN (SELECT ID, Name FROM mdm.tblEntityMemberType WHERE  ID = 1) tType
GO
