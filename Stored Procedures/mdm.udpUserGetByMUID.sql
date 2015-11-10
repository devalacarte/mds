SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
EXEC mdm.udpUserGetByMuid 3F07AFF7-9557-4D7E-AFEA-A8E2AFA6F90E  
*/  
CREATE PROCEDURE [mdm].[udpUserGetByMUID]  
(  
    @User_MUID UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
    DECLARE @USER_ID int,  
            @return_value int  
  
    IF (@User_MUID IS NULL OR CAST(@User_MUID  AS BINARY) = 0x0 OR (NOT EXISTS (SELECT MUID FROM mdm.tblUser WHERE MUID = @User_MUID)))  
    BEGIN  
        RAISERROR('MDSERR500001|The user GUID is not valid.', 16, 1);  
        RETURN;  
    END  
  
    SELECT @USER_ID = (SELECT ID FROM mdm.tblUser where MUID=@User_MUID)  
  
    EXEC [mdm].[udpUserGet] @USER_ID  
  
    SET NOCOUNT OFF  
END --proc
GO
