SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_TRANSACTIONS]  
/*WITH SCHEMABINDING*/  
AS  
SELECT    
    T.ID,    
    M.ID as Model_ID,    
    M.Name as Model_Name,    
    M.MUID as Model_MUID,    
    MV.ID as Version_ID,    
    MV.Name as Version_Name,    
    MV.MUID as Version_MUID,    
    TT.ID as TransactionType_ID,    
    TT.Description as Type,    
    CASE WHEN H.Name IS NULL THEN N'' ELSE H.Name END [Explicit Hierarchy],    
    H.ID as [ExplicitHierarchy_ID],    
    H.MUID as [ExplicitHierarchy_MUID],    
    CASE WHEN E.Name IS NULL THEN N'' ELSE E.Name END as Entity,    
    E.ID as Entity_ID,    
    E.MUID as Entity_MUID,    
    CASE WHEN A.Name IS NULL THEN N'' ELSE A.Name END as Attribute,        
    A.ID as Attribute_ID,        
    A.MUID as Attribute_MUID,        
    T.Member_ID as [Member_ID],    
    CASE WHEN T.MemberCode IS NULL THEN N'' ELSE T.MemberCode END as [Member Code],    
    CASE WHEN L.Name  IS NULL THEN N'' ELSE L.Name END as [Member Type],    
    CASE WHEN T.OldCode IS NULL THEN N'' ELSE T.OldCode END as [Prior Value],    
    CASE WHEN T.NewCode IS NULL THEN N'' ELSE T.NewCode END as [New Value],    
    CASE WHEN T.EnterDTM IS NULL THEN N'' ELSE T.EnterDTM END as [Date Time],    
    U.UserName as [User Name],    
    U.ID AS [User ID],    
    U.MUID as [User_MUID]    
FROM  
                mdm.tblTransaction T    
    LEFT JOIN   mdm.tblModelVersion MV ON T.Version_ID = MV.ID    
    LEFT JOIN   mdm.tblModel M ON M.ID = MV.Model_ID    
    LEFT JOIN   mdm.tblTransactionType TT ON T.TransactionType_ID = TT.ID    
    LEFT JOIN   mdm.tblHierarchy H ON T.Hierarchy_ID = H.ID    
    LEFT JOIN   mdm.tblEntity E ON T.Entity_ID = E.ID    
    LEFT JOIN   mdm.tblAttribute A ON T.Attribute_ID = A.ID    
    LEFT JOIN   mdm.tblEntityMemberType L ON T.MemberType_ID = L.ID    
    LEFT JOIN   mdm.tblUser U ON T.EnterUserID = U.ID
GO
