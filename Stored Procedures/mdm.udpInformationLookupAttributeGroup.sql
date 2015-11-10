SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	DECLARE @Name NVARCHAR(MAX);  
	DECLARE @MUID UniqueIdentifier;  
	DECLARE @Privilege_ID INT;  
	EXEC mdm.udpInformationLookupAttributeGroup 	  
			 @User_ID				=	1  
			,@AttributeGroup_MUID	=	NULL	  
			,@AttributeGroup_ID		=	NULL  
			,@AttributeGroup_Name	=	'General Model Information'  
			,@Entity_ID				=	1  
			,@Entity_MUID			=	NULL  
			,@ID					=	@ID				OUTPUT  
			,@Name					=	@Name			OUTPUT  
			,@MUID					=	@MUID			OUTPUT  
			,@Privilege_ID			=	@Privilege_ID	OUTPUT  
	SELECT @ID, @Name, @MUID, @Privilege_ID;  
	  
*/		  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpInformationLookupAttributeGroup]  
(  
	@User_ID				INT = NULL,  
	@AttributeGroup_MUID	UNIQUEIDENTIFIER = NULL,	--\  
	@AttributeGroup_ID		INT = NULL,					--One of these 3 always required  
	@AttributeGroup_Name	NVARCHAR(MAX) = NULL,		--/  
	@Entity_ID				INT = NULL,					--\ One of these always required (except Model)  
	@Entity_MUID			UNIQUEIDENTIFIER = NULL,	--/  
	@ID						INTEGER = NULL OUTPUT,  
	@Name					NVARCHAR(MAX) = NULL OUTPUT,  
	@MUID					UNIQUEIDENTIFIER = NULL OUTPUT,  
	@Privilege_ID			INTEGER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
  
	SET NOCOUNT ON;  
	SET @User_ID = ISNULL(@User_ID, 0);  
	  
	SELECT TOP 1  
	@ID= grp.ID   
	, @Name= grp.[Name]  
	, @MUID= grp.MUID  
	, @Privilege_ID= S.Privilege_ID  
	FROM mdm.tblAttributeGroup grp     
	INNER JOIN mdm.tblEntity ent ON grp.Entity_ID = ent.ID    
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTEGROUP S ON S.ID=grp.ID   
	WHERE   
		S.User_ID = @User_ID  
		AND (grp.ID = @AttributeGroup_ID OR @AttributeGroup_ID IS NULL)  
		AND (grp.[Name] = @AttributeGroup_Name OR @AttributeGroup_Name IS NULL)  
		AND (grp.MUID = @AttributeGroup_MUID OR @AttributeGroup_MUID IS NULL)  
		AND (grp.Entity_ID = @Entity_ID OR @Entity_ID IS NULL)  
		AND (ent.MUID = @Entity_MUID OR @Entity_MUID IS NULL)  
		AND S.Privilege_ID  > 1 --Needed to make sure that all Denied objects are treated as the same as invalid(non existent) objects  
	ORDER BY grp.ID;  
	  
	SET NOCOUNT OFF;  
	  
END
GO
