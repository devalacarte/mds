SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpUserDelete 'admin','jsmith'  
select * from mdm.tblUser  
*/  
CREATE PROCEDURE [mdm].[udpUserDelete]  
(  
   @SystemUser_ID	INT, --Person performing save  
   @User_ID			INT, --Username  
   @Return_ID		INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
    IF @SystemUser_ID = @User_ID  
    BEGIN  
        RAISERROR('MDSERR500019|The logged-in user cannot be deleted.', 16, 1);  
        RETURN(1)       
    END  
    --DECLARE @User_ID as INT  
    --DECLARE @SystemUser_ID as INT  
    --SELECT @User_ID = mdm.udfUserIDGetByUserName(@UserName)  
    --SELECT @SystemUser_ID = mdm.udfUserIDGetByUserName(@SystemUserName) --person performing Save  
  
    IF EXISTS (SELECT ID FROM mdm.tblUser WHERE ID = @User_ID)  
       BEGIN  
          UPDATE  
             mdm.tblUser  
          SET  
             Status_ID = 2,  
             LastChgUserID = @SystemUser_ID,  
             LastChgDTM = GETUTCDATE()  
          FROM  
             mdm.tblUser  
          WHERE  
             ID = @User_ID  
         
         --SELECT @Return_ID = @User_ID  
  
         DELETE FROM mdm.tblUserGroupAssignment WHERE User_ID = @User_ID  
         DELETE FROM mdm.tblNavigationSecurity WHERE Foreign_ID = @User_ID AND ForeignType_ID = 1  
         EXEC mdm.udpSecurityPrivilegesDeleteByPrincipalID @User_ID, 1  
    END  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR500056|The user cannot be deleted. A database error occurred.', 16, 1);  
            RETURN(1)       
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
