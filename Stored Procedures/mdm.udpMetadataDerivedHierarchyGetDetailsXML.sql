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
Returns a serialized DerivedHierarchy business entity object.  
*/  
CREATE PROCEDURE [mdm].[udpMetadataDerivedHierarchyGetDetailsXML]   
(  
    @User_ID            INT,  
    @ModelIDs           XML = NULL,  
    @HierarchyIDs       XML = NULL,  
    @ResultOption       SMALLINT,  
    @SearchOption       SMALLINT,  
    @Return             XML OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	-- SET NOCOUNT ON added to prevent extra result sets from  
	-- interfering with SELECT statements.  
	SET NOCOUNT ON;  
      
    SELECT @Return = mdm.udfMetadataDerivedHierarchiesGetDetailsXML(  
	       @User_ID,   
	       @ModelIDs,   
	       @HierarchyIDs,   
	       @ResultOption,   
	       @SearchOption)  
  
    
	SET NOCOUNT OFF    
	END
GO
