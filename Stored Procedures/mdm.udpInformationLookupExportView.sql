SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	DECLARE @Name NVARCHAR(MAX);  
	DECLARE @MUID UniqueIdentifier;  
	DECLARE @Privilege_ID INT;  
	EXEC mdm.udpInformationLookupExportView 	  
			 @ExportView_MUID	=	NULL	  
			,@ExportView_ID		=	1  
			,@ExportView_Name	=	NULL  
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
CREATE PROCEDURE [mdm].[udpInformationLookupExportView]  
(  
	@ExportView_MUID		UNIQUEIDENTIFIER = NULL,	--\  
	@ExportView_ID			INT = NULL,					--One of these 3 always required  
	@ExportView_Name		NVARCHAR(MAX) = NULL,		--/  
	@ID						INTEGER = NULL OUTPUT,  
	@Name					sysname = NULL OUTPUT,  
	@MUID					UNIQUEIDENTIFIER = NULL OUTPUT,  
	@Privilege_ID			INTEGER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
	  
	SELECT TOP 1  
		@ID =  ID,   
		@Name = [Name],   
		@MUID = MUID,  
		@Privilege_ID = 2  
	FROM mdm.tblSubscriptionView    
	WHERE   
		(ID = @ExportView_ID OR @ExportView_ID IS NULL)  
		AND ([Name] = @ExportView_Name OR @ExportView_Name IS NULL)  
		AND (MUID = @ExportView_MUID OR @ExportView_MUID IS NULL)  
    ORDER BY ID;  
          
    SET NOCOUNT OFF;  
END
GO
