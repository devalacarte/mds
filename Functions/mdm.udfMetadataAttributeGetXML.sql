SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Returns a serialized MetadataAttribute business entity object.  
  
SELECT mdm.udfMetadataAttributeGetXML(  
	2  
	,null  
	,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
	,'<MemberTypes><MemberType>Leaf</MemberType></MemberTypes>'  
	,null  
	,null  
	,1  
	,0  
)  
  
	,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
  
SELECT mdm.udfMetadataAttributeGetXML(  
	1  
	,'<Models><Identifier><Name>Product</Name></Identifier></Models>'  
	,'<Entities><Identifier><Name>Product</Name></Identifier></Entities>'  
	,null  
	,null  
	,'<AttributeGroups><Identifier><Muid>FACE96DE-00F8-4368-B375-B9095D90DA02</Muid></Identifier></AttributeGroups>'  
	,1  
	,0  
)  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataAttributeGetXML]  
(  
        @User_ID            INT,  
        @ModelIDs           XML = NULL,  
        @EntityIDs          XML = NULL,  
        @MemberTypeIDs      XML = NULL,  
        @AttributeIDs       XML = NULL,  
        @AttributeGroupID   XML = NULL,  
        @ResultOption       SMALLINT,  
        @SearchOption       SMALLINT  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
DECLARE @return         XML  
  
IF @ResultOption = 1  
   SELECT @return = mdm.udfMetadataAttributeGetIdentifiersXML(  
                @User_ID,   
                @ModelIDs,   
                @EntityIDs,   
                @MemberTypeIDs,  
                @AttributeIDs,  
                @AttributeGroupID,  
                @ResultOption,  
                @SearchOption)  
ELSE IF @ResultOption = 2  
   SELECT @return = mdm.udfMetadataAttributeGetDetailsXML(  
                @User_ID,   
                @ModelIDs,   
                @EntityIDs,   
                @MemberTypeIDs,  
                @AttributeIDs,  
                @AttributeGroupID,  
                @ResultOption,  
                @SearchOption)  
  
RETURN @return  
  
END; --function
GO
