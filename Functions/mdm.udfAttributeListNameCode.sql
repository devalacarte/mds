SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Tuesday, May 09, 2006  
Function   : mdm.udfAttributeListNameCode  
Component  : Security  
Description: mdm.udfAttributeListNameCode returns name and/or code attributes and an 'unspecified' privilege_id  
             if the name and/or code attributes do not have any permissions.  
Parameters : User ID, , Entity ID, MemberType_ID, Attribute_ID (optional), AttributeGroup_ID (optional)  
Return     : Table: Attribute information including the privilege  
  
	SELECT * FROM mdm.udfAttributeListNameCode(121, 1, 1)  
	SELECT * FROM mdm.udfAttributeListNameCode(1, 31, 1)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfAttributeListNameCode]  
(  
	@User_ID			INT,  
	@Entity_ID			INT,  
	@MemberType_ID		INT  
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
	vAtt.Attribute_Column							ColumnName,  
	vAtt.Attribute_DisplayWidth						DisplayWidth,  
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
	vAtt.Attribute_SortOrder						SortOrder,  
	-1												AttributeGroup_ID,  
	99												Privilege_ID,  
    vAtt.EnteredUser_ID,  
    vAtt.EnteredUser_MUID,  
    vAtt.EnteredUser_UserName,  
    vAtt.EnteredUser_DTM,  
    vAtt.LastChgUser_ID,  
    vAtt.LastChgUser_MUID,  
    vAtt.LastChgUser_UserName,  
    vAtt.LastChgUser_DTM  
FROM  
	mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES AS vAtt  
LEFT JOIN (  
	SELECT vAttSec.ID   
	FROM mdm.udfSecurityUserAttributeList(@User_ID, NULL, @Entity_ID, @MemberType_ID) AS vAttSec   
	INNER JOIN mdm.tblAttribute AS tAtt   
		ON tAtt.ID = vAttSec.ID	AND	(tAtt.IsCode = 1 OR tAtt.IsName = 1)  
	) AS x ON vAtt.Attribute_ID = x.ID  
WHERE  
	vAtt.Entity_ID = @Entity_ID  
AND	vAtt.Attribute_MemberType_ID = @MemberType_ID  
AND	(vAtt.Attribute_IsCode = 1 OR vAtt.Attribute_IsName = 1)  
AND x.ID IS NULL
GO
