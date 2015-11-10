SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMetadataDerivedHierarchyGetXML]  
(  
	@User_ID        INT,  
	@SearchCriteria XML = NULL,  
	@ResultCriteria XML = NULL  
)  
/*WITH*/  
AS BEGIN  
  
SET NOCOUNT ON  
  
DECLARE @SearchOption       SMALLINT,  
        @ResultOption       SMALLINT,  
        @ModelIDs           XML,  
        @HierarchyIDs       XML,  
        @Result             XML;  
  
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
   @ResultOption = mdm.udfMetadataResultOptionGetByName(T.Criteria.value('DerivedHierarchies[1]', 'nvarchar(50)'))  
FROM @ResultCriteria.nodes('/MetadataResultOptions') T(Criteria)   
  
SET @SearchOption = COALESCE(@SearchOption, 0)  
  
SELECT @ModelIDs = @SearchCriteria.query('//Models');  
SELECT @HierarchyIDs = @SearchCriteria.query('//DerivedHierarchies');  
  
IF @ResultOption = 0  
	SELECT CONVERT(XML,'<ArrayOfDerivedHierarchy/>')  
ELSE IF @ResultOption = 1  
    BEGIN  
        EXEC mdm.udpMetadataDerivedHierarchyGetIdentifiersXML  
		    @User_ID,   
		    @ModelIDs,   
		    @HierarchyIDs,   
		    @ResultOption,   
		    @SearchOption,  
		    @Result OUTPUT;  
    END  
ELSE IF @ResultOption = 2  
    BEGIN  
        EXEC mdm.udpMetadataDerivedHierarchyGetDetailsXML  
		    @User_ID,   
		    @ModelIDs,   
		    @HierarchyIDs,   
		    @ResultOption,   
		    @SearchOption,  
		    @Result OUTPUT;  
    END  
		  
SELECT @Result  
    FOR XML PATH(''),ELEMENTS XSINIL, ROOT('ArrayOfDerivedHierarchy')  
  
SET NOCOUNT OFF  
END --proc
GO
