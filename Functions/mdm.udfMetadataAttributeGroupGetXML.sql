SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Returns a serialized Entity business entity object.  
  
SELECT mdm.udfMetadataAttributeGroupGetXML(  
	1  
	,null  
	,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
	,'<MemberTypes><MemberType>Leaf</MemberType></MemberTypes>'  
	,null  
	,null  
	,2  
	,0  
)  
  
SELECT mdm.udfMetadataAttributeGroupGetXML(  
	1  
	,null  
	,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
	,'<MemberTypes><MemberType>Consolidated</MemberType></MemberTypes>'  
	,null  
	,null  
	,1  
	,0  
)  
  
SELECT mdm.udfMetadataAttributeGroupGetXML(  
	1  
	,null  
	,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
	,null  
	,null  
	,'<AttributeGroups><Identifier><Muid>108673D9-7BB3-4C03-A31C-FAB65CBCA067</Muid></Identifier></AttributeGroups>'  
	,2  
	,0  
)  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataAttributeGroupGetXML]  
(  
    @User_ID            INT,  
    @ModelIDs           XML = NULL,  
    @EntityIDs          XML = NULL,  
    @MemberTypeIDs      XML = NULL,  
    @AttributeIDs       XML = NULL,  
    @AttributeGroupIDs  XML = NULL,  
    @ResultOption       SMALLINT,  
    @SearchOption       SMALLINT  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
DECLARE @return         XML  
  
IF @ResultOption = 1  
   SELECT @return = mdm.udfMetadataAttributeGroupGetIdentifiersXML(  
                @User_ID,   
                @ModelIDs,   
                @EntityIDs,   
                @MemberTypeIDs,   
                @AttributeIDs,   
                @AttributeGroupIDs,   
                @ResultOption,   
                @SearchOption)  
                  
ELSE IF @ResultOption = 2  
   SELECT @return = mdm.udfMetadataAttributeGroupGetDetailsXML(  
                @User_ID,   
                @ModelIDs,   
                @EntityIDs,   
                @MemberTypeIDs,   
                @AttributeIDs,   
                @AttributeGroupIDs,   
                @ResultOption,   
                @SearchOption)  
     
RETURN @return  
  
END; --function
GO
