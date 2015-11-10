SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Example  : mdm.udpSecurityUserMemberEntityOrCollection(2, 1020, 4, 1, @Privilege_ID OUT) --Returns the default privilege for User ID = 2 and Attribute ID = 1288 (leaf member)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityUserMemberEntityOrCollection]  
(  
	@User_ID INT,   
	@Item_ID INT,   
	@MemberType_ID TINYINT,   
	@Privilege_ID INT OUTPUT  
)    
AS    
BEGIN     
      
    DECLARE @InferredPrivilegeId INT = 99,  
            @ReadOnlyPrivilegeId INT = 3,  
            @UpdatePrivilegeId   INT = 2;  
      
    SELECT @Privilege_ID = Privilege_ID   
        FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE   
        WHERE User_ID = @User_ID   
            AND Entity_ID = @Item_ID   
            AND ID = @MemberType_ID;  
  
    --from tblSecurityPrivilege, 99 = -NA-  
    SET @Privilege_ID = ISNULL(@Privilege_ID, @InferredPrivilegeId);  
  
	--if the user has no privs at the memberType level,    
    --we need to check the attribute level due to bi-directional inheritence.    
    --i.e. if the user has access to an attribute in the entity, then they    
    --implicitly get read-only access to the entity, else    
    --99 turns into a soft DENY,which we can handle.  
    -- If the privileges on the member type are read only. There could be privileges on the attributes that allow the   
    -- user to update. Verify those as well     
    IF @Privilege_ID = @InferredPrivilegeId  OR @Privilege_ID = @ReadOnlyPrivilegeId BEGIN    
  
        DECLARE @AttributePrivilege_ID		INT,  
				@ExHierarchyPrivilege_ID	INT;    
	      
	    --this select checks for any explicit hierarchy privs in the entity.  
	    SELECT TOP 1 @ExHierarchyPrivilege_ID = Privilege_ID   
			FROM mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY   
			WHERE User_ID = @User_ID     
			    AND Entity_ID = @Item_ID  
			ORDER BY Privilege_ID ASC;  
	      
	    --this select checks for any attribute privs in the entity. We filter deny as these columns will not be returned   
	    -- for the members. We only care for update, readonly or not specified.  
	    SELECT TOP 1 @AttributePrivilege_ID = Privilege_ID  
		    FROM mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTE     
		    WHERE User_ID = @User_ID   
			    AND Entity_ID = @Item_ID   
			    AND MemberType_ID = @MemberType_ID AND Privilege_ID <> 1  
		    ORDER BY Rank, Privilege_ID ASC;  
    	  
	    SET @ExHierarchyPrivilege_ID = ISNULL(@ExHierarchyPrivilege_ID, @InferredPrivilegeId);    
	    SET @AttributePrivilege_ID = ISNULL(@AttributePrivilege_ID, @InferredPrivilegeId);    
	        
	    --default the membertype to read-only if the user has an attribute or ex-hierarchy privilege    
	    IF @AttributePrivilege_ID IN (@UpdatePrivilegeId, @ReadOnlyPrivilegeId)   
	        SET @Privilege_ID = @AttributePrivilege_ID;  
	    ELSE IF @ExHierarchyPrivilege_ID IN (@UpdatePrivilegeId, @ReadOnlyPrivilegeId)   
	        SET @Privilege_ID = @ReadOnlyPrivilegeId;  
    END;  
  
END
GO
