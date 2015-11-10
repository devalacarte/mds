SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpSecurityPrivilegesDelete 1, 12, 1, 1  
  
--The list of Objects can be found in mdm.tblSecurityObject.  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesDelete]  
(  
	@Principal_ID		INT = NULL,  
	@PrincipalType_ID	INT = NULL,  
	@Object_ID			INT,  
	@Securable_ID		INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @Role_ID			INT  
  
	IF ISNULL(@Principal_ID, 0) > 0 AND ISNULL(@PrincipalType_ID, 0) > 0 BEGIN  
		SELECT	@Role_ID = Role_ID  
		FROM	mdm.tblSecurityAccessControl  
		WHERE	Principal_ID = @Principal_ID  
		AND		PrincipalType_ID = @PrincipalType_ID  
  
		IF @Role_ID IS NOT NULL BEGIN  
			DELETE FROM mdm.tblSecurityRoleAccess WHERE Role_ID = @Role_ID AND Object_ID = @Object_ID AND Securable_ID = @Securable_ID  
		END  
	END       
    ELSE IF ISNULL(@Principal_ID, 0) = 0 AND ISNULL(@PrincipalType_ID, 0) > 0 BEGIN  
        DELETE FROM mdm.tblSecurityRoleAccess  
        WHERE Object_ID = 5  
        AND Securable_ID = @Securable_ID  
        AND Role_ID IN (  
            SELECT	Role_ID  
            FROM	mdm.tblSecurityAccessControl  
            WHERE	PrincipalType_ID = @PrincipalType_ID  
        )  
    END  
	ELSE BEGIN  
			DELETE   
			FROM	mdm.tblSecurityRoleAccess   
			WHERE	Object_ID = @Object_ID   
			AND		Securable_ID = @Securable_ID  
	END  
  
	SET NOCOUNT OFF  
END --proc
GO
