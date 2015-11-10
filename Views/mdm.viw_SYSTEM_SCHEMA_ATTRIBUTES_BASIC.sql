SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC WHERE Entity_ID = 23  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC WHERE Entity_ID = 23 AND Attribute_MemberType_ID = 1  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC WHERE Entity_ID = 23 AND Attribute_Name = 'Weight'  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC WHERE Attribute_ID = 1067  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_ATTRIBUTES_BASIC]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
   tMod.ID				Model_ID,   
   tMod.MUID		    Model_MUID,      
   tMod.Name			Model_Name,  
   tEnt.ID				Entity_ID,   
   tEnt.MUID            Entity_MUID,  
   tEnt.Name			Entity_Name,   
   tAtt.ID				Attribute_ID,  
   tAtt.MUID            Attribute_MUID,  
   tAtt.Name			Attribute_Name,  
   tAtt.MemberType_ID	Attribute_MemberType_ID,  
   CASE tDBAEnt.ID WHEN NULL THEN 0 ELSE tDBAEnt.ID END Attribute_DBAEntity_ID,     
   tDBAEnt.MUID         Attribute_DBAEntity_MUID,  
   tDBAEnt.Name         Attribute_DBAEntity_Name   
FROM  
   mdm.tblModel tMod   
   INNER JOIN mdm.tblEntity tEnt ON tMod.ID = tEnt.Model_ID   
   INNER JOIN mdm.tblAttribute tAtt ON tEnt.ID = tAtt.Entity_ID   
   LEFT OUTER JOIN mdm.tblEntity tDBAEnt ON tAtt.DomainEntity_ID = tDBAEnt.ID
GO
