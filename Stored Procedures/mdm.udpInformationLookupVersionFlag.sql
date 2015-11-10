SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	DECLARE @Name NVARCHAR(MAX);  
	DECLARE @MUID UniqueIdentifier;  
	DECLARE @Privilege_ID INT;  
	EXEC mdm.udpInformationLookupVersionFlag 	  
			 @User_ID			=	1  
			,@VersionFlag_MUID	=	NULL	  
			,@VersionFlag_ID	=	NULL  
			,@VersionFlag_Name	=	'Current'  
			,@Model_ID			=	1  
			,@Model_MUID		=	NULL  
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
CREATE PROCEDURE [mdm].[udpInformationLookupVersionFlag]  
(  
	@User_ID					INT = NULL,  
	@VersionFlag_MUID			UNIQUEIDENTIFIER = NULL,	--\  
	@VersionFlag_ID				INT = NULL,					--One of these 3 always required  
	@VersionFlag_Name			NVARCHAR(MAX) = NULL,		--/  
	@Model_ID					INT = NULL,					--\ One of these always required (except Model)  
	@Model_MUID					UNIQUEIDENTIFIER = NULL,	--/  
	@ID							INTEGER = NULL OUTPUT,  
	@Name						NVARCHAR(MAX) = NULL OUTPUT,  
	@MUID						UNIQUEIDENTIFIER = NULL OUTPUT,  
	@Privilege_ID				INTEGER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
  
	SET NOCOUNT ON;  
	SET @User_ID = ISNULL(@User_ID, 0);  
	  
	SELECT TOP 1  
	@ID= flg.ID   
	, @Name= flg.[Name]  
	, @MUID= flg.MUID  
	, @Privilege_ID= CASE   
						WHEN (flg.Status_ID = 2 AND S.IsAdministrator <> 1) OR flg.Status_ID = 3 THEN 3   
						ELSE 2   
					END      
	FROM mdm.tblModelVersionFlag flg INNER JOIN mdm.tblModel mdl ON flg.Model_ID = mdl.ID	    
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL S ON S.ID=flg.Model_ID   
	WHERE   
		S.User_ID = @User_ID  
		AND (flg.ID = @VersionFlag_ID OR @VersionFlag_ID IS NULL)  
		AND (flg.[Name] = @VersionFlag_Name OR @VersionFlag_Name IS NULL)  
		AND (flg.MUID = @VersionFlag_MUID OR @VersionFlag_MUID IS NULL)  
		AND (flg.Model_ID = @Model_ID OR @Model_ID IS NULL)  
		AND (mdl.MUID = @Model_MUID OR @Model_MUID IS NULL)  
		AND S.Privilege_ID  > 1 --Needed to make sure that all Denied objects are treated as the same as invalid(non existent) objects  
	ORDER BY flg.ID;  
		  
	SET NOCOUNT OFF;  
	  
END
GO
