SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- select mdm.udfStagingErrorViewNameGet('foo')  
-- result:  
-- stg.viw_foo_StagingErrors  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfStagingErrorViewNameGet]  
(  
    @StagingTableBaseName sysname  
)  
RETURNS sysname  
AS BEGIN  
  
    DECLARE @ErroViewName       sysname;  
  
    SET @ErroViewName = N'stg.' + QUOTENAME('viw_' + @StagingTableBaseName + '_StagingErrors');     
  
    RETURN @ErroViewName;  
      
END; --fn
GO
