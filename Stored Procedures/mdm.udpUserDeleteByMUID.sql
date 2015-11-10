SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpUserDeleteByMUID 'admin','jsmith'  
select * from mdm.tblUser  
*/  
CREATE PROCEDURE [mdm].[udpUserDeleteByMUID]  
(  
    @SystemUser_ID	INT, --Person performing save  
   @User_MUID			UNIQUEIDENTIFIER,  
   @Return_ID		INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
   
    DECLARE @Administrator_ID int = 1;  
    DECLARE @User_ID int,  
            @return_value int;  
  
    IF (@User_MUID IS NULL OR CAST(@User_MUID  AS BINARY) = 0x0 OR (NOT EXISTS (SELECT MUID FROM mdm.tblUser WHERE MUID = @User_MUID)))  
        BEGIN  
            RAISERROR('MDSERR500043|The user cannot be deleted. The ID is not valid.', 16, 1);  
        END  
      
    SELECT @User_ID  = (SELECT ID FROM mdm.tblUser WHERE MUID = @User_MUID)  
   
    IF (@User_ID = @Administrator_ID)   
        BEGIN  
            RAISERROR('MDSERR500047|The Master Data Services administrator cannot be deleted.', 16, 1);  
        END  
      
    EXEC @return_value = [mdm].[udpUserDelete] @SystemUser_ID,@User_ID,@Return_ID OUTPUT;  
      
    SET NOCOUNT OFF  
END --proc
GO
