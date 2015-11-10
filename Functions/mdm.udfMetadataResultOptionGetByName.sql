SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT mdm.udfMetadataResultOptionGetByName('None')  
SELECT mdm.udfMetadataResultOptionGetByName('Identifiers')  
SELECT mdm.udfMetadataResultOptionGetByName('Details')  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
  
CREATE FUNCTION [mdm].[udfMetadataResultOptionGetByName]  
(  
   @ResultOptionName  NVARCHAR(50)  
)   
RETURNS SMALLINT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
   DECLARE @ResultOption SMALLINT   
     
   SELECT @ResultOption = CASE @ResultOptionName   
                        WHEN 'Identifiers' THEN 1   
                        WHEN 'Details' THEN 2   
                        ELSE 0  
                       END   
     
   RETURN @ResultOption   
    
END --fn
GO
