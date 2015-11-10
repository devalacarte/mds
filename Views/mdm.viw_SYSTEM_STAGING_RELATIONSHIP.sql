SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_STAGING_RELATIONSHIP   
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_STAGING_RELATIONSHIP]  
/*WITH SCHEMABINDING*/  
AS  
SELECT TOP 100 PERCENT  
    tStage.Batch_ID                                         Batch_ID,  
    tStage.ID                                               Stage_ID,  
    tUser.ID                                                [User_ID],  
    LTRIM(RTRIM(tStage.UserName))                           [User_Name],  
    ISNULL(tMod.ID, 0)                                      Model_ID,  
    LTRIM(RTRIM(tStage.ModelName))	                        Model_Name,  
    tSec.IsAdministrator                                    IsAdministrator,  
    ISNULL(tEnt.ID, 0)                                      Entity_ID,  
    LTRIM(RTRIM(tStage.EntityName))                         Entity_Name,  
    tEnt.EntityTable                                        Entity_Table,  
    tEnt.HierarchyParentTable                               Parent_Table,  
    tEnt.CollectionTable                                    Collection_Table,  
    mdm.udfTableNameGetByID(tEnt.ID, tStage.MemberType_ID)  Relationship_Table,  
    CONVERT(BIT, 1 - tEnt.IsFlat)                           Entity_HasHierarchy,   
    tHir.ID                                                 Hierarchy_ID,   
    LTRIM(RTRIM(tStage.HierarchyName))                      Hierarchy_Name,  
    tHir.IsMandatory                                        Hierarchy_IsMandatory,  
    tStage.MemberType_ID                                    MemberType_ID,  
    -2                                                      Member_ID,  
    tMemberType.Name                                        MemberType_Name,  
    LTRIM(RTRIM(tStage.MemberCode))                         Member_Code,  
    tStage.TargetType_ID                                    TargetType_ID,  
    tStage.SortOrder                                        SortOrder,  
    CASE  
        WHEN LTRIM(RTRIM(TargetCode)) = N'ROOT' THEN 0  
        WHEN LTRIM(RTRIM(TargetCode)) = N'MDMUNUSED' AND tHir.IsMandatory = 0 THEN -1  
        ELSE -2  
    END                                                     Target_ID,  
    tTargetType.Name                                        TargetType_Name,  
    LTRIM(RTRIM(tStage.TargetCode))                         Target_Code,  
    CASE  
        WHEN tStage.Status_ID = 1 THEN 1  
        WHEN tUser.ID IS NULL AND LEN(LTRIM(RTRIM(tStage.UserName))) > 0 THEN 2   
        WHEN tMod.ID IS NULL THEN 2 --Model is required  
        WHEN tSec.IsAdministrator = 0 THEN 2 --Model administrator privileges are required to stage into the selected model  
        WHEN tEnt.ID IS NULL THEN 2 --Entity is required  
        WHEN tHir.ID IS NULL AND tStage.MemberType_ID = 4 THEN 2 --Hierarchy is required if the type is 4  
        WHEN NOT (tStage.MemberType_ID = 4 OR tStage.MemberType_ID = 5) THEN 2 --Member type must be 4 (hierarchy) or 5 (collection)  
        WHEN tStage.MemberType_ID = 5 AND LEN(tEnt.HierarchyTable) = 0 THEN 2 --Collections may only be staged to entities that possess a hierarchy  
        WHEN LEN(LTRIM(RTRIM(MemberCode))) = 0 THEN 2 --The member code is required  
        WHEN LTRIM(RTRIM(MemberCode)) = N'ROOT' THEN 2 --The member code may not use the reserved code ROOT  
        WHEN LTRIM(RTRIM(MemberCode)) = N'MDMUNUSED' THEN 2 --The member code may not use the reserved code MDMUNUSED (for non-mandatory hierarchies)  
        WHEN NOT (tStage.TargetType_ID = 1 OR tStage.TargetType_ID = 2) THEN 2 --The target type must be 1 (parent) or 2 (sibling)  
        WHEN LEN(LTRIM(RTRIM(TargetCode))) = 0 THEN 2 --The target code is required  
        WHEN LTRIM(RTRIM(TargetCode)) = N'MDMUNUSED' AND tHir.IsMandatory <> 0 THEN 2 --May only use the reserve code MDMUNUSED for non-mandatory hierarchies   
        WHEN LTRIM(RTRIM(TargetCode)) = N'ROOT' AND tStage.TargetType_ID = 2 THEN 2 --May not stage siblings of the Root node  
        WHEN LTRIM(RTRIM(TargetCode)) = N'MDMUNUSED' AND tStage.TargetType_ID = 2 THEN 2 --May not stage siblings of the Unused node  
        WHEN LTRIM(RTRIM(MemberCode)) = LTRIM(RTRIM(TargetCode)) THEN 2 --Member code and target code may not be the same  
        WHEN tStage.MemberType_ID = 5 AND tStage.TargetType_ID = 2 THEN 2 --May not stage siblings for collections  
        ELSE 0  
    END                                                     Status_ID ,  
    CASE  
        WHEN tUser.ID IS NULL AND LEN(LTRIM(RTRIM(tStage.UserName))) > 0 THEN N'210017' -- Error - user name is invalid  
        WHEN tMod.ID IS NULL THEN N'210018' -- Error - invalid Model  
        WHEN tSec.IsAdministrator = 0 THEN N'210019' -- Error - Model administrator privileges are required to stage into the selected Model  
        WHEN tEnt.ID IS NULL THEN N'210020' -- Error - invalid entity  
        WHEN tHir.ID IS NULL AND tStage.MemberType_ID = 4 THEN N'210038'          -- Error - hierarchy is required if member type is 4; or invalid hierarchy  
        WHEN NOT (tStage.MemberType_ID = 4 OR tStage.MemberType_ID = 5) THEN N'210039' -- Error - member type ID must be 4 (hierarchy) or 5 (collection)  
        WHEN tStage.MemberType_ID = 5 AND LEN(tEnt.HierarchyTable) = 0 THEN N'210033' -- Error - collections may only be staged to entities that have a hierarchy  
        WHEN LEN(LTRIM(RTRIM(tStage.MemberCode))) = 0 THEN N'210040' -- Error - member code is required  
        WHEN UPPER(LTRIM(RTRIM(tStage.MemberCode))) = N'ROOT' THEN N'210041' -- Error - may not use reserved code ''ROOT''  
        WHEN UPPER(LTRIM(RTRIM(tStage.MemberCode))) = N'MDMUNUSED' THEN N'210042' -- Error - may not use reserved code ''MDMUNUSED''  
        WHEN NOT (tStage.TargetType_ID = 1 OR tStage.TargetType_ID = 2) THEN N'210043' -- Error - target type ID must be 1 (parent) or 2 (sibling)  
        WHEN LEN(LTRIM(RTRIM(tStage.TargetCode))) = 0 THEN N'210044' -- Error - target code is required  
        WHEN UPPER(LTRIM(RTRIM(tStage.TargetCode))) = N'MDMUNUSED' AND tHir.IsMandatory <> 0 THEN N'210045' -- Error - may not use reserved code ''MDMUNUSED'' in non-mandatory hierarchies  
        WHEN UPPER(LTRIM(RTRIM(tStage.TargetCode))) = N'ROOT' AND tStage.TargetType_ID = 2 THEN N'210046' -- Error - may not stage a sibling of the Root node  
        WHEN UPPER(LTRIM(RTRIM(tStage.TargetCode))) = N'MDMUNUSED' AND tStage.TargetType_ID = 2 THEN N'210047' -- Error - may not stage a sibling of the Unused node  
        WHEN LTRIM(RTRIM(tStage.MemberCode)) = LTRIM(RTRIM(tStage.TargetCode)) THEN N'210048' -- Error - member code and target code may not be the same  
        WHEN tStage.MemberType_ID = 5 AND tStage.TargetType_ID = 2 THEN N'210049' -- Error - may not stage siblings for collections  
        WHEN LEN(LTRIM(RTRIM(tStage.HierarchyName))) > 0 AND tStage.MemberType_ID = 5 THEN N'210050'    -- Information - hierarchy is not required for collections        
        ELSE ''  
    END                                                     Status_ErrorCode  
