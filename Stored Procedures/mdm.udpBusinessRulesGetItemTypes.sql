SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
  
CREATE PROCEDURE [mdm].[udpBusinessRulesGetItemTypes]   
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    SELECT  
        ID Id,  
        [Description],  
        PropertyDelimiter Delimiter  
    FROM mdm.tblBRItemType  
  
    SET NOCOUNT OFF  
END --proc
GO
