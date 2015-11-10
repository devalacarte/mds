SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
mdm.udpStagingClear 1,1,1  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpStagingClear]  
(  
	@User_ID            INT,  
	@StagingType_ID		INT,  
	@DeleteType_ID		INT,  
	@ModelName		    NVARCHAR(250) = NULL,  
	@Batch_ID           INT = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	-- Get User Name from ID  
	DECLARE @UserName as NVARCHAR(100)  
  
	SET @UserName=mdm.udfUserNameGetByUserID(@User_ID)  
  
	IF @DeleteType_ID = 3 -- Delete by Batch, including the batch record.  
		BEGIN  
			DELETE FROM mdm.tblStgMember WHERE Batch_ID = @Batch_ID;  
			DELETE FROM mdm.tblStgMemberAttribute WHERE Batch_ID = @Batch_ID;  
			DELETE FROM mdm.tblStgRelationship WHERE Batch_ID = @Batch_ID;  
			DELETE FROM mdm.tblStgBatch WHERE ID = @Batch_ID;  
			-- Clear error detail table records.  
			DELETE FROM mdm.tblStgErrorDetail WHERE Batch_ID = @Batch_ID;  
		END  
	IF @DeleteType_ID = 2 -- Delete by User.  
		BEGIN  
			DELETE FROM mdm.tblStgMember WHERE (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
			DELETE FROM mdm.tblStgMemberAttribute WHERE (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
			DELETE FROM mdm.tblStgRelationship WHERE (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
		END  
	IF @DeleteType_ID = 1 -- Delete by Model and User the staging records that have processed successfully.  
		BEGIN  
			IF @StagingType_ID = 1  
				BEGIN  
					DELETE FROM mdm.tblStgMember WHERE Status_ID = 1 AND ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
				END  
			ELSE IF @StagingType_ID = 2  
				BEGIN  
					DELETE FROM mdm.tblStgMemberAttribute WHERE Status_ID = 1 AND ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
				END  
			ELSE IF @StagingType_ID = 3  
				BEGIN  
					DELETE FROM mdm.tblStgRelationship WHERE Status_ID = 1 AND ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
				END  
			ELSE IF @StagingType_ID = 4  
				BEGIN  
					DELETE FROM mdm.tblStgMember WHERE Status_ID = 1 AND ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
					DELETE FROM mdm.tblStgMemberAttribute WHERE Status_ID = 1 AND ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
					DELETE FROM mdm.tblStgRelationship WHERE Status_ID = 1 AND ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
				END		  
		END  
	IF @DeleteType_ID = 0 -- Delete by Model and User.  
		BEGIN  
			IF @StagingType_ID = 1  
				BEGIN  
					DELETE FROM mdm.tblStgMember WHERE ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
				END  
			ELSE IF @StagingType_ID = 2  
				BEGIN  
					DELETE FROM mdm.tblStgMemberAttribute WHERE ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
				END  
			ELSE IF @StagingType_ID = 3  
				BEGIN  
					DELETE FROM mdm.tblStgRelationship WHERE ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
				END	  
			ELSE IF @StagingType_ID = 4  
				BEGIN  
					DELETE FROM mdm.tblStgMember WHERE ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
					DELETE FROM mdm.tblStgMemberAttribute WHERE ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
					DELETE FROM mdm.tblStgRelationship WHERE ModelName = @ModelName AND (UserName = @UserName OR ISNULL(UserName,N'')=N'')  
				END		  
		END  
  
	SET NOCOUNT OFF  
END --proc
GO
