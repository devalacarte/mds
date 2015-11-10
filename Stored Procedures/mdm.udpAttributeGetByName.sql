SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	EXEC mdm.udpAttributeGetByName 1,'Code',23,1;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpAttributeGetByName]  
(  
	@User_ID		INT,  
	@Name			NVARCHAR(50),  
	@Entity_ID		INT,  
	@MemberType_ID	INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	SELECT  
		vAtt.Attribute_ID								ID,  
		vAtt.Attribute_Name								AttributeName,  
		vAtt.Attribute_DisplayName						DisplayName,  
		vAtt.Attribute_DisplayWidth						DisplayWidth,  
		vAtt.Attribute_ChangeTrackingGroup				ChangeTrackingGroup,  
		vAtt.Attribute_DBAEntity_ID						DomainEntity_ID,  
		vAtt.Attribute_Type_ID							AttributeType_ID,  
		vAtt.Attribute_DataType_ID						DataType_ID,  
		vAtt.Attribute_DataType_Information				DataTypeInformation,  
		REPLACE(vAtt.Attribute_DataMask_Name,N'None',N'')	InputMask,  
		vAtt.Attribute_DataMask_ID						InputMask_ID,  
		mdm.udfEntityHasHierarchy(vAtt.Attribute_DBAEntity_ID) HierarchyInd,  
		vAtt.Model_ID									Model_ID,  
		vAtt.Entity_ID									Entity_ID,  
		vAtt.Entity_Name								EntityName,  
		vAtt.Entity_TableName							EntityTableName,  
		vAtt.Attribute_SortOrder						SortOrder,  
		vAttSec.Privilege_ID							Privilege_ID  
	FROM  
		mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES AS vAtt  
		INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTE AS vAttSec  
			ON	vAtt.Attribute_ID = vAttSec.ID   
			AND vAttSec.[User_ID] = @User_ID  
			AND	vAtt.Attribute_Name = @Name  
			AND	vAtt.Entity_ID = @Entity_ID  
			AND vAtt.Attribute_MemberType_ID = @MemberType_ID;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
