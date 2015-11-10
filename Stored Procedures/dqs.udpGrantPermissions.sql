SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC [dqs].[udpGrantPermissions]  
  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [dqs].[udpGrantPermissions]  
AS BEGIN  
  
-- If user doesn't exist, create the login and give it Schema access.  
-- This SPROC will called on every MDS service load, as DQS can be installed after MDS.  
IF NOT EXISTS(SELECT principal_id FROM sys.database_principals WHERE name='##MS_dqs_service_login##')  
BEGIN  
CREATE USER ##MS_dqs_service_login## FOR LOGIN ##MS_dqs_service_login## with default_schema=dqs;  
  
GRANT CONTROL ON SCHEMA :: dqs  
TO [##MS_dqs_service_login##];  
  
END;  
  
END -- Proc
GO
