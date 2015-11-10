SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
/*  
Returns a serialized Entity business entity object with just Identifiers.  
*/  
CREATE PROCEDURE [mdm].[udpMetadataEntityGetIdentifiersXML]   
(  
    @User_ID            INT,   
    @ModelIDs           XML = NULL,  
    @EntityIDs          XML = NULL,  
    @HierarchyIDs       XML = NULL,  
    @MemberTypeIDs      XML = NULL,  
    @AttributeIDs       XML = NULL,  
    @AttributeGroupIDs  XML = NULL,  
    @ResultOption       SMALLINT,  
    @SearchOption       SMALLINT,  
    @Return             XML OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	-- SET NOCOUNT ON added to prevent extra result sets from  
	-- interfering with SELECT statements.  
	SET NOCOUNT ON;  
      
    SELECT @Return = mdm.udfMetadataEntityGetIdentifiersXML(	     
	        @User_ID,   
	        @ModelIDs,   
	        @EntityIDs,   
	        @HierarchyIDs,   
	        @MemberTypeIDs,   
	        @AttributeIDs,   
	        @AttributeGroupIDs,   
	        @ResultOption,   
	        @SearchOption)     
      
END
GO
