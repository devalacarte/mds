SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
SELECT mdm.udfSecurableNameGetByObjectID(8,26)  
  
  
select * from mdm.tblSecurityObject  
select * from mdm.viw_SYSTEM_SCHEMA_MODELS   
select * from mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES  
select * from mdm.viw_SYSTEM_SCHEMA_ATTRIBUTEGROUPS   
SELECT * FROM mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED  
  
*/  
  
CREATE FUNCTION [mdm].[udfSecurableNameGetByObjectID]  
(  
    @Object_ID        INT,  
    @Securable_ID    INT  
)   
RETURNS NVARCHAR(250)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
    DECLARE @SecurableName NVARCHAR(250)  
      
    IF @Object_ID = 1 -- Model  
        SELECT TOP 1 @SecurableName = Model_Label FROM mdm.viw_SYSTEM_SCHEMA_MODELS WHERE Model_ID = @Securable_ID ORDER BY Model_ID  
    ELSE IF @Object_ID = 3 -- Entity  
        SELECT TOP 1 @SecurableName = Entity_Label FROM mdm.viw_SYSTEM_SCHEMA_MODELS WHERE Entity_ID = @Securable_ID ORDER BY Entity_ID  
    ELSE IF @Object_ID = 4 -- Attribute  
        SELECT TOP 1 @SecurableName = Attribute_FullyQualifiedName FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Attribute_ID = @Securable_ID ORDER BY Attribute_ID  
    ELSE IF @Object_ID = 5 -- Attribute Group  
        SELECT TOP 1 @SecurableName = AttributeGroup_FullName FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTEGROUPS_ATTRIBUTES WHERE AttributeGroup_ID = @Securable_ID ORDER BY AttributeGroup_ID  
    ELSE IF @Object_ID = 8 -- Leaf Member Type  
        SELECT TOP 1 @SecurableName = MemberType_Label FROM mdm.viw_SYSTEM_SCHEMA_MODELS WHERE MemberType_ID = 1 AND Entity_ID = @Securable_ID ORDER BY Entity_ID  
    ELSE IF @Object_ID = 9 -- Consolidated Member Type  
        SELECT TOP 1 @SecurableName = MemberType_Label FROM mdm.viw_SYSTEM_SCHEMA_MODELS WHERE MemberType_ID = 2 AND Entity_ID = @Securable_ID ORDER BY Entity_ID  
    ELSE IF @Object_ID = 10 -- Collection Member Type  
        SELECT TOP 1 @SecurableName = MemberType_Label FROM mdm.viw_SYSTEM_SCHEMA_MODELS WHERE MemberType_ID = 3 AND Entity_ID = @Securable_ID ORDER BY Entity_ID  
  
    RETURN @SecurableName         
  
END --fn
GO
