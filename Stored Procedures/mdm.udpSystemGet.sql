SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	Gets the record from tblSystem  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSystemGet]  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
    DECLARE @NeedsRepair    BIT = 1,  
            @DbName         NVARCHAR(MAX)  
  
    SET @DbName = DB_NAME()  
  
    -- A DB does not need repair if has both the broker enabled and trustworthy on  
    SELECT @NeedsRepair = 0 from sys.databases where name=@DbName AND is_broker_enabled=1 and is_trustworthy_on=1  
  
	SELECT TOP 1 [ID]  
      ,[ProductName]  
      ,[ProductVersion]  
      ,[ProductRegistrationKey]  
      ,[SchemaVersion]  
      ,[EnterDTM]  
      ,[EnterUserID]  
      ,[LastChgUserID]  
      ,[LastChgDTM]  
      ,@NeedsRepair AS NeedsRepair  
	FROM [mdm].[tblSystem]  
	ORDER BY [ID]  
    
	SET NOCOUNT OFF  
END --proc
GO
