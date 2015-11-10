SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfBusinessRuleAttributeMemberControllerNameGetByID(32,1)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfBusinessRuleAttributeMemberControllerNameGetByID]  
(  
	@Entity_ID	INT,  
	@EntityType_ID	TINYINT  
)   
RETURNS sysname  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @ControllerName sysname,  
			@ModelID INT;  
  
	SELECT @ModelID = Model_ID FROM mdm.tblEntity WHERE ID = @Entity_ID;  
  
	SELECT @ControllerName = CAST(N'udp_SYSTEM_' +   
			CONVERT(NVARCHAR(10), @ModelID) + N'_' +  
			CONVERT(NVARCHAR(10), @Entity_ID) + N'_' +  
			ViewSuffix +   
			N'_ProcessRules' AS sysname)  
	FROM mdm.tblEntityMemberType WHERE ID = @EntityType_ID;  
  
	RETURN @ControllerName;  
END --fn
GO
