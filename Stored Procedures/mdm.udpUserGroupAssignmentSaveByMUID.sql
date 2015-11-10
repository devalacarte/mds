SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.[udpUserGroupAssignmentSaveByMUID] 1,1,1  
select * from mdm.tblUserGroupAssignment  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupAssignmentSaveByMUID]  
(  
    @SystemUser_ID		INT, --Person performing save  
    @User_ID 			int, --Username  
    @UserGroup_MUID		UNIQUEIDENTIFIER  
  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
    DECLARE @UserGroup_ID int,  
            @return_value int  
  
   
    IF (@UserGroup_MUID IS NULL OR CAST(@UserGroup_MUID  AS BINARY) = 0x0 OR (NOT EXISTS (SELECT MUID FROM mdm.tblUserGroup WHERE MUID = @UserGroup_MUID)))  
        BEGIN  
            RAISERROR('MDSERR500022|The group assignment cannot be updated. The group ID is not valid.', 16, 1);  
            RETURN;  
        END  
  
    SELECT @UserGroup_ID  = (SELECT ID FROM mdm.tblUserGroup WHERE MUID = @UserGroup_MUID)  
  
    EXEC @return_value = [mdm].[udpUserGroupAssignmentSave] @SystemUser_ID,@User_ID,@UserGroup_ID;  
  
--INSERT INTO mdm.tblUserGroupAssignment SELECT @UserGroup_ID,@User_ID,GETUTCDATE(),@SystemUser_ID,GETUTCDATE(),@SystemUser_ID  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR500058|The group assignment cannot be saved. A database error occurred.', 16, 1);  
            RETURN(1)	      
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
