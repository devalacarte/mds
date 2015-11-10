SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	DECLARE @Name NVARCHAR(MAX);  
	DECLARE @MUID UniqueIdentifier;  
	DECLARE @Privilege_ID INT;  
	EXEC mdm.udpInformationLookupStagingBatch 	  
			 @StagingBatch_MUID	=	NULL	  
			,@StagingBatch_ID	=	1  
			,@StagingBatch_Name	=	NULL  
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
CREATE PROCEDURE [mdm].[udpInformationLookupStagingBatch]  
(  
	@StagingBatch_MUID		UNIQUEIDENTIFIER = NULL,	--\  
	@StagingBatch_ID		INT = NULL,					--One of these 3 always required  
	@StagingBatch_Name		NVARCHAR(MAX) = NULL,		--/  
	@ID						INTEGER = NULL OUTPUT,  
	@Name					NVARCHAR(MAX) = NULL OUTPUT,  
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
	FROM mdm.tblStgBatch    
	WHERE   
		(ID = @StagingBatch_ID OR @StagingBatch_ID IS NULL)  
		AND ([Name] = @StagingBatch_Name OR @StagingBatch_Name IS NULL)  
		AND (MUID = @StagingBatch_MUID OR @StagingBatch_MUID IS NULL)  
    ORDER BY ID;  
          
    SET NOCOUNT OFF;  
END
GO
