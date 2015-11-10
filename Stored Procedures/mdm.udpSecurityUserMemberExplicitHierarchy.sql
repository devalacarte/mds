SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Example  : mdm.udpSecurityUserMemberExplicitHierarchy(2, 1, 6, 1, , @Privilege_ID OUT) --Returns the default privilege for User ID = 2 and Hierarchy ID = 6  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityUserMemberExplicitHierarchy]  
(  
	@User_ID INT,   
	@Item_ID INT,   
	@MemberType_ID TINYINT,   
	@Privilege_ID INT OUTPUT  
)    
AS    
BEGIN     
  
    DECLARE @InferredPrivilegeId	INT = 99,    
            @ReadOnlyPrivilegeId	INT = 3,    
            @UpdatePrivilegeId		INT = 2,  
            @ExHierarchyPrivilege	INT,  
            @MemberTypePrivilege	INT;       
  
    SELECT @MemberTypePrivilege = ssum.Privilege_ID     
    FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE ssum    
	    INNER JOIN mdm.tblHierarchy h     
	    ON ssum.Entity_ID = h.Entity_ID     
	    AND h.ID = @Item_ID     
    WHERE ssum.User_ID = @User_ID     
	    AND ssum.ID = @MemberType_ID;    
        
    SELECT @ExHierarchyPrivilege = ssuh.Privilege_ID     
    FROM mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY ssuh  
    WHERE ssuh.User_ID = @User_ID   
	    AND ssuh.ID = @Item_ID;    
  
    SET @MemberTypePrivilege = ISNULL(@MemberTypePrivilege, @InferredPrivilegeId);    
    SET @ExHierarchyPrivilege = ISNULL(@ExHierarchyPrivilege, @InferredPrivilegeId);    
      
    -- model and member security privilege intersection for hierarchymembers  
    -- occurs in the business logic layer of the API, so in this case we've reverted to  
    -- the previous method of taking the least restrictive of the two unless one is Deny,  
    -- at which time we use it.  
    SELECT @Privilege_ID = mdm.udfMin(@MemberTypePrivilege, @ExHierarchyPrivilege);   
  
END
GO
