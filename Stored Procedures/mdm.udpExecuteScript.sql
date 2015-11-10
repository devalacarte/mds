SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Executes a SQL script.  Primarily used within MDS by the business rule stored prodedure generation process.  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpExecuteScript]  
(  
	@SqlScript	NVARCHAR(MAX)  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON  
      
	EXEC sp_executesql @SqlScript;  
  
	SET NOCOUNT OFF  
	  
END; --proc
GO
