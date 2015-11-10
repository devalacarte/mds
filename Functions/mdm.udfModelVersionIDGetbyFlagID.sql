SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
DECLARE @VersionID int  
        ,@VersionFlagID int;  
          
SET @VersionFlagID = 6;  
  
SELECT @VersionID = mdm.udfModelVersionIDGetbyFlagID(@VersionFlagID);  
  
PRINT CAST(@VersionID AS NVARCHAR(10));  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
  
CREATE FUNCTION [mdm].[udfModelVersionIDGetbyFlagID]  
(  
	@FlagID INT   
)  
RETURNS INT  
AS  
BEGIN  
  
DECLARE @ModelID INT  
  
SELECT @ModelID = ID   
FROM mdm.tblModelVersion WHERE VersionFlag_ID = @FlagID  
	RETURN @ModelID  
END
GO
