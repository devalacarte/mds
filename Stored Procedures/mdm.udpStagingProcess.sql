SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
	EXEC mdm.udpStagingProcess 1, 3, 4, 0, 0;  
	EXEC mdm.udpStagingProcess 2, 34, 4, 1, 1;  
*/  
CREATE PROCEDURE [mdm].[udpStagingProcess]  
(  
   @User_ID         INT,  
   @Version_ID		INT,  
   @StagingType_ID	INT,		--1 = Members, 2 = Attributes, 3 = Relationships, 4 = All  
   @LogFlag			INT = NULL, --1 = Log anything  
   @DoValidate		BIT = NULL, --1 = Validate after staging; otherwise do not validate.  
   @Batch_ID		INT = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE   
		@Model_ID			        INT,  
		@Hierarchy_ID		        INT,  
		@HierarchyType_ID	        SMALLINT,  
		@ErrorMessage               NVARCHAR(4000),   
        @ErrorSeverity              INT,   
        @ErrorState                 INT,   
        @Error                      INT,  
        @VersionStatus_ID			INT,  
        @VersionStatus_Committed	INT = 3;      
  
  
	DECLARE @TempTable TABLE  
	(  
		Hierarchy_ID		INT,   
		HierarchyType_ID	SMALLINT  
	);  
  
    SELECT @Model_ID = Model_ID, @VersionStatus_ID = Status_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID;    
    
	--Ensure that Version is not committed  
	IF (@VersionStatus_ID = @VersionStatus_Committed) BEGIN  
        RAISERROR('MDSERR310040|Data cannot be loaded into a committed version.', 16, 1);  
        RETURN 1;      
	END;  
	  
	IF @StagingType_ID = 1 OR @StagingType_ID =4 BEGIN  
		EXEC mdm.udpStagingMemberSave @User_ID, @Version_ID, @LogFlag, @Batch_ID;  
	END; --if  
  
	IF @StagingType_ID = 2 OR @StagingType_ID =4 BEGIN  
		EXEC mdm.udpStagingMemberAttributeSave @User_ID, @Version_ID, @LogFlag, @Batch_ID;  
	END; --if  
  
	IF @StagingType_ID = 3 OR @StagingType_ID =4 BEGIN  
		EXEC mdm.udpStagingRelationshipSave @User_ID, @Version_ID, @LogFlag, @Batch_ID;  
	END; --if  
  
	IF @StagingType_ID <> 3	BEGIN  
  
		--Deadlock risk mitigated using an applock in the business rule code-generated procedure. See TFS 388360  
		UPDATE umc SET  
			umc.LastCount= -1 ,  
			umc.LastChgDTM = GETUTCDATE()  
		FROM mdm.tblUserMemberCount AS umc  
		INNER JOIN mdm.tblEntity e  
			ON umc.Entity_ID = e.ID  
		INNER JOIN mdm.tblModelVersion mv  
			ON mv.Model_ID = e.Model_ID   
			AND mv.ID = @Version_ID  
		WHERE  
			umc.Version_ID = @Version_ID;  
		  
	END; --if  
  
	IF @DoValidate = 1 BEGIN  
		  --EDM-1667 (1/15/2006): Initialize validation Model event.  
		  EXEC mdm.udpSystemEventSave @User_ID, @Version_ID, N'ValidateModel', 1;  
  
		   --EDM-1379 (1/10/2006): Invoke validation after business rules are complete.  
		  EXEC mdm.udpValidateModel @User_ID, @Model_ID, @Version_ID, 1; --Open   
	END; --if  
	-------------------------------------------------------------------------  
	--Create HierarchyMaps  
	-------------------------------------------------------------------------  
	--Get Hierarchy List for Members that where staged.  
	IF @StagingType_ID = 1 OR @StagingType_ID =4 BEGIN  
		INSERT INTO @TempTable  
		SELECT DISTINCT H.ID, 0   
		FROM mdm.tblStgMember AS S  
		INNER JOIN mdm.tblHierarchy AS H ON H.Name = S.HierarchyName   
		INNER JOIN mdm.tblModel AS D ON D.Name = S.ModelName  
		INNER JOIN mdm.tblModelVersion AS V ON V.ID = @Version_ID AND V.Model_ID = D.ID  
		WHERE   
			NULLIF(LTRIM(RTRIM(HierarchyName)), N'') IS NOT NULL   
			AND EXISTS (  
				SELECT Hierarchy_ID  
				FROM	mdm.tblSecurityRoleAccessMember sec  
				WHERE	Hierarchy_ID = H.ID   
				AND HierarchyType_ID = 0  
			);  
	END; --if  
  
	--Get Hierarchy List for Relationships that where staged.  
	IF @StagingType_ID IN (2,4) BEGIN  
		INSERT INTO @TempTable  
		SELECT DISTINCT H.ID, 0   
		FROM mdm.tblStgRelationship AS S  
		INNER JOIN mdm.tblHierarchy AS H ON H.Name = S.HierarchyName   
		INNER JOIN mdm.tblModel AS D ON D.Name = S.ModelName  
    	INNER JOIN mdm.tblModelVersion AS V ON V.ID = @Version_ID AND V.Model_ID = D.ID  
		WHERE   
			NULLIF(LTRIM(RTRIM(HierarchyName)), N'') IS NOT NULL   
			AND	EXISTS (  
				SELECT Hierarchy_ID  
				FROM	mdm.tblSecurityRoleAccessMember sec  
				WHERE	Hierarchy_ID =H.ID   
				AND HierarchyType_ID = 0  
			);  
	END; --if  
  
	--Get Hierarchy List for Attributes that where staged.  
	IF @StagingType_ID IN (2,3,4) BEGIN  
		--Deadlock risk mitigated using an applock in the business rule code-generated procedure. See TFS 388360  
		EXEC mdm.udpSecurityMemberProcessRebuildModelVersion @Version_ID=@Version_ID, @ProcessNow = 0;	  
	END; --if  
  
	SET NOCOUNT OFF;  
END; --proc
GO