FROM   
   mdm.tblStgRelationship tStage  
   LEFT OUTER JOIN mdm.tblUser tUser ON LTRIM(RTRIM(tStage.UserName)) = tUser.UserName AND tUser.Status_ID=1  
   LEFT OUTER JOIN mdm.tblModel tMod ON LTRIM(RTRIM(tStage.ModelName)) = tMod.Name AND tMod.IsSystem <> 1 -- skipping meta models (IsSystem = 1) for staging processing since re-importing will override exisiting metaobject identifiers and thus relationships between metadata objects  
   LEFT OUTER JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL tSec ON tUser.ID = tSec.User_ID AND tMod.ID = tSec.ID  
   LEFT OUTER JOIN mdm.tblEntity tEnt ON tMod.ID = tEnt.Model_ID AND LTRIM(RTRIM(tStage.EntityName)) = tEnt.Name  
   LEFT OUTER JOIN mdm.tblHierarchy tHir ON tEnt.ID = tHir.Entity_ID AND LTRIM(RTRIM(tStage.HierarchyName)) = tHir.Name  
   --LEFT OUTER JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = N'lstAttributeMemberType') tMemberType ON tStage.MemberType_ID = tMemberType.ID  
   LEFT OUTER JOIN (SELECT ID, Name FROM mdm.tblEntityMemberType) tMemberType ON tStage.MemberType_ID = tMemberType.ID  
   LEFT OUTER JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = CAST(N'lstTargetType' AS NVARCHAR(50))) tTargetType ON tStage.TargetType_ID = tTargetType.ID  
  
ORDER BY tStage.ID
GO
