SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataGetSearchCriteriaIds]  
(  
	@SearchCriteria	XML = NULL  
)  
  
RETURNS @Identifiers TABLE (MUID UNIQUEIDENTIFIER, Name NVARCHAR(max), ID INT)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
	INSERT INTO @Identifiers  
	SELECT   
	   CASE T.Identifier.value('Muid[1]', 'nvarchar(max)') WHEN '' THEN NULL WHEN CONVERT(UNIQUEIDENTIFIER, 0x0) THEN NULL ELSE T.Identifier.value('Muid[1]', 'UNIQUEIDENTIFIER') END AS MUID,  
	   CASE T.Identifier.value('Name[1]', 'nvarchar(max)') WHEN '' THEN NULL ELSE T.Identifier.value('Name[1]', 'nvarchar(max)') END AS Name,  
	   CASE T.Identifier.value('Id[1]', 'int') WHEN 0 THEN NULL ELSE T.Identifier.value('Id[1]', 'int') END AS ID  
	FROM @SearchCriteria.nodes('//Identifier') T(Identifier)   
  
	UNION  
  
	SELECT NULL, NULL, NULL  
	WHERE @SearchCriteria.exist('//Identifier') = 0  
  
	RETURN  
END
GO
