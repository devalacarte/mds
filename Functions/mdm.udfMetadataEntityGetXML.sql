SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Returns a serialized Entity business entity object.  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataEntityGetXML]  
(  
    @User_ID			INT,  
	@ModelIDs			XML = NULL,  
	@EntityIDs			XML = NULL,  
	@HierarchyIDs		XML = NULL,  
	@MemberTypeIDs		XML = NULL,  
	@AttributeIDs		XML = NULL,  
	@AttributeGroupIDs	XML = NULL,  
    @ResultOption		SMALLINT,  
    @SearchOption		SMALLINT  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @return XML  
  
	IF @ResultOption = 1  
	   SELECT @return = mdm.udfMetadataEntityGetIdentifiersXML(	     
	        @User_ID,   
	        @ModelIDs,   
	        @EntityIDs,   
	        @HierarchyIDs,   
	        @MemberTypeIDs,   
	        @AttributeIDs,   
	        @AttributeGroupIDs,   
	        @ResultOption,   
	        @SearchOption)  
	ELSE   
	IF @ResultOption = 2  
	   SELECT @return = mdm.udfMetadataEntityGetDetailsXML(  
	       @User_ID,   
	       @ModelIDs,   
	       @EntityIDs,   
	       @HierarchyIDs,   
	       @MemberTypeIDs,   
	       @AttributeIDs,   
	       @AttributeGroupIDs,   
	       @ResultOption,   
	       @SearchOption)  
  
	RETURN @return;  
END; --function
GO
