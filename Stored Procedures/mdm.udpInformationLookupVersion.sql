SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	DECLARE @Name NVARCHAR(MAX);  
	DECLARE @MUID UniqueIdentifier;  
	DECLARE @Privilege_ID INT;  
	EXEC mdm.udpInformationLookupVersion 	  
			 @User_ID		=	1  
			,@Version_MUID	=	NULL	  
			,@Version_ID	=	NULL  
			,@Version_Name	=	'Version 1'  
			,@Model_ID		=	4  
			,@Model_MUID	=	NULL  
			,@ID			=	@ID				OUTPUT  
			,@Name			=	@Name			OUTPUT  
			,@MUID			=	@MUID			OUTPUT  
			,@Privilege_ID	=	@Privilege_ID	OUTPUT  
	SELECT @ID, @Name, @MUID, @Privilege_ID;  
	  
*/		  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpInformationLookupVersion]  
(  
	@User_ID				INT = NULL,  
	@Version_MUID			UNIQUEIDENTIFIER = NULL,	--\  
	@Version_ID				INT = NULL,					--One of these 3 always required  
	@Version_Name			NVARCHAR(MAX) = NULL,		--/  
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
				@ID = ver.ID,   
				@Name = ver.[Name],   
				@MUID = ver.MUID,  
				@Privilege_ID=CASE    
			                    WHEN (ver.Status_ID = 2 AND S.IsAdministrator <> 1) OR ver.Status_ID = 3 THEN 3   
			                    ELSE 2   
			                 END  
			FROM mdm.tblModelVersion ver   
			INNER JOIN mdm.tblModel mdl ON ver.Model_ID = mdl.ID	  
			LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL S ON S.ID=ver.Model_ID  
			WHERE   
				S.User_ID = @User_ID  
				AND (ver.ID = @Version_ID OR @Version_ID IS NULL)  
				AND (ver.[Name] = @Version_Name OR @Version_Name IS NULL)  
				AND (ver.MUID = @Version_MUID OR @Version_MUID IS NULL)  
				AND (ver.Model_ID = @Model_ID OR @Model_ID IS NULL)  
				AND (mdl.MUID = @Model_MUID OR @Model_MUID IS NULL)  
				AND S.Privilege_ID > 1 --Needed to make sure that all Denied objects are treated as the same as invalid(non existent) objects  
			ORDER BY ver.ID;  
			  
	SET NOCOUNT OFF;  
		  
END
GO
