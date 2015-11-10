SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_BUSINESSRULES]  
/*WITH SCHEMABINDING*/  
AS  
SELECT   
   tMod.ID					Model_ID,  
   tMod.MUID				Model_MUID,  
   tMod.Name				Model_Name,  
   tEnt.ID					Entity_ID,  
   tEnt.MUID				Entity_MUID,  
   tEnt.Name				Entity_Name,  
   tBR.ID					BusinessRule_ID,  
   tBR.MUID					BusinessRule_MUID,  
   tBR.Name					BusinessRule_Name,  
   tBR.Description			BusinessRule_Description,  
   tBR.RuleConditionText	BusinessRule_RuleConditionText,  
   tBR.RuleConditionSQL	    BusinessRule_RuleConditionSql,  
   tBR.RuleActionText		BusinessRule_RuleActionText,  
   tBR.Status_ID			BusinessRule_StatusID,  
   tStatus.Name				BusinessRule_StatusName,  
   tBR.Priority 			BusinessRule_Priority,  
   ng.ID                    BusinessRule_NotificationGroupID,  
   ng.MUID                  BusinessRule_NotificationGroupMUID,  
   ng.Name                  BusinessRule_NotificationGroupName,  
   nu.ID                    BusinessRule_NotificationUserID,  
   nu.MUID                  BusinessRule_NotificationUserMUID,  
   nu.UserName              BusinessRule_NotificationUserName,  
   lr.Parent_ID             BusinessRule_TypeID,  
   p.ListOption				BusinessRule_TypeName,  
   tMemberType.ID			BusinessRule_SubTypeID,  
   tMemberType.Name			BusinessRule_SubTypeName,  
   cu.ID                    BusinessRule_CreatedUserID,   
   cu.MUID                  BusinessRule_CreatedUserMUID,  
   cu.UserName              BusinessRule_CreatedUserName,  
   tBR.EnterDTM             BusinessRule_DateCreated,       
   uu.ID                    BusinessRule_UpdatedUserID,   
   uu.MUID                  BusinessRule_UpdatedUserMUID,  
   uu.UserName              BusinessRule_UpdatedUserName,  
   tBR.LastChgDTM           BusinessRule_DateUpdated  
FROM  
    mdm.tblBRBusinessRule tBR  
    JOIN mdm.tblListRelationship lr   
        ON tBR.ForeignType_ID = lr.ID  
    JOIN mdm.tblList p   
        ON   
            p.OptionID = lr.Parent_ID AND   
            p.ListCode = lr.ParentListCode  
    JOIN mdm.tblEntity tEnt  
        ON tBR.Foreign_ID = tEnt.ID  
    JOIN (SELECT ID, [Name] FROM mdm.tblEntityMemberType) tMemberType  
        ON tBR.ForeignType_ID = tMemberType.ID  
    JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = CAST(N'lstBRStatus' AS NVARCHAR(50))) tStatus  
        ON tBR.Status_ID = tStatus.ID  
    JOIN mdm.tblModel tMod   
        ON tEnt.Model_ID = tMod.ID  
    LEFT JOIN mdm.tblUserGroup ng  
        ON   
            tBR.NotificationGroupID IS NOT NULL AND   
            tBR.NotificationGroupID = ng.ID  
    LEFT JOIN mdm.tblUser nu  
        ON   
            tBR.NotificationUserID IS NOT NULL AND   
            tBR.NotificationUserID = nu.ID             
    LEFT JOIN mdm.tblUser cu  
        ON tBR.EnterUserID = cu.ID             
    LEFT JOIN mdm.tblUser uu  
        ON tBR.LastChgUserID = uu.ID
GO
