SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpUserGroupDelete 1,1  
select * from mdm.tblUserGroup  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupDelete]  
(  
    @SystemUser_ID 	INT,  
    @UserGroup_ID	INT = NULL  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    IF EXISTS (SELECT ID FROM mdm.tblUserGroup WHERE ID = @UserGroup_ID) BEGIN  
                  
        UPDATE  
            tblUserGroup  
        SET  
            Status_ID = 2,  
            LastChgUserID = @SystemUser_ID,  
            LastChgDTM = GETUTCDATE()  
        FROM  
            mdm.tblUserGroup  
        WHERE  
            ID = @UserGroup_ID  
  
  
         DELETE FROM mdm.tblUserGroupAssignment WHERE UserGroup_ID = @UserGroup_ID  
         DELETE FROM mdm.tblNavigationSecurity WHERE Foreign_ID = @UserGroup_ID AND ForeignType_ID = 2  
         EXEC mdm.udpSecurityPrivilegesDeleteByPrincipalID @UserGroup_ID, 2  
  
    END  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR500059|The group cannot be deleted. A database error occurred.', 16, 1);  
            RETURN(1)	      
        END  
  
  
    SET NOCOUNT OFF  
END --proc
GO
