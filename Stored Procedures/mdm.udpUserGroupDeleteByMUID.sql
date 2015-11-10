SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupDeleteByMUID]  
(  
    @SystemUser_ID	INT, --Person performing save  
    @UserGroup_MUID			UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
   
    DECLARE @UserGroup_ID int,  
            @return_value int  
  
   
    IF (@UserGroup_MUID IS NULL OR CAST(@UserGroup_MUID  AS BINARY) = 0x0 OR   
            (NOT EXISTS (SELECT MUID FROM mdm.tblUserGroup WHERE MUID = @UserGroup_MUID)))  
        BEGIN  
            RAISERROR('MDSERR500044|The group cannot be deleted. The ID is not valid.', 16, 1);  
        END  
      
    SELECT @UserGroup_ID  = (SELECT ID FROM mdm.tblUserGroup WHERE MUID = @UserGroup_MUID)  
   
    EXEC @return_value = [mdm].[udpUserGroupDelete] @SystemUser_ID,@UserGroup_ID;  
      
    SET NOCOUNT OFF  
END --proc
GO
