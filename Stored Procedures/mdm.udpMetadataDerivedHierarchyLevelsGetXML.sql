SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMetadataDerivedHierarchyLevelsGetXML]   
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
   @ResultOption = mdm.udfMetadataResultOptionGetByName(T.Criteria.value('DerivedHierarchyLevels[1]', 'nvarchar(50)'))  
FROM @ResultCriteria.nodes('/MetadataResultOptions') T(Criteria)   
  
SET @SearchOption = ISNULL(@SearchOption, 0)  
  
IF @ResultOption = 0  
	SELECT CONVERT(XML,'<ArrayOfDerivedHierarchyLevel/>')  
ELSE  
	SELECT mdm.udfMetadataDerivedHierarchyLevelsGetXML(  
		@User_ID,   
		@SearchCriteria.query('//Models'),   
		@SearchCriteria.query('//DerivedHierarchies'),   
		@SearchCriteria.query('//DerivedHierarchyLevels'),   
		@ResultOption,   
		@SearchOption)  
      FOR XML PATH(''),ELEMENTS XSINIL, ROOT('ArrayOfDerivedHierarchyLevel')  
  
SET NOCOUNT OFF  
END --proc
GO
