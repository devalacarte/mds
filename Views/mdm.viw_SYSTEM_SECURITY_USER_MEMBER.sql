SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_USER_MEMBER]  
/*WITH SCHEMABINDING*/  
AS  
SELECT   
    [User_ID],   
    MIN(tRol.Role_ID) Role_ID,   
    MIN(Privilege_ID) Privilege_ID,   
    [Object_ID],   
    Model_ID,   
    Version_ID,   
    Entity_ID,   
    Hierarchy_ID,   
    HierarchyType_ID,   
    Member_ID,   
    MemberType_ID,  
	tMbr.IsInitialized IsMapped   
FROM   
    mdm.tblSecurityRoleAccessMember tMbr   
    JOIN mdm.viw_SYSTEM_SECURITY_USER_ROLE tRol ON tMbr.Role_ID = tRol.Role_ID  
    LEFT JOIN mdm.tblEntity tEnt ON tMbr.Entity_ID = tEnt.ID  
WHERE  
    (HierarchyType_ID = -1 OR HierarchyType_ID = 0)  
GROUP BY   
	[User_ID],   
    [Object_ID],   
    Model_ID,   
    Version_ID,   
    Entity_ID,   
    Hierarchy_ID,   
    HierarchyType_ID,   
    Member_ID,   
    MemberType_ID,  
	tMbr.IsInitialized  
  
UNION    
SELECT   
    User_ID,   
    MIN(tRol.Role_ID) Role_ID,   
    MIN(Privilege_ID) Privilege_ID,   
    Object_ID,   
    Model_ID,   
    Version_ID,   
    CASE ItemType_ID WHEN 2 THEN Item_ID ELSE Entity_ID END,   
    Hierarchy_ID,   
    HierarchyType_ID,   
    Member_ID,   
    MemberType_ID,  
	tMbr.IsInitialized IsMapped   
FROM   
    mdm.tblSecurityRoleAccessMember tMbr   
    JOIN mdm.viw_SYSTEM_SECURITY_USER_ROLE tRol ON tMbr.Role_ID = tRol.Role_ID  
    LEFT JOIN mdm.tblDerivedHierarchy tHir ON tMbr.Hierarchy_ID = tHir.ID  
WHERE  
    HierarchyType_ID = 1  
GROUP BY   
	User_ID,   
     Object_ID,   
    Model_ID,   
    Version_ID,   
    CASE ItemType_ID WHEN 2 THEN Item_ID ELSE Entity_ID END,   
    Hierarchy_ID,   
    HierarchyType_ID,   
    Member_ID,   
    MemberType_ID,  
	tMbr.IsInitialized
GO
