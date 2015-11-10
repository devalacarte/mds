SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	DECLARE @Name NVARCHAR(MAX);  
	DECLARE @MUID UniqueIdentifier;  
	DECLARE @Privilege_ID INT;  
	EXEC mdm.udpInformationLookupModel 	  
			 @User_ID =		1		  
			,@Model_MUID =	NULL	  
			,@Model_ID =	NULL  
			,@Model_Name =	'Product'  
			,@ID =			@ID				OUTPUT  
			,@Name	=		@Name			OUTPUT  
			,@MUID	=		@MUID			OUTPUT  
			,@Privilege_ID = @Privilege_ID	OUTPUT  
	SELECT @ID, @Name, @MUID, @Privilege_ID;  
	  
*/		  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
  
CREATE PROCEDURE [mdm].[udpInformationLookupModel]  
(  
	@User_ID				INT = NULL,  
	@Model_MUID				UNIQUEIDENTIFIER = NULL,	--\  
	@Model_ID				INT = NULL,					--One of these 3 always required  
	@Model_Name				NVARCHAR(MAX) = NULL,		--/  
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
		@ID =  M.ID,   
		@Name = M.[Name],   
		@MUID = M.MUID,  
		@Privilege_ID=CASE S.Privilege_ID WHEN 99 THEN 3 ELSE S.Privilege_ID END  
	FROM mdm.tblModel M  
	LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL S ON S.ID=M.ID  
	WHERE   
		(M.ID = @Model_ID OR @Model_ID IS NULL)  
		AND (M.[Name] = @Model_Name OR @Model_Name IS NULL)  
		AND (M.MUID = @Model_MUID OR @Model_MUID IS NULL)  
		AND S.User_ID = @User_ID  
        AND S.Privilege_ID > 1 --Needed to make sure that all Denied objects are treated as the same as invalid(non existent) objects  
    ORDER BY M.ID;  
      
    SET NOCOUNT OFF;  
END
GO
