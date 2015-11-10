SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpEntitiesGetByValidationProcessSeq 1  
EXEC mdm.udpEntitiesGetByValidationProcessSeq 1, 1  
EXEC mdm.udpEntitiesGetByValidationProcessSeq 5  
EXEC mdm.udpEntitiesGetByValidationProcessSeq 6  
EXEC mdm.udpEntitiesGetByValidationProcessSeq NULL, 29  
EXEC mdm.udpEntitiesGetByValidationProcessSeq 6, 29  
EXEC mdm.udpEntitiesGetByValidationProcessSeq 6, 26  
EXEC mdm.udpEntitiesGetByValidationProcessSeq 7  
EXEC mdm.udpEntitiesGetByValidationProcessSeq 7, 33  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpEntitiesGetByValidationProcessSeq]  
(  
	@Model_ID	INT = NULL,  
	@Entity_ID			INT = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
	  
    SELECT   
         ent.Model_ID  
        ,ent.Entity_ID  
        ,ent.Name  
        ,ent.MemberType_ID  
        ,aih.ParentAttributeName AS AttributeName  
        ,aih.ParentAttributeColumnName AS AttributeColumnName  
        ,aih.ChildEntityID  
        ,aih.ChildEntityName  
        ,aih.ChildAttributeName  
        ,aih.ChildAttributeColumnName  
        ,ent.[Level]  
    FROM   
        mdm.udfEntityDependencyTree(@Model_ID, @Entity_ID) AS ent left join  
        mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY AS aih  
            ON ent.Entity_ID = aih.ParentEntityID  
            AND ent.MemberType_ID = aih.Attribute_MemberType_ID  
    WHERE  
        ent.MemberType_ID = 1 OR ent.MemberType_ID = 2 -- Only leaf and consolidated member types have business rules.  
    ORDER BY ent.[Level]  
  
	SET NOCOUNT OFF  
END --proc
GO
