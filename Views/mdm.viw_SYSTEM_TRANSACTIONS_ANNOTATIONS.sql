SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_TRANSACTIONS_ANNOTATIONS]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
	TA.ID,  
	T.ID AS [Transaction ID],  
	CASE WHEN TA.Comment IS NULL THEN N'' ELSE TA.Comment END AS [User Comment],  
	CASE WHEN TA.EnterDTM IS NULL THEN N'' ELSE TA.EnterDTM END as [Date Time],  
	U.UserName as [User Name],  
	U.ID AS [User ID],  
	U.MUID as [User_MUID],  
	CASE WHEN TA.LastChgDTM IS NULL THEN N'' ELSE TA.LastChgDTM END as [LastChgDateTime],  
	U2.UserName as [LastChgUserName],  
	U2.ID AS [LastChgUserID],  
	U2.MUID as [LastChgUserMUID]  
FROM  
	[mdm].[tblTransactionAnnotation] TA  
		INNER JOIN [mdm].[tblTransaction] T ON TA.Transaction_ID = T.ID  
		LEFT JOIN [mdm].[tblUser] U ON TA.EnterUserID = U.ID  
		LEFT JOIN [mdm].[tblUser] U2 ON TA.LastChgUserID = U2.ID
GO
