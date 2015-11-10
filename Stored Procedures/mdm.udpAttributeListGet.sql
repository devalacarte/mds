SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	EXEC mdm.udpAttributeListGet 1, 7, 1;  
	EXEC mdm.udpAttributeListGet 18, 15, 1;  
	EXEC mdm.udpAttributeListGet 18, 16, 1;	  
	EXEC mdm.udpAttributeListGet 1, 23, 2;	  
	EXEC mdm.udpAttributeListGet 1, 23, 1, 825;  
	EXEC mdm.udpAttributeListGet 1, 23, 1,null,1 -- Supply Chain  
	EXEC mdm.udpAttributeListGet 1, 23, 1,null,2 -- Inventory  
	EXEC mdm.udpAttributeListGet 1, 23, 1,null,3 -- Packaging  
	EXEC mdm.udpAttributeListGet 1, 28, 1,null,4 -- System  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpAttributeListGet]  
(  
	@User_ID			INT,  
	@Entity_ID			INT,  
	@MemberType_ID		INT,  
	@Attribute_ID		INT = NULL,  
	@AttributeGroup_ID	INT = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @tblDBASec TABLE (Entity_ID INT, Privilege_ID INT);  
  
	INSERT INTO @tblDBASec   
	SELECT ID, Privilege_ID   
	FROM mdm.viw_SYSTEM_SECURITY_USER_ENTITY   
	WHERE [User_ID] = @User_ID;  
  
	SELECT	  
		vAtt.ID  
        ,vAtt.MUID  
        ,vAtt.AttributeName  
        ,vAtt.DisplayName  
        ,vAtt.Name  
        ,vAtt.DisplayWidth  
        ,vAtt.DomainEntity_ID  
        ,vAtt.DomainEntity_MUID  
        ,vAtt.DomainEntity_Name  
        ,vAtt.AttributeType_ID  
        ,vAtt.DataType_ID  
        ,vAtt.DataTypeInformation  
        ,vAtt.InputMask_ID  
        ,vAtt.InputMask  
        ,vAtt.HierarchyInd  
        ,vAtt.Attribute_IsSystem  
        ,vAtt.Attribute_IsReadOnly  
        ,vAtt.Attribute_IsCode  
        ,vAtt.Attribute_IsName  
        ,vAtt.Model_ID  
        ,vAtt.Model_MUID  
        ,vAtt.Model_Name  
        ,vAtt.Entity_ID  
        ,vAtt.Entity_MUID  
        ,vAtt.Entity_Name  
        ,vAtt.EntityTableName  
        ,vAtt.EntityPhysicalTableName  
        ,vAtt.MemberType_ID  
        ,vAtt.MemberType_Name  
        ,vAtt.SortOrder  
        ,vAtt.AttributeGroup_ID  
        ,vAtt.Privilege_ID  
        ,vAtt.EnteredUser_ID  
        ,vAtt.EnteredUser_MUID  
        ,vAtt.EnteredUser_UserName  
        ,vAtt.EnteredUser_DTM  
        ,vAtt.LastChgUser_ID  
        ,vAtt.LastChgUser_MUID  
        ,vAtt.LastChgUser_UserName  
        ,vAtt.LastChgUser_DTM  
		,ISNULL(DBASec.Privilege_ID, 1) AS DomainEntity_Privilege_ID  
	FROM	  
		mdm.udfAttributeList(@User_ID, @Entity_ID, @MemberType_ID, @Attribute_ID, @AttributeGroup_ID) AS vAtt  
	LEFT JOIN @tblDBASec AS DBASec   
		ON vAtt.DomainEntity_ID = DBASec.Entity_ID  
  
	UNION  
  
	SELECT	  
		vAtt.ID  
        ,vAtt.MUID  
        ,vAtt.AttributeName  
        ,vAtt.DisplayName  
        ,vAtt.Name  
        ,vAtt.DisplayWidth  
        ,vAtt.DomainEntity_ID  
        ,vAtt.DomainEntity_MUID  
        ,vAtt.DomainEntity_Name  
        ,vAtt.AttributeType_ID  
        ,vAtt.DataType_ID  
        ,vAtt.DataTypeInformation  
        ,vAtt.InputMask_ID  
        ,vAtt.InputMask  
        ,vAtt.HierarchyInd  
        ,vAtt.Attribute_IsSystem  
        ,vAtt.Attribute_IsReadOnly  
        ,vAtt.Attribute_IsCode  
        ,vAtt.Attribute_IsName  
        ,vAtt.Model_ID  
        ,vAtt.Model_MUID  
        ,vAtt.Model_Name  
        ,vAtt.Entity_ID  
        ,vAtt.Entity_MUID  
        ,vAtt.Entity_Name  
        ,vAtt.EntityTableName  
        ,vAtt.EntityPhysicalTableName  
        ,vAtt.MemberType_ID  
        ,vAtt.MemberType_Name  
        ,vAtt.SortOrder  
        ,vAtt.AttributeGroup_ID  
        ,vAtt.Privilege_ID  
        ,vAtt.EnteredUser_ID  
        ,vAtt.EnteredUser_MUID  
        ,vAtt.EnteredUser_UserName  
        ,vAtt.EnteredUser_DTM  
        ,vAtt.LastChgUser_ID  
        ,vAtt.LastChgUser_MUID  
        ,vAtt.LastChgUser_UserName  
        ,vAtt.LastChgUser_DTM  
		,ISNULL(DBASec.Privilege_ID,1) DomainEntity_Privilege_ID  
	FROM   
		mdm.udfAttributeListNameCode(@User_ID, @Entity_ID, @MemberType_ID) AS vAtt  
	LEFT JOIN @tblDBASec DBASec   
		ON vAtt.DomainEntity_ID = DBASec.Entity_ID   
  
	ORDER BY SortOrder;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
