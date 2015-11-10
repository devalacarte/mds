SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
exec mdm.udpUserGroupAssignmentDelete 'jhills', NULL    -- Deletes all group assignments for user_id 'jhills'  
exec mdm.udpUserGroupAssignmentDelete NULL, 8           -- Deletes all group assignments for usergroup_id 8   
exec mdm.udpUserGroupAssignmentDelete 'bbarnett', 9     -- Deletes group assignment for user_id 'bbarnett' and usergroup_id 9  
exec mdm.udpUserGroupAssignmentDelete NULL, NULL        -- Deletes all group assignments  
  
select u.UserName, ga.* from mdm.tblUserGroupAssignment ga inner join mdm.tblUser u on u.id = ga.User_ID order by usergroup_id, user_id  
select u.UserName, ga.* from mdm.tblUserGroupAssignment ga inner join mdm.tblUser u on u.id = ga.User_ID order by user_id, usergroup_id   
  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupAssignmentDelete]  
(  
    @User_ID        INT = NULL,  
    @UserGroup_ID	INT = NULL  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DELETE   
    FROM	mdm.tblUserGroupAssignment   
    WHERE	((@UserGroup_ID IS NULL) OR (UserGroup_ID = @UserGroup_ID))  
    AND		((@User_ID IS NULL) OR ([User_ID] = @User_ID))  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR500057|The group assignment cannot be deleted. A database error occurred.', 16, 1);  
            RETURN(1)	      
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
