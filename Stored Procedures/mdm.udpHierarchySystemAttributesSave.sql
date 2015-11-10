SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, June 06, 2006  
Procedure  : mdm.udpHierarchySystemAttributesSave  
Component  : Validation, Staging  
Description: mdm.udpHierarchySystemAttributesSave recalculates the level number, sort order, and index code for each member relationship in a hierarchy within a version  
Parameters : Version ID, Hierarchy ID  
Return     : N/A  
  
Example    : EXEC mdm.udpHierarchySystemAttributesSave 30, 27  
  
*/  
  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpHierarchySystemAttributesSave]   
(  
	@Version_ID INT,   
	@Hierarchy_ID INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
	--Calculate level numbers for the hierarchy  
	EXEC mdm.udpHierarchyMemberLevelSave @Version_ID, @Hierarchy_ID, 0, 2  
  
	--Recalibrate sort orders for the hierarchy   
	EXEC mdm.udpHierarchySortOrderSave @Version_ID, @Hierarchy_ID  
  
	--Recalculate index codes for the hierarchy   
	--EXEC mdm.udpHierarchyIndexCodeSave @Version_ID, @Hierarchy_ID  
  
	SET NOCOUNT OFF;  
END --proc
GO
