SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_ISSUE_VALIDATION]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
    tAll.ID,     
    M.ID [Model_ID],    
    M.MUID [Model_MUID],    
    M.Name [Model_Name],    
    tAll.Version_ID,    
    V.MUID [Version_MUID],    
    V.Name [Version_Name],    
    tAll.Hierarchy_ID,    
    H.MUID [Hierarchy_MUID],    
    H.Name [Hierarchy_Name],    
    tAll.Entity_ID,    
    E.MUID [Entity_MUID],    
    E.Name [Entity_Name],    
    tAll.MemberType_ID,    
    tAll.Member_ID,    
    tAll.MemberCode,    
    BR.RuleConditionText [Description],  
    tAll.BRBusinessRule_ID,    
    BR.MUID [BRBusinessRule_MUID],    
    BR.Name [BRBusinessRule_Name],    
    tAll.BRItem_ID,    
    BRI.MUID [BRItem_MUID],       
    BRI.ItemText [BRItem_Name],    
    tAll.EnterDTM,     
    U1.ID [EnterUserID],     
    U1.MUID [EnterUserMUID] ,    
    U1.UserName [EnterUserName],     
    tAll.LastChgDTM	[LastChgDTM],     
    U2.ID [LastChgUserID],     
    U2.MUID [LastChgUse_MUID],      
    U2.UserName [LastChgUserName],     
    tAll.NotificationStatus_ID  
FROM  
   mdm.tblValidationLog tAll  
   INNER JOIN  
   (  
   SELECT  
      Version_ID,  
      Hierarchy_ID,  
      Entity_ID,  
      Member_ID,  
      MemberType_ID,  
      BRBusinessRule_ID,  
      BRItem_ID,  
      MAX(LastChgDTM) LastUpdated  
   FROM  
      mdm.tblValidationLog  
   GROUP BY  
      Version_ID,  
      Hierarchy_ID,  
      Entity_ID,  
      Member_ID,  
      MemberType_ID,  
      BRBusinessRule_ID,  
      BRItem_ID  
   ) tDistinct ON   
         tAll.Version_ID = tDistinct.Version_ID AND  
         tAll.Hierarchy_ID = tDistinct.Hierarchy_ID AND  
         tAll.Entity_ID = tDistinct.Entity_ID AND  
         tAll.Member_ID = tDistinct.Member_ID AND  
         tAll.MemberType_ID = tDistinct.MemberType_ID AND  
         tAll.BRBusinessRule_ID = tDistinct.BRBusinessRule_ID AND  
         tAll.BRItem_ID = tDistinct.BRItem_ID AND  
         tAll.LastChgDTM = tDistinct.LastUpdated AND  
     tAll.Status_ID = 1  
    LEFT JOIN mdm.tblBRBusinessRule BR ON BR.ID = tAll.BRBusinessRule_ID     
    LEFT JOIN mdm.tblBRItem BRI ON BRI.ID = tAll.BRItem_ID       
    LEFT JOIN mdm.tblModelVersion V ON V.ID = tAll.Version_ID      
    LEFT JOIN mdm.tblModel M ON M.ID = V.Model_ID      
    LEFT JOIN mdm.tblUser U1 ON U1.ID =  tAll.EnterUserID      
    LEFT JOIN mdm.tblUser U2 ON U2.ID =  tAll.LastChgUserID      
    LEFT JOIN mdm.tblEntity E ON E.ID = tAll.Entity_ID       
    LEFT JOIN mdm.tblHierarchy H ON H.ID = tAll.Hierarchy_ID
GO
