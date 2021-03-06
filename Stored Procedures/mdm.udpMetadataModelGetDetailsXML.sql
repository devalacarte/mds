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
Returns a serialized Model business entity object.  
*/  
CREATE PROCEDURE [mdm].[udpMetadataModelGetDetailsXML]   
(  
	@User_ID            INT,   
	@SearchCriteria     XML=NULL,  
	@return             XML OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	-- SET NOCOUNT ON added to prevent extra result sets from  
	-- interfering with SELECT statements.  
	SET NOCOUNT ON;  
      
    SELECT @return = mdm.udfMetadataModelGetDetailsXML(  
        @User_ID,  
        @SearchCriteria)  
  
    
	SET NOCOUNT OFF    
	END
GO
