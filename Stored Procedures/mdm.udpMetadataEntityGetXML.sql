SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMetadataEntityGetXML]   
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
        @EntityIDs          XML,  
        @HierarchyIDs       XML,  
        @AttributeIDs       XML,  
        @AttributeGroupIDs  XML,  
        @MemberTypeIDs      XML,  
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
   @ResultOption = mdm.udfMetadataResultOptionGetByName(T.Criteria.value('Entities[1]', 'nvarchar(50)'))  
FROM @ResultCriteria.nodes('/MetadataResultOptions') T(Criteria)   
  
SET @SearchOption = COALESCE(@SearchOption, 0)  
  
SELECT @ModelIDs = @SearchCriteria.query('//Models');  
SELECT @EntityIDs = @SearchCriteria.query('//Entities');  
SELECT @HierarchyIDs = @SearchCriteria.query('//ExplicitHierarchies');  
SELECT @AttributeIDs = @SearchCriteria.query('//Attributes');  
SELECT @AttributeGroupIDs = @SearchCriteria.query('//AttributeGroups');  
SELECT @MemberTypeIDs = @SearchCriteria.query('//MemberTypes');  
  
IF @ResultOption = 0  
	SELECT CONVERT(XML,'<ArrayOfEntity/>')  
ELSE IF @ResultOption = 1  
    BEGIN  
        EXEC mdm.udpMetadataEntityGetIdentifiersXML  
		    @User_ID,   
		    @ModelIDs,   
		    @EntityIDs,   
		    @HierarchyIDs,   
		    @MemberTypeIDs,   
		    @AttributeIDs,   
		    @AttributeGroupIDs,   
		    @ResultOption,   
		    @SearchOption,  
		    @Result OUTPUT;  
    END  
ELSE IF @ResultOption = 2  
    BEGIN  
	    EXEC mdm.udpMetadataEntityGetDetailsXML  
		    @User_ID,   
		    @ModelIDs,   
		    @EntityIDs,   
		    @HierarchyIDs,   
		    @MemberTypeIDs,   
		    @AttributeIDs,   
		    @AttributeGroupIDs,   
		    @ResultOption,   
		    @SearchOption,  
		    @Result OUTPUT;  
    END  
      
SELECT @Result  
  FOR XML PATH(''), ELEMENTS XSINIL, ROOT('ArrayOfEntity')  
  
SET NOCOUNT OFF  
  
END --proc
GO
