SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT mdm.udfMetadataSearchOptionGetByName('UserDefinedObjectsOnly')  
SELECT mdm.udfMetadataSearchOptionGetByName('SystemObjectsOnly')  
SELECT mdm.udfMetadataSearchOptionGetByName('BothUserDefinedAndSystemObjects')  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
  
CREATE FUNCTION [mdm].[udfMetadataSearchOptionGetByName]  
(  
   @SearchOptionName  NVARCHAR(50)  
)   
RETURNS SMALLINT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
   DECLARE @SearchOption SMALLINT   
     
   SELECT @SearchOption = CASE @SearchOptionName   
                        WHEN 'UserDefinedObjectsOnly' THEN 0  
                        WHEN 'SystemObjectsOnly' THEN 1   
                        WHEN 'BothUserDefinedAndSystemObjects' THEN 2  
                       END   
     
   RETURN @SearchOption   
    
END --fn
GO
