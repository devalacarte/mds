SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Function   : mdm.udfStagingMemberAttributesGet  
Component  : Staging  
Description: mdm.udfStagingMemberAttributesGet returns a list of staging member attributes associated with a user and Model  
Parameters : User ID, Model ID, Status_ID (optional; Null returns all records)  
Return     : Table queried from mdm.viw_SYSTEM_STAGING_MEMBER  
Example 1  : SELECT * FROM mdm.udfStagingMemberAttributesGet(3, 5, 0)    --returns records that have not errored  
Example 2  : SELECT * FROM mdm.udfStagingMemberAttributesGet(1, 1, 0) --returns all records  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfStagingMemberAttributesGet] (  
	@User_ID	INT,   
	@Model_ID	INT,   
	@Status_ID	TINYINT = NULL,  
	@Batch_ID INT = NULL  
)   
RETURNS TABLE   
/*WITH SCHEMABINDING*/  
AS RETURN  
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
        ,Hierarchy_Table  
        ,MemberType_ID  
        ,Member_ID  
        ,Member_Code  
        ,Attribute_ID  
        ,AttributeType_ID  
        ,Attribute_Entity_Table  
        ,Attribute_Name  
        ,Attribute_Column  
        ,Attribute_Value  
        ,Attribute_ChangeTrackingGroup  
        ,Status_ID  
        ,Status_ErrorCode   
	FROM   
		mdm.viw_SYSTEM_STAGING_MEMBER_ATTRIBUTE  
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
