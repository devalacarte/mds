SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Function   : mdm.udfStagingMembersGet  
Component  : Staging  
Description: mdm.udfStagingMembersGet returns a list of staging members associated with a user and Model  
Parameters : User ID, Model ID, Status_ID (optional; Null returns all records)  
Return     : Table queried from mdm.viw_SYSTEM_STAGING_MEMBER  
Example 1  : SELECT * FROM mdm.udfStagingMembersGet(1, 2, 0)    --returns records that have not errored  
Example 2  : SELECT * FROM mdm.udfStagingMembersGet(1, 2, NULL,null) --returns all records  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfStagingMembersGet] (@User_ID INT, @Model_ID INT, @Status_ID TINYINT = NULL,@Batch_ID INT = NULL)   
RETURNS TABLE   
/*WITH SCHEMABINDING*/  
AS  
RETURN  
  
SELECT   
     Batch_ID  
    ,Stage_ID  
    ,[User_ID]  
    ,[User_Name]  
    ,Model_ID  
    ,Model_Name  
    ,IsAdministrator  
    ,Entity_ID  
    ,Entity_Name  
    ,Entity_Table  
    ,Entity_HasHierarchy  
    ,Hierarchy_ID  
    ,Hierarchy_Name  
    ,Hierarchy_IsMandatory  
    ,Hierarchy_Table  
    ,Collection_Table  
    ,MemberType_ID  
    ,MemberType_Name  
    ,Member_Code  
    ,Member_Name  
    ,Status_ID  
    ,Status_ErrorCode   
FROM   
    mdm.viw_SYSTEM_STAGING_MEMBER   
WHERE   
    Model_ID  = @Model_ID   
    AND   
    (  
		([User_ID] IS NULL) OR   
		(@User_ID IS NOT NULL AND [User_ID] IS NOT NULL AND [User_ID] = @User_ID)  
	)  
	AND   
	(  
		(@Status_ID IS NULL) OR  
		(@Status_ID IS NOT NULL AND [Status_ID] = @Status_ID)  
	)  
	AND   
	(  
		(@Batch_ID IS NULL) OR  
		(@Batch_ID IS NOT NULL AND ((Batch_ID IS NULL AND @Batch_ID = 0) OR (Batch_ID IS NOT NULL AND Batch_ID = @Batch_ID)))  
	)  
;
GO
