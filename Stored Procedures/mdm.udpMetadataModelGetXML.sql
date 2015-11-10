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
CREATE PROCEDURE [mdm].[udpMetadataModelGetXML]   
(  
	@User_ID        INT,  
	@SearchCriteria XML = NULL,  
	@ResultCriteria XML = NULL  
)  
/*WITH*/  
AS BEGIN  
  
DECLARE @SearchOption		SMALLINT,  
        @ResultOption       SMALLINT,  
        @Return             XML;  
  
SET NOCOUNT ON  
  
/*  
SearchOption  
    UserDefinedObjectsOnly = 0,  
    SystemObjectsOnly = 1  
    BothUserDefinedAndSystemObjects = 2  
  
ResultOption  
	None = 0  
    Identifiers = 1  
    Details = 2  
*/  
  
SELECT   
    @ResultOption = mdm.udfMetadataResultOptionGetByName(T.Criteria.value('Models[1]', 'nvarchar(50)'))  
FROM @ResultCriteria.nodes('/MetadataResultOptions') T(Criteria)   
  
IF @ResultOption = 0  
	SELECT CONVERT(XML,'<ArrayOfModel/>')  
ELSE IF @ResultOption = 1   
    BEGIN  
	    EXEC mdm.udpMetadataModelGetIdentifiersXML   
	        @User_ID,   
	        @SearchCriteria,  
	        @Return OUTPUT;  
    END  
ELSE IF @ResultOption = 2  
    BEGIN  
		EXEC mdm.udpMetadataModelGetDetailsXML   
	        @User_ID,   
	        @SearchCriteria,   
	        @Return OUTPUT;  
	END	    
	  
SELECT @Return    
  FOR XML PATH(''), ELEMENTS XSINIL, ROOT('ArrayOfModel')   
     
SET NOCOUNT OFF  
  
END --proc
GO
