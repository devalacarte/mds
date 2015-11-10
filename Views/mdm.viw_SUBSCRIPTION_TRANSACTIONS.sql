SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SUBSCRIPTION_TRANSACTIONS]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
   DV.[Name]                  AS VersionName,   
   DV.Display_ID              AS VersionNumber,  
   CASE WHEN VF.Name IS NULL THEN  N'' ELSE VF.Name END VersionFlag,  
   DV.Description             AS VersionDescription,  
   TT.Description             AS TransactionType,  
   CASE WHEN H.Name IS NULL THEN N'' ELSE H.Name END Hierarchy,  
   D.[Name]                   AS Model,  
   E.Name                     AS DomainAttribute,  
   CASE WHEN A.DisplayName IS NULL THEN N'' ELSE A.DisplayName END Attribute,    
   T.MemberCode,  
   --L.ListOption               AS MemberType,  
   L.Name						AS MemberType,  
   T.OldCode                  AS PriorValue,  
   T.NewCode                  AS NewValue,  
   T.EnterDTM                 AS [DateTime],  
   CASE WHEN U.UserName IS NULL THEN N'' ELSE U.UserName END UserName  
FROM  
   mdm.tblTransaction T  
   LEFT JOIN mdm.tblTransactionType TT ON T.TransactionType_ID = TT.ID  
   LEFT JOIN mdm.tblHierarchy H ON T.Hierarchy_ID = H.ID  
   INNER JOIN mdm.tblEntity E ON T.Entity_ID = E.ID  
   INNER JOIN mdm.tblModel D ON E.Model_ID = D.ID  
   INNER JOIN mdm.tblModelVersion DV ON T.Version_ID = DV.ID  
   LEFT JOIN mdm.tblAttribute A ON T.Attribute_ID = A.ID  
  -- LEFT JOIN mdm.tblList L ON T.MemberType_ID = L.OptionID  
  --    AND L.ListCode = N'lstAttributeMemberType'  
	LEFT JOIN mdm.tblEntityMemberType L ON T.MemberType_ID = L.ID  
   LEFT JOIN mdm.tblUser U ON T.EnterUserID = U.ID  
   LEFT OUTER JOIN mdm.tblModelVersionFlag VF ON DV.VersionFlag_ID = VF.ID
GO
