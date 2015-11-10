SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*    
==============================================================================    
 Copyright (c) Microsoft Corporation. All Rights Reserved.    
==============================================================================    
  
Returns a list of business rule IDs available to the given user. A rule is excluded if    
the user cannot see one or more of the attributes referenced by the rule.    
    
    SELECT * FROM mdm.udfSecurityUserBusinessRuleList(2,31,1);    
    
    -- Gets rules for all Entities and MemberTypes.    
    SELECT * FROM mdm.udfSecurityUserBusinessRuleList(2, NULL, NULL);    
*/    
CREATE FUNCTION [mdm].[udfSecurityUserBusinessRuleList]    
(    
    @User_ID INT,       
    @Entity_ID INT = NULL,       
    @MemberType_ID TINYINT = NULL      
)    
RETURNS @tblBusinessRuleIdList TABLE     
(    
    BusinessRule_ID INT PRIMARY KEY CLUSTERED    
)    
AS BEGIN    
    -- Get all business rules for the specified Entity and MemberType.    
    INSERT INTO @tblBusinessRuleIdList (BusinessRule_ID)    
    SELECT      
        DISTINCT br.BusinessRule_ID    
    FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES br    
    WHERE     
        ((@Entity_ID IS NULL) OR (br.Entity_ID = @Entity_ID)) AND    
        ((@MemberType_ID IS NULL) OR (br.BusinessRule_SubTypeID = @MemberType_ID));    
    
  
    -- Determine if the user does not have access to any attributes referenced in the business rules.  These BR need to be excluded.    
      
    -- Get all attributes referenced by the BRs    
    DECLARE @BusinessRulesWithDenyAttributes TABLE (BusinessRule_ID INT, Item_ID INT, Attribute_ID INT, Attribute_Entity_ID INT, Attribute_MemberType_ID TINYINT);    
    INSERT INTO @BusinessRulesWithDenyAttributes (BusinessRule_ID, Item_ID, Attribute_ID, Attribute_Entity_ID, Attribute_MemberType_ID)    
    SELECT      
        brAtt.BusinessRule_ID, brAtt.Item_ID, brAtt.Attribute_ID, brAtt.Attribute_Entity_ID, brAtt.Attribute_MemberType_ID  
    FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES_ATTRIBUTES brAtt    
    INNER JOIN @tblBusinessRuleIdList br ON br.BusinessRule_ID = brAtt.BusinessRule_ID   
  
    -- Get a list of all unique Entity-MemberType pairs.  
    DECLARE @tblEntityMemberTypes TABLE  
    (  
        RowNumber INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,  
        Attribute_Entity_ID INT,  
        Attribute_MemberType_ID TINYINT  
    )  
    INSERT INTO @tblEntityMemberTypes(Attribute_Entity_ID, Attribute_MemberType_ID)  
    SELECT DISTINCT  
        Attribute_Entity_ID,  
        Attribute_MemberType_ID   
    FROM   
        @BusinessRulesWithDenyAttributes    
  
    -- Loop through each Entity-MemberType, and remove from @BusinessRulesWithDenyAttributes those attributes which the user  
    -- can see. Those left over are not visible to the user.  
    DECLARE @Counter INT = 1,  
            @MaxCount INT = (SELECT MAX(RowNumber) FROM @tblEntityMemberTypes),  
            @Attribute_Entity_ID INT,  
            @Attribute_MemberType_ID TINYINT;       
    WHILE (@Counter <= @MaxCount)  
    BEGIN  
        -- Get the current Entity-MemberType IDs.  
        SELECT   
            @Attribute_Entity_ID = Attribute_Entity_ID,  
            @Attribute_MemberType_ID = Attribute_MemberType_ID  
        FROM   
            @tblEntityMemberTypes  
        WHERE RowNumber = @Counter;  
          
        -- Delete rows for the attributes that the user can see.  
        DELETE FROM @BusinessRulesWithDenyAttributes   
        WHERE   
            Attribute_Entity_ID = @Attribute_Entity_ID AND  
            Attribute_MemberType_ID = @Attribute_MemberType_ID AND  
            Attribute_ID IN (SELECT ID FROM mdm.udfSecurityUserAttributeList(@User_ID, NULL, @Attribute_Entity_ID, @Attribute_MemberType_ID));  
          
        SET @Counter += 1;              
    END                 
  
    -- Remove from the results the rules that contain denied attributes.    
    DELETE FROM @tblBusinessRuleIdList     
    WHERE BusinessRule_ID IN (SELECT DISTINCT BusinessRule_ID FROM @BusinessRulesWithDenyAttributes)    
  
    RETURN;    
END
GO
