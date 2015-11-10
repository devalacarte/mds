SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT * FROM MDM.viw_SYSTEM_STAGING_MEMBER  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_STAGING_MEMBER]  
/*WITH SCHEMABINDING*/  
AS  
SELECT TOP 100 PERCENT  
   tStage.Batch_ID                                          Batch_ID,  
   tStage.ID                                                Stage_ID,  
   tUser.ID                                                 [User_ID],  
   LTRIM(RTRIM(tStage.UserName))                            [User_Name],  
   ISNULL(tMod.ID, 0)                                       Model_ID,  
   LTRIM(RTRIM(tStage.ModelName))                           Model_Name,  
   tSec.IsAdministrator                                     IsAdministrator,  
   ISNULL(tEnt.ID, 0)                                       Entity_ID,  
   LTRIM(RTRIM(tStage.EntityName))                          Entity_Name,  
   mdm.udfTableNameGetByID(tEnt.ID, tStage.MemberType_ID)   Entity_Table,  
   CASE tEnt.IsFlat WHEN 0 THEN 1   
   ELSE 0 END                                               Entity_HasHierarchy ,   
   tHir.ID                                                  Hierarchy_ID,  
   LTRIM(RTRIM(tStage.HierarchyName))                       Hierarchy_Name,  
   tHir.IsMandatory                                         Hierarchy_IsMandatory,  
   tEnt.HierarchyTable                                      Hierarchy_Table,  
   tEnt.CollectionTable                                     Collection_Table,  
   tStage.MemberType_ID                                     MemberType_ID,  
   tMemberType.Name                                         MemberType_Name,  
   LTRIM(RTRIM(tStage.MemberCode))                          Member_Code,  
   CASE  
    WHEN LTRIM(RTRIM(tStage.MemberName)) IS NULL THEN SPACE(0)  
    WHEN LEN(LTRIM(RTRIM(tStage.MemberName))) = 0 THEN SPACE(0)  
    ELSE LTRIM(RTRIM(tStage.MemberName))  
    END                                                     Member_Name,  
   CASE  
    WHEN tStage.Status_ID = 1 THEN 1  
    WHEN tUser.ID IS NULL AND LEN(LTRIM(RTRIM(tStage.UserName))) > 0 THEN 2   
    WHEN tMod.ID IS NULL THEN 2 --Model is required  
    WHEN tSec.IsAdministrator = 0 THEN 2 --Model administrator privileges are required to stage into the selected Model  
    WHEN tEnt.ID IS NULL THEN 2 --Entity is required  
    WHEN tEnt.IsSystem = 1 THEN 2  
    WHEN tHir.ID IS NULL AND tStage.MemberType_ID = 2 THEN 2 --Hierarchy is required for consolidation members  
    WHEN tStage.MemberType_ID = 3 AND LEN(tEnt.HierarchyTable) = 0 THEN 2 --Collections may only be staged to entities that possess a hierarchy  
    WHEN mdm.udfItemReservedWordCheck(12, LTRIM(RTRIM(MemberCode))) = 1 THEN 2 --May not use an MDS reserved word  
    WHEN (LEN(LTRIM(RTRIM(MemberCode))) = 0) AND (mdm.udfBusinessRuleHasGenerateCodeItem(1, MemberType_ID, tEnt.ID) = 0) THEN 2 --Code is required if not generating a business rule  
    WHEN (tStage.MemberType_ID <> 1 AND tStage.MemberType_ID <> 2 AND tStage.MemberType_ID <> 3) THEN 2  
    WHEN tStage.Status_ID = 2 THEN 2   
    ELSE 0  
   END                                                      Status_ID ,  
   CASE  
    WHEN tUser.ID IS NULL AND LEN(LTRIM(RTRIM(tStage.UserName))) > 0 THEN N'210017' -- Error - user name is invalid  
    WHEN tMod.ID IS NULL THEN N'210018' -- Error - Model is required or invalid Model  
    WHEN tSec.IsAdministrator = 0 THEN N'210019' -- Error - Model administrator privileges are required to stage into the selected Model  
    WHEN tEnt.ID IS NULL THEN N'210020' -- Error - entity is required or invalid entity  
    WHEN tEnt.IsSystem = 1 THEN N'210056' -- Error - You cannot update system entities.  
    WHEN tHir.ID IS NULL AND tStage.MemberType_ID = 2 THEN N'210032' -- Error - hierarchy is required or invalid hierarchy  
    WHEN tStage.MemberType_ID = 3 AND LEN(tEnt.HierarchyTable) = 0 THEN N'210033' -- Error - collections may only be staged to entities that have a hierarchy  
    WHEN mdm.udfItemReservedWordCheck(12, LTRIM(RTRIM(MemberCode))) = 1 THEN N'210034' --Error - selected MemberCode is a reserved word. Please select another code.  
    WHEN (LEN(LTRIM(RTRIM(MemberCode))) = 0) AND (mdm.udfBusinessRuleHasGenerateCodeItem(1, MemberType_ID, tEnt.ID) = 0) THEN N'210035' -- Error - code is required without a code generation business rule  
    WHEN (LEN(LTRIM(RTRIM(MemberCode))) > 0) AND (mdm.udfBusinessRuleHasGenerateCodeItem(1, MemberType_ID, tEnt.ID) = 1) THEN N'210036' -- Information - code is not required for a code generation business rule  
    WHEN (tStage.MemberType_ID <> 1 AND tStage.MemberType_ID <> 2 AND tStage.MemberType_ID <> 3) THEN N'210037' -- Error - member type ID must be 1 (leaf member), 2 (parent member), or 3 (collection)  
    WHEN tStage.Status_ID = 2 THEN tStage.ErrorCode  
    ELSE N''  
    END                                                     Status_ErrorCode  
FROM   
mdm.tblStgMember tStage  
LEFT OUTER JOIN mdm.tblUser tUser   
    ON LTRIM(RTRIM(tStage.UserName)) = tUser.UserName AND tUser.Status_ID=1  
LEFT OUTER JOIN mdm.tblModel tMod   
    ON LTRIM(RTRIM(tStage.ModelName)) = tMod.Name   
LEFT OUTER JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL tSec   
    ON tUser.ID = tSec.User_ID AND tMod.ID = tSec.ID  
LEFT OUTER JOIN mdm.tblEntity tEnt   
    ON tMod.ID = tEnt.Model_ID AND LTRIM(RTRIM(tStage.EntityName)) = tEnt.Name  
LEFT OUTER JOIN mdm.tblHierarchy tHir   
    ON tEnt.ID = tHir.Entity_ID AND LTRIM(RTRIM(tStage.HierarchyName)) = tHir.Name  
LEFT OUTER JOIN (SELECT ID, Name FROM mdm.tblEntityMemberType) tMemberType   
    ON tStage.MemberType_ID = tMemberType.ID  
ORDER BY tStage.ID
GO
