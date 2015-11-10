SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
View       : mdm.viw_SYSTEM_SECURITY_TRANSACTION  
Component  : Security  
Description: mdm.viw_SYSTEM_SECURITY_TRANSACTION returns a list of transactions that need to be applied to the hierarchy map table.  
             The list is retricted to those that   
                a) are not free-form attributes and   
                b) those that have not already been mapped  
             Set attribute value and move member to parent affect security hierarchy maps.  New members (create transaction) is addressed via the   
             move member to parent (a transaction generated immediately after a member is created).  
Results  
-------  
ID                  : Transaction ID  
Version_ID          : Model version ID  
TransactionType_ID  : Transaction type ID  
Hierarchy_ID        : Hierarchy ID (present if a member move occurs)  
HierarchyType_ID    : Hierarchy type ID (0 if a member move occurs)  
BaseEntity_ID       : Entity ID of hierarchy or member  
Attribute_ID        : Attribute ID (present if a set attribute value occurs)  
DomainEntity_ID     : Entity ID of the attribute  
MemberType_ID       : Member type  
Member_ID           : Member ID  
AncestorMember_ID   : New member parent or attribute value  
OldValue            : Original member parent or attribute value  
MemberLevelSecured  : Level number of the member (NULL indicates that it is not secured)  
AncestorLevelSecured: Level number of the member's ancestor (NULL indicates that it is not secured)  
  
SELECT * FROM mdm.viw_SYSTEM_SECURITY_TRANSACTION ORDER BY ID  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SECURITY_TRANSACTION]  
/*WITH SCHEMABINDING*/  
AS  
WITH MAXID AS  
(SELECT MAX(ID) ID FROM mdm.tblTransaction WHERE IsMapped = 0 GROUP BY Version_ID, Hierarchy_ID, Entity_ID, Attribute_ID, MemberType_ID, Member_ID  
)  
  
SELECT  
    tTran.ID,  
    tTran.Version_ID,  
    TransactionType_ID = CASE tTran.TransactionType_ID WHEN 5 THEN 4 ELSE tTran.TransactionType_ID END,  
    tTran.Hierarchy_ID,  
    HierarchyType_ID = CASE WHEN tTran.Hierarchy_ID IS NULL THEN 1 ELSE 0 END,  
    tTran.Entity_ID,  
    tTran.MemberType_ID,  
    tTran.Member_ID,  
	tTran.Entity_ID AncestorEntity_ID,  
    AncestorMemberType_ID = CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END,  
    CONVERT(INT, tTran.NewValue) AncestorMember_ID,  
    CONVERT(INT, tTran.OldValue) OldValue--,  
    --MemberLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, tTran.Entity_ID, tTran.Hierarchy_ID, CASE WHEN tTran.Hierarchy_ID IS NOT NULL THEN 0 ELSE NULL END, tTran.MemberType_ID, tTran.Member_ID, 0),  
    --AncestorLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, tTran.Entity_ID, tTran.Hierarchy_ID, CASE WHEN tTran.Hierarchy_ID IS NOT NULL THEN 0 ELSE NULL END, CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END, CONVERT(INT, tTran.NewValue), 1),  
	--WasAncestorLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, tTran.Entity_ID, tTran.Hierarchy_ID, CASE WHEN tTran.Hierarchy_ID IS NOT NULL THEN 0 ELSE NULL END, CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END, CONVERT(INT, tTran.OldValue), 1)  
FROM  
    mdm.tblTransaction tTran  
    JOIN MAXID tList ON tTran.ID = tList.ID  
    LEFT JOIN mdm.tblAttribute tAttr ON tTran.Attribute_ID = tAttr.ID  
WHERE  
    (TransactionType_ID = 4 OR TransactionType_ID = 5)  
    AND (tTran.MemberType_ID = 1 AND tTran.MemberType_ID = 2)  
    AND IsMapped = 0  
  
UNION ALL  
  
SELECT  
    tTran.ID,  
    tTran.Version_ID,  
    TransactionType_ID = CASE tTran.TransactionType_ID WHEN 5 THEN 4 ELSE tTran.TransactionType_ID END,  
    tTran.Hierarchy_ID,  
    HierarchyType_ID = CASE WHEN tTran.Hierarchy_ID IS NULL THEN 1 ELSE 0 END,  
    tTran.Entity_ID,  
    tTran.MemberType_ID,  
    tTran.Member_ID,  
    ISNULL(tAttr.DomainEntity_ID, tTran.Entity_ID) AncestorEntity_ID,  
    AncestorMemberType_ID = CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END,  
    CONVERT(INT, tTran.NewValue) AncestorMember_ID,  
    CONVERT(INT, tTran.OldValue) OldValue--,  
    --MemberLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, tTran.Entity_ID, tTran.Hierarchy_ID, CASE WHEN tTran.Hierarchy_ID IS NOT NULL THEN 0 ELSE NULL END, tTran.MemberType_ID, tTran.Member_ID, 0),  
    --AncestorLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, ISNULL(tAttr.DomainEntity_ID, tTran.Entity_ID), tTran.Hierarchy_ID, CASE WHEN tTran.Hierarchy_ID IS NOT NULL THEN 0 ELSE NULL END, CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END, CONVERT(INT, tTran.NewValue), 1),  
	--WasAncestorLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, ISNULL(tAttr.DomainEntity_ID, tTran.Entity_ID), tTran.Hierarchy_ID, CASE WHEN tTran.Hierarchy_ID IS NOT NULL THEN 0 ELSE NULL END, CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END, CONVERT(INT, tTran.OldValue), 1)  
