SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_ISSUE_NOTIFICATION]  
/*WITH SCHEMABINDING*/  
AS  
SELECT   
    ValidationIssue_ID,  
    Version_ID,  
    VersionName,  
    Model_ID,  
    ModelName,  
    Entity_ID,  
    EntityName,  
    Hierarchy_ID,  
    HierarchyName,  
    MemberCode,  
    Member_ID,  
    MemberType_ID,  
    MemberType,  
    ConditionText,  
    ActionText,  
    BusinessRuleID,  
    BusinessRuleName,  
    PriorityRank,  
    User_ID,  
    UserName,  
    DateCreated,  
    DateDue  
FROM  
    mdm.viw_SYSTEM_USER_VALIDATION  
WHERE  
    NotificationStatus_ID = 0
GO
