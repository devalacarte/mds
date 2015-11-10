SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Wrapper for mdm.udpVersionDelete sproc.  
*/  
CREATE PROCEDURE [mdm].[udpVersionDeleteByMUID]  
(  
        @Version_MUID UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
    DECLARE @Version_ID INT;  
  
    SELECT @Version_ID = ID FROM mdm.tblModelVersion WHERE MUID = @Version_MUID;  
  
    --Test for invalid parameters  
    IF @Version_ID IS NULL --Invalid Model_MUID  
    BEGIN  
        RAISERROR('MDSERR200038|The version cannot be deleted. The version MUID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    EXEC mdm.udpVersionDelete @Version_ID;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
