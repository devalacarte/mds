SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    SELECT * FROM mdm.viw_SYSTEM_USER_VALIDATION  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_USER_VALIDATION]  
/*WITH SCHEMABINDING*/  
AS  
SELECT   
    tLog.ID                                 ValidationIssue_ID,  
    tLog.Version_ID                         Version_ID,  
    tLog.Version_Name                       VersionName,  
    tLog.Model_ID                           Model_ID,  
    tLog.Model_Name                         ModelName,  
    tLog.Entity_ID                          Entity_ID,  
    tLog.Entity_Name                        EntityName,  
    tLog.Hierarchy_ID                       Hierarchy_ID,  
    ISNULL(tLog.Hierarchy_Name, N'')        HierarchyName,  
    tLog.Member_ID                          Member_ID,      
    tLog.MemberCode                         MemberCode,  
    tLog.MemberType_ID                      MemberType_ID,  
    tType.Name                              MemberType,  
    tLog.Description                        ConditionText,  
    tLog.BRItem_Name                        ActionText,  
    tLog.BRBusinessRule_ID                  BusinessRuleID,  
    tLog.BRBusinessRule_Name                BusinessRuleName,  
    N''                                     PriorityRank,  
    CASE WHEN vBR.BusinessRule_NotificationGroupID IS NULL THEN vBR.BusinessRule_NotificationUserID ELSE ugu.[User_ID] END [User_ID],  
    CASE WHEN vBR.BusinessRule_NotificationGroupID IS NULL THEN vBR.BusinessRule_NotificationUserName ELSE ugu.[User_Name] END [UserName],  
    tLog.LastChgUserID                      LastChgUserID,  
    tLog.LastChgDTM                         DateCreated,  
    CAST(NULL AS DATETIME2(3))              DateDue,  
    tLog.NotificationStatus_ID              NotificationStatus_ID,  
    tNotify.Name                            NotificationStatus,  
    tRule.Property_Value                    Property_Value  
FROM  
    mdm.viw_SYSTEM_ISSUE_VALIDATION tLog  
    LEFT JOIN mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES tRule   
        ON    tLog.BRBusinessRule_ID = tRule.BusinessRule_ID  
        AND   tLog.BRItem_ID = tRule.Item_ID  
    LEFT JOIN mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES vBR   
        ON vBR.BusinessRule_ID = tRule.BusinessRule_ID  
    LEFT JOIN mdm.tblEntityMemberType tType  
        ON tLog.MemberType_ID = tType.ID  
    LEFT JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListName = N'NotificationStatus') tNotify  
        ON tLog.NotificationStatus_ID = tNotify.ID  
    LEFT JOIN mdm.viw_SYSTEM_USERGROUP_USERS ugu  
        ON vBR.BusinessRule_NotificationGroupID = ugu.UserGroup_ID
GO
