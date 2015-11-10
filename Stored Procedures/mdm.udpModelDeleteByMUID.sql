SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpModelDeleteByMUID '1565655D-4B03-4F64-B37F-956F75BF396D'  
*/  
CREATE PROCEDURE [mdm].[udpModelDeleteByMUID]  
(  
    @Model_MUID UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @Model_ID INT;  
        
    SELECT  @Model_ID = ID FROM mdm.tblModel WHERE MUID = @Model_MUID and IsSystem = 0;  
  
    --Test for invalid parameters  
    IF @Model_ID IS NULL --Invalid Model_MUID  
    BEGIN  
        RAISERROR('MDSERR200021|The model cannot be deleted. The model ID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    EXEC mdm.udpModelDelete @Model_ID;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
