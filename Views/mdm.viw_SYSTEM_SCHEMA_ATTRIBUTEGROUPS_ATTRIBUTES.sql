SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*   
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTEGROUPS_ATTRIBUTES  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_ATTRIBUTEGROUPS_ATTRIBUTES]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
   tMod.ID              Model_ID,  
   tMod.Name            Model_Name,  
   tMod.MUID            Model_MUID,  
   tEnt.ID              Entity_ID,   
   tEnt.Name            Entity_Name,   
   tEnt.MUID            Entity_MUID,  
   tGrp.ID              AttributeGroup_ID,  
   tGrp.Name            AttributeGroup_Name,  
   tGrp.MUID            AttributeGroup_MUID,  
   AttributeGroup_FullName = tMod.Name + N':' + tEnt.Name + N':' + tGrpType.Name + N':' + tGrp.Name,  
   tGrp.MemberType_ID   AttributeGroupType_ID,  
   tGrpType.Name        AttributeGroupType_Name,  
   tAtt.ID              Attribute_ID,  
   tAtt.Name            Attribute_Name,  
   tAtt.MUID            Attribute_MUID,  
   tAtt.DisplayName     Attribute_DisplayName,  
   tMemberType.ID       AttributeMemberType_ID,  
   tMemberType.Name     AttributeMemberType_Name,  
   tAttributeType.ID    AttributeType_ID,  
   tAttributeType.Name  AttributeType_Name,  
   tDet.SortOrder	    Attribute_SortOrder,  
   --  
   tGrp.IsSystem					 AttributeGroup_IsSystem,  
   tGrp.EnterUserID                  AttributeGroup_UserIDCreated,   
   AttributeGroup_UserNameCreated =  (SELECT UserName FROM mdm.tblUser WHERE ID = tGrp.EnterUserID) ,   
   tGrp.EnterDTM                     AttributeGroup_DateCreated,   
   tGrp.LastChgUserID                AttributeGroup_UserIDUpdated,   
   AttributeGroup_UserNameUpdated =  (SELECT UserName FROM mdm.tblUser WHERE ID = tGrp.LastChgUserID) ,   
   tGrp.LastChgDTM                   AttributeGroup_DateUpdated  
FROM  
   mdm.tblEntity tEnt  
   JOIN mdm.tblAttributeGroup tGrp ON tEnt.ID = tGrp.Entity_ID  
   LEFT JOIN mdm.tblAttributeGroupDetail tDet ON tGrp.ID = tDet.AttributeGroup_ID   
   LEFT JOIN mdm.tblAttribute tAtt ON tDet.Attribute_ID = tAtt.ID   
  -- LEFT JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = N'lstAttributeMemberType') tGrpType  
      LEFT JOIN (SELECT CAST(ID AS INT) ID, Name FROM mdm.tblEntityMemberType)tGrpType  
      ON tGrp.MemberType_ID = tGrpType.ID  
   --LEFT JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = N'lstAttributeMemberType') tMemberType  
     LEFT JOIN (SELECT CAST(ID AS INT) ID, Name FROM mdm.tblEntityMemberType)tMemberType  
      ON tAtt.MemberType_ID = tMemberType.ID  
   --LEFT JOIN (SELECT OptionID ID, ListOption Name FROM mdm.tblList WHERE ListCode = N'lstAttributeType') tAttributeType  
    LEFT JOIN (SELECT CAST(ID AS INT) ID, Name FROM mdm.tblEntityMemberType) tAttributeType  
      ON tAtt.AttributeType_ID = tAttributeType.ID  
   LEFT JOIN mdm.tblModel tMod   
      ON tEnt.Model_ID = tMod.ID
GO