FROM  
    mdm.tblTransaction tTran  
    JOIN MAXID tList ON tTran.ID = tList.ID  
    INNER JOIN mdm.tblAttribute tAttr ON tTran.Attribute_ID = tAttr.ID and tAttr.AttributeType_ID = 2  
WHERE  
    TransactionType_ID = 3  
    AND (tTran.MemberType_ID = 1 OR tTran.MemberType_ID = 2)  
    AND IsMapped = 0  
  
UNION ALL  
  
SELECT  
    tTran.ID,  
    tTran.Version_ID,  
    TransactionType_ID = CASE tTran.TransactionType_ID WHEN 5 THEN 4 ELSE tTran.TransactionType_ID END,  
    SHD.Hierarchy_ID,  
    HierarchyType_ID = 1,  
    tTran.Entity_ID,  
    tTran.MemberType_ID,  
    tTran.Member_ID,  
    tTran.Entity_ID AncestorEntity_ID,  
    AncestorMemberType_ID = CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END,  
    CONVERT(INT, tTran.NewValue) AncestorMember_ID,  
    CONVERT(INT, tTran.OldValue) OldValue--,  
    --MemberLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, tTran.Entity_ID, SHD.Hierarchy_ID, 1, tTran.MemberType_ID, tTran.Member_ID, 0),  
    --AncestorLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, tTran.Entity_ID, SHD.Hierarchy_ID, 1, CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END, CONVERT(INT, tTran.NewValue), 1),  
	--WasAncestorLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, tTran.Entity_ID, SHD.Hierarchy_ID, 1, CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END, CONVERT(INT, tTran.OldValue), 1)  
FROM  
    mdm.tblTransaction tTran  
    JOIN MAXID tList ON tTran.ID = tList.ID  
	INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS SHD ON SHD.Foreign_ID = tTran.Hierarchy_ID  
		AND SHD.Object_ID = 6  
WHERE  
    (TransactionType_ID = 4 OR TransactionType_ID = 5)  
    AND (tTran.MemberType_ID = 1 OR tTran.MemberType_ID = 2)  
    AND IsMapped = 0  
  
UNION ALL  
  
SELECT  
    tTran.ID,  
    tTran.Version_ID,  
    TransactionType_ID = CASE tTran.TransactionType_ID WHEN 5 THEN 4 ELSE tTran.TransactionType_ID END,  
    SHD.Hierarchy_ID,  
    HierarchyType_ID = 1,  
    tTran.Entity_ID,  
    tTran.MemberType_ID,  
    tTran.Member_ID,  
    ISNULL(tAttr.DomainEntity_ID, tTran.Entity_ID) AncestorEntity_ID,  
    AncestorMemberType_ID = CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END,  
    CONVERT(INT, tTran.NewValue) AncestorMember_ID,  
    CONVERT(INT, tTran.OldValue) OldValue--,  
    --MemberLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, tTran.Entity_ID, SHD.Hierarchy_ID, 1, tTran.MemberType_ID, tTran.Member_ID, 0),  
    --AncestorLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, ISNULL(tAttr.DomainEntity_ID, tTran.Entity_ID), SHD.Hierarchy_ID, 1, CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END, CONVERT(INT, tTran.NewValue), 1),  
    --WasAncestorLevelSecured = mdm.udfLevelMemberSecured(tTran.Version_ID, ISNULL(tAttr.DomainEntity_ID, tTran.Entity_ID), SHD.Hierarchy_ID, 1, CASE tTran.TransactionType_ID WHEN 3 THEN 1 ELSE 2 END, CONVERT(INT, tTran.OldValue), 1)  
FROM  
    mdm.tblTransaction tTran  
    JOIN MAXID tList ON tTran.ID = tList.ID  
    INNER JOIN mdm.tblAttribute tAttr ON tTran.Attribute_ID = tAttr.ID AND tAttr.AttributeType_ID = 2  
	INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS SHD ON SHD.Foreign_ID = tTran.Hierarchy_ID  
		AND SHD.Object_ID = 6  
WHERE   
    TransactionType_ID = 3  
    AND (tTran.MemberType_ID = 1 OR tTran.MemberType_ID = 2)  
    AND IsMapped = 0  
;
GO
