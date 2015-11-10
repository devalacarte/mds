SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Example 1  : SELECT mdm.udfSecurityUserMemberDefault(2, 26, 3, 1) --Returns the default privilege for User ID = 2 and Entity ID = 26 (leaf member)  
Example 2  : SELECT mdm.udfSecurityUserMemberDefault(2, 1020, 4, 1) --Returns the default privilege for User ID = 2 and Attribute ID = 1288 (leaf member)  
Example 3  : SELECT mdm.udfSecurityUserMemberDefault(2, 1, 6, 1) --Returns the default privilege for User ID = 2 and Hierarchy ID = 6  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityUserMemberDefault]  
(  
	@User_ID INT,   
	@Item_ID INT,   
	@Object_ID INT,   
	@MemberType_ID TINYINT,   
	@Privilege_ID INT OUTPUT  
)    
AS    
BEGIN     
  
    --consts for the different object types  
    DECLARE @EntityObjectTypeId             INT = 3,  
            @CollectionObjectTypeId         INT = 11,  
            @AttributeObjectTypeId          INT = 4,  
            @ExplicitHierarchyObjectTypeId  INT = 6;  
  
	IF @Object_ID IN (@EntityObjectTypeId, @CollectionObjectTypeId)   
		BEGIN  
		EXEC [mdm].[udpSecurityUserMemberEntityOrCollection]  
			@User_ID,   
			@Item_ID,   
			@MemberType_ID,   
			@Privilege_ID OUTPUT;  
		END  
	ELSE IF @Object_ID = @AttributeObjectTypeId  
		BEGIN  
		EXEC [mdm].[udpSecurityUserMemberAttribute]  
			@User_ID,   
			@Item_ID,   
			@MemberType_ID,   
			@Privilege_ID OUTPUT;  
		END  
	ELSE IF @Object_ID = @ExplicitHierarchyObjectTypeId  
		BEGIN  
		EXEC [mdm].[udpSecurityUserMemberExplicitHierarchy]  
			@User_ID,   
			@Item_ID,   
			@MemberType_ID,   
			@Privilege_ID OUTPUT;  
		END  
	ELSE  
		BEGIN  
		SET @Privilege_ID = NULL;  
		END  
END
GO
