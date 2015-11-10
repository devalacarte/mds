SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMetadataExplicitHierarchyGetXML]   
(  
	@User_ID        INT,  
	@SearchCriteria XML = NULL,  
	@ResultCriteria XML = NULL  
)  
/*WITH*/  
AS BEGIN  
  
SET NOCOUNT ON  
  
DECLARE @SearchOption SMALLINT  
DECLARE @ResultOption SMALLINT  
  
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
   @SearchOption = mdm.udfMetadataSearchOptionGetByName(T.Criteria.value('SearchOption[1]', 'nvarchar(50)'))  
FROM @SearchCriteria.nodes('/MetadataSearchCriteria') T(Criteria)   
  
SELECT   
   @ResultOption = mdm.udfMetadataResultOptionGetByName(T.Criteria.value('ExplicitHierarchies[1]', 'nvarchar(50)'))  
FROM @ResultCriteria.nodes('/MetadataResultOptions') T(Criteria)   
  
SET @SearchOption = COALESCE(@SearchOption, 0)  
  
IF @ResultOption = 0  
	SELECT CONVERT(XML,'<ArrayOfExplicitHierarchy/>')  
ELSE  
	SELECT mdm.udfMetadataExplicitHierarchiesGetXML(  
		@User_ID,   
		@SearchCriteria.query('//Models'),   
		@SearchCriteria.query('//Entities'),   
		@SearchCriteria.query('//ExplicitHierarchies'),   
		@ResultOption,   
		@SearchOption)  
      FOR XML PATH(''), ELEMENTS XSINIL, ROOT('ArrayOfExplicitHierarchy')  
  
SET NOCOUNT OFF  
END --proc
GO
