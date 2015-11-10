SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataGetSearchCriteriaMemberTypes]  
(  
	@SearchCriteria	XML = NULL  
)  
RETURNS @MemberTypes TABLE (ID int, Name nvarchar(50))  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
	INSERT INTO @MemberTypes  
	SELECT   
		mt.ID,  
		mt.Name		  
	FROM @SearchCriteria.nodes('//MemberType') T(Identifier)   
	INNER JOIN mdm.tblEntityMemberType mt  
		ON mt.Name = T.Identifier.value('.', 'nvarchar(50)')  
  
	UNION  
  
	SELECT NULL, NULL  
	WHERE @SearchCriteria.exist('//MemberType') = 0  
  
	RETURN  
END
GO
