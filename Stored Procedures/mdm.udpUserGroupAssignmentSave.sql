SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpUserGroupAssignmentSave 1,1,1  
select * from mdm.tblUserGroupAssignment  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupAssignmentSave]  
(  
	@SystemUser_ID		INT, --Person performing save  
	@User_ID 			INT, --Username  
	@UserGroup_ID		INT  
  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	IF NOT EXISTS(SELECT * FROM mdm.tblUserGroupAssignment WHERE UserGroup_ID = @UserGroup_ID AND User_ID = @User_ID)  
    	INSERT INTO mdm.tblUserGroupAssignment(UserGroup_ID, User_ID, EnterDTM, EnterUserID, LastChgDTM, LastChgUserID)  
    	    SELECT @UserGroup_ID,@User_ID,GETUTCDATE(),@SystemUser_ID,GETUTCDATE(),@SystemUser_ID;  
    ELSE  
        UPDATE mdm.tblUserGroupAssignment   
            SET LastChgDTM = GETUTCDATE(),  
                LastChgUserID = @SystemUser_ID  
            WHERE UserGroup_ID = @UserGroup_ID AND User_ID = @User_ID;  
  
	IF @@ERROR <> 0  
		BEGIN  
			RAISERROR('MDSERR500058|The group assignment cannot be saved. A database error occurred.', 16, 1);  
			RETURN(1);	      
		END  
  
	SET NOCOUNT OFF;  
END --proc
GO
