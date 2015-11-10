SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	DECLARE @Name NVARCHAR(MAX);  
	DECLARE @MUID UniqueIdentifier;  
	DECLARE @Privilege_ID INT;  
	EXEC mdm.udpInformationLookupDerivedHierarchy 	  
			 @User_ID				=	1		  
			,@DerivedHierarchy_MUID =	NULL	  
			,@DerivedHierarchy_ID	=	NULL  
			,@DerivedHierarchy_Name =	'AccountType'  
			,@Model_ID				=	2  
			,@Model_MUID			=	NULL  
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
CREATE PROCEDURE [mdm].[udpInformationLookupDerivedHierarchy]  
(  
	@User_ID				INT = NULL,  
	@DerivedHierarchy_MUID	UNIQUEIDENTIFIER = NULL,	--\  
	@DerivedHierarchy_ID	INT = NULL,					--One of these 3 always required  
	@DerivedHierarchy_Name	NVARCHAR(MAX) = NULL,		--/  
	@Model_ID				INT = NULL,					--\ One of these always required (except Model)  
	@Model_MUID				UNIQUEIDENTIFIER = NULL,	--/  
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
		@ID= dh.ID   
		, @Name= dh.[Name]  
		, @MUID= dh.MUID  
		, @Privilege_ID= S.Privilege_ID  
		FROM mdm.tblDerivedHierarchy dh   
		INNER JOIN mdm.tblModel mdl ON dh.Model_ID = mdl.ID  
		LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY_DERIVED S ON S.ID=dh.ID  
		WHERE   
			S.User_ID = @User_ID  
			AND (dh.ID = @DerivedHierarchy_ID OR @DerivedHierarchy_ID IS NULL)  
			AND (dh.[Name] = @DerivedHierarchy_Name OR @DerivedHierarchy_Name IS NULL)  
			AND (dh.MUID = @DerivedHierarchy_MUID OR @DerivedHierarchy_MUID IS NULL)  
			AND (dh.Model_ID = @Model_ID OR @Model_ID IS NULL)  
			AND (mdl.MUID = @Model_MUID OR @Model_MUID IS NULL)  
			AND S.Privilege_ID  > 1 --Needed to make sure that all Denied objects are treated as the same as invalid(non existent) objects  
		ORDER BY dh.ID;  
		  
	SET NOCOUNT OFF;  
END
GO
