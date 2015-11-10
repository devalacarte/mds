SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, May 09, 2006  
Function   : mdm.udfAttributeList  
Component  : Security  
Description: mdm.udfAttributeList returns a list of attributes and privileges available for a user (read or update).  
Parameters : User ID, , Entity ID, MemberType_ID, Attribute_ID (optional), AttributeGroup_ID (optional)  
Return     : Table: Attribute information including the privilege  
  
	SELECT * FROM mdm.udfAttributeList(1, NULL, NULL, NULL, NULL)  
	SELECT * FROM mdm.udfAttributeList(1, 31, 1, NULL, NULL)  
	SELECT * FROM mdm.udfAttributeList(18, 28, 1, NULL, 4)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfAttributeList]  
(  
	@User_ID			INT,  
	@Entity_ID			INT = NULL,  
	@MemberType_ID		INT = NULL,  
	@Attribute_ID		INT = NULL,  
	@AttributeGroup_ID	INT = NULL  
)  
RETURNS TABLE   
/*WITH SCHEMABINDING*/  
AS  
RETURN  
SELECT  
	vAtt.Attribute_ID								ID,  
	vAtt.Attribute_MUID								MUID,  
	vAtt.Attribute_Name								AttributeName,  
	vAtt.Attribute_DisplayName						DisplayName,  
	vAtt.Attribute_DisplayName						[Name],  
	vAtt.Attribute_DisplayWidth						DisplayWidth,  
	vAtt.Attribute_Column							ColumnName,  
	vAtt.Attribute_ChangeTrackingGroup				ChangeTrackingGroup,  
	vAtt.Attribute_DBAEntity_ID						DomainEntity_ID,  
	vAtt.Attribute_DBAEntity_MUID					DomainEntity_MUID,  
	vAtt.Attribute_DBAEntity_Name					DomainEntity_Name,  
	vAtt.Attribute_Type_ID							AttributeType_ID,  
	vAtt.Attribute_DataType_ID						DataType_ID,  
	vAtt.Attribute_DataType_Information				DataTypeInformation,  
	vAtt.Attribute_DataMask_ID						InputMask_ID,  
	REPLACE(ISNULL(vAtt.Attribute_DataMask_Name,N''),N'None',N'')	InputMask,  
	mdm.udfEntityHasHierarchy(vAtt.Attribute_DBAEntity_ID) HierarchyInd,  
	vAtt.Attribute_IsSystem,  
	vAtt.Attribute_IsReadOnly,  
	vAtt.Attribute_IsCode,  
	vAtt.Attribute_IsName,  
	vAtt.Model_ID,  
	vAtt.Model_MUID,  
	vAtt.Model_Name,  
	vAtt.Entity_ID,  
	vAtt.Entity_MUID,  
	vAtt.Entity_Name,  
	vAtt.Entity_TableName							EntityTableName,  
	vAtt.Entity_PhysicalTableName					EntityPhysicalTableName,  
    vAtt.Attribute_MemberType_ID					MemberType_ID,  
    vAtt.Attribute_MemberType_Name					MemberType_Name,  
	CASE WHEN @AttributeGroup_ID IS NULL THEN vAtt.Attribute_SortOrder ELSE AGD.SortOrder END AS SortOrder,  
	CASE  
		WHEN (vAtt.Attribute_IsCode = 1 OR vAtt.Attribute_IsName = 1) AND @AttributeGroup_ID IS NOT NULL THEN -1  
		ELSE ISNULL(AGD.ID, 0)  
	END												AttributeGroup_ID,  
	--vAtt.Attribute_DBAEntity_Name					EntityName,	  
	vAttSec.Privilege_ID,  
    vAtt.EnteredUser_ID,  
    vAtt.EnteredUser_MUID,  
    vAtt.EnteredUser_UserName,  
    vAtt.EnteredUser_DTM,  
    vAtt.LastChgUser_ID,  
    vAtt.LastChgUser_MUID,  
    vAtt.LastChgUser_UserName,  
    vAtt.LastChgUser_DTM  
FROM  
	mdm.udfSecurityUserAttributeList(@User_ID, NULL, @Entity_ID, @MemberType_ID) vAttSec  
	INNER JOIN [mdm].[viw_SYSTEM_SCHEMA_ATTRIBUTES] vAtt  
		ON	vAtt.Attribute_ID = vAttSec.ID   
		AND vAttSec.User_ID = @User_ID  
		AND	((@Attribute_ID IS NULL) OR (vAtt.Attribute_ID = @Attribute_ID))  
		AND vAtt.Attribute_Type_ID <> 3 -- System  
	LEFT JOIN mdm.tblAttributeGroupDetail AGD   
		ON	vAtt.Attribute_ID = AGD.Attribute_ID  
		AND AGD.AttributeGroup_ID = @AttributeGroup_ID  
WHERE  
	((AGD.AttributeGroup_ID IS NULL AND @AttributeGroup_ID IS NULL)  
	 OR (AGD.AttributeGroup_ID = @AttributeGroup_ID))  
	OR (vAtt.Attribute_IsCode = 1 OR vAtt.Attribute_IsName = 1)
GO
