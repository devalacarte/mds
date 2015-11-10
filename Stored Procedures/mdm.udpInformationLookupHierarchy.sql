SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	DECLARE @Name NVARCHAR(MAX);  
	DECLARE @MUID UniqueIdentifier;  
	DECLARE @Privilege_ID INT;  
	EXEC mdm.udpInformationLookupHierarchy 	  
			 @User_ID			=	1  
			,@Hierarchy_MUID	=	NULL	  
			,@Hierarchy_ID		=	NULL  
			,@Hierarchy_Name	=	'AccountType'  
			,@Entity_ID			=	7  
			,@Entity_MUID		=	NULL  
			,@ID				=	@ID				OUTPUT  
			,@Name				=	@Name			OUTPUT  
			,@MUID				=	@MUID			OUTPUT  
			,@Privilege_ID		=	@Privilege_ID	OUTPUT  
	SELECT @ID, @Name, @MUID, @Privilege_ID;  
	  
*/		  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpInformationLookupHierarchy]  
(  
	@User_ID			INT = NULL,  
	@Hierarchy_MUID		UNIQUEIDENTIFIER = NULL,	--\  
	@Hierarchy_ID		INT = NULL,					--One of these 3 always required  
	@Hierarchy_Name		NVARCHAR(MAX) = NULL,		--/  
	@Entity_ID			INT = NULL,					--\ One of these always required (except Model)  
	@Entity_MUID		UNIQUEIDENTIFIER = NULL,	--/  
	@ID					INTEGER = NULL OUTPUT,  
	@Name				NVARCHAR(MAX) = NULL OUTPUT,  
	@MUID				UNIQUEIDENTIFIER = NULL OUTPUT,  
	@Privilege_ID		INTEGER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
  
	SET NOCOUNT ON;  
	SET @User_ID = ISNULL(@User_ID, 0);  
	SET @Entity_ID = NULLIF(@Entity_ID, 0);   
	SET @Hierarchy_ID = NULLIF(@Hierarchy_ID, 0);   
	  
	SELECT TOP 1  
	@ID= hir.ID   
	, @Name= hir.[Name]  
	, @MUID= hir.MUID  
	, @Privilege_ID= S.Privilege_ID  
	FROM mdm.tblHierarchy hir     
	INNER JOIN mdm.tblEntity ent ON hir.Entity_ID = ent.ID    
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY S ON S.ID=hir.ID   
	WHERE   
		S.User_ID = @User_ID  
		AND (hir.ID = @Hierarchy_ID OR @Hierarchy_ID IS NULL)  
		AND (hir.[Name] = @Hierarchy_Name OR @Hierarchy_Name IS NULL)  
		AND (hir.MUID = @Hierarchy_MUID OR @Hierarchy_MUID IS NULL)  
		AND (hir.Entity_ID = @Entity_ID OR @Entity_ID IS NULL)  
		AND (ent.MUID = @Entity_MUID OR @Entity_MUID IS NULL)  
		AND S.Privilege_ID  > 1 --Needed to make sure that all Denied objects are treated as the same as invalid(non existent) objects  
	ORDER BY hir.ID;  
	  
	SET NOCOUNT OFF;  
END
GO
