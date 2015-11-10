SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfGetHighestDBVersion()  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfGetLatestDBUpgradeVersion]()   
RETURNS INT  
/*WITH*/  
AS BEGIN  
    DECLARE @DBVersion INT;  
         
    SELECT TOP(1) @DBVersion = DBVersion  
    FROM mdm.tblDBUpgradeHistory   
    ORDER BY DBVersion DESC;  
      
    --Do not return null if no upgrades exist. Return zero  
    SELECT @DBVersion = ISNULL(@DBVersion, 0)  
  
    RETURN @DBVersion;  
END --fn
GO
