SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
StagingType_ID  
0=Batch Information Only(NO DATA)  
1=MemberData  
2=AttributeData  
3=RelationshipData  
4=All Data  
  
EXEC mdm.udpStagingBatchGet 1,4,1,0  
  
NOTE: This sproc returns multiple recordsets  
*/  
CREATE PROCEDURE [mdm].[udpStagingBatchGet]  
(  
	@User_ID		INT,  
	@StagingType_ID	INT,   
	@Batch_ID		INT,  
	@Status_ID		TINYINT = NULL,  
	@BatchStatus_ID	TINYINT = NULL,  
	@PageSize       INT = NULL	  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
  
	SET NOCOUNT ON  
	  
	DECLARE @SQL        NVARCHAR(MAX),  
	        @ParamList  NVARCHAR(500);  
	   
	SET @SQL = ''  
	SET @ParamList = ''  
  
	-- Assemble the dynamic SQL for valid Staging Types  
	IF @StagingType_ID IN (1,2,3,4) BEGIN  
		  
		SET @SQL = N'SELECT ';  
		SET @ParamList = N'@Batch_ID INT, @BatchStatus_ID INT, @Status_ID INT'  
	  
		IF @PageSize IS NOT NULL AND @PageSize > 0   
			SET @SQL = @SQL + N'TOP ' + CONVERT(NVARCHAR(30), @PageSize)  
	END  
  
	IF @BatchStatus_ID <1 SET @BatchStatus_ID = NULL  
	  
	SELECT   
	B.ID  
    ,B.OriginalBatch_ID  
    ,B.MUID  
    ,B.Version_ID  
    ,B.ExternalSystem_ID  
    ,B.Name  
    ,B.Status_ID  
    ,B.TotalMemberCount  
    ,B.ErrorMemberCount  
    ,B.TotalMemberAttributeCount  
    ,B.ErrorMemberAttributeCount  
    ,B.TotalMemberRelationshipCount  
    ,B.ErrorMemberRelationshipCount  
    ,B.LastRunStartDTM  
    ,B.LastRunStartUserID  
    ,B.LastRunEndDTM  
    ,B.LastRunEndUserID  
    ,B.LastClearedDTM  
    ,B.LastClearedUserID  
    ,B.EnterDTM  
    ,B.EnterUserID  
	,E.MUID as ExternalSystem_MUID  
	,E.Name as ExternalSystem_Name  
	,M.MUID as ModelMUID  
	,M.Name as ModelName   
	,V.Name as VersionName  
	FROM mdm.tblStgBatch B   
		LEFT JOIN mdm.tblExternalSystem E ON E.ID=B.ExternalSystem_ID   
		INNER JOIN mdm.tblModelVersion V ON V.ID=B.Version_ID  
		INNER JOIN mdm.tblModel M ON M.ID=V.Model_ID  
	WHERE ((@Batch_ID IS NULL) OR (B.ID = @Batch_ID))  
		AND ((@BatchStatus_ID IS NULL) OR (B.Status_ID = @BatchStatus_ID) OR (@BatchStatus_ID = 6 AND B.Status_ID <> 5))  -- Status_ID 6 (Enum value - AllButCleared), Status_ID 5 (Enum value - Cleared)   
  
	IF @Status_ID <1 SET @Status_ID = NULL  
	  
	IF @StagingType_ID = 1  
		BEGIN  
			SET @SQL = @SQL + N'    
				''MEMBER'' as StagingRecordType,V.Name as VersionName,V.MUID as VersionMUID,ModelName,M.MUID as ModelMUID,HierarchyName,H.MUID as HierarchyMUID,EntityName,E.MUID as EntityMUID,    
				MemberName,MemberCode,S.MemberType_ID,null as AttributeName,null as AttributeMUID,null as AttributeValue,    
				null as TargetCode,null as TargetType_ID,S.Status_ID,S.ErrorCode     
			FROM mdm.tblStgMember S     
				INNER JOIN mdm.tblModel M ON M.[Name] = S.ModelName     
				INNER JOIN mdm.tblStgBatch B ON B.ID=S.Batch_ID    
				INNER JOIN mdm.tblModelVersion V ON B.Version_ID=V.ID    
				LEFT JOIN mdm.tblEntity E ON E.Name =S.EntityName AND E.Model_ID=M.ID     
				LEFT JOIN mdm.tblHierarchy H ON H.Name=S.HierarchyName AND H.Entity_ID=E.ID    
			WHERE ((@Batch_ID IS NULL) OR Batch_ID = @Batch_ID) AND ((@Status_ID IS NULL) OR (S.Status_ID = @Status_ID))    
					AND ((@BatchStatus_ID IS NULL) OR (B.Status_ID = @BatchStatus_ID) OR (@BatchStatus_ID = 6 AND B.Status_ID <> 5))'  
		END		  
  
	IF @StagingType_ID = 2  
		BEGIN  
			SET @SQL = @SQL + N'   
				''MEMBER_ATTRIBUTE'' as StagingRecordType,V.Name as VersionName,V.MUID as VersionMUID,ModelName,M.MUID as ModelMUID,null as HierarchyName,null  as HierarchyMUID,EntityName,E.MUID as EntityMUID,    
				null as MemberName,MemberCode,S.MemberType_ID,AttributeName,A.MUID as AttributeMUID,AttributeValue,    
				null as TargetCode,null as TargetType_ID,S.Status_ID,S.ErrorCode     
    
			FROM mdm.tblStgMemberAttribute S    
				INNER JOIN mdm.tblModel M ON M.[Name] = S.ModelName    
				INNER JOIN mdm.tblStgBatch B ON B.ID=S.Batch_ID    
				INNER JOIN mdm.tblModelVersion V ON B.Version_ID=V.ID    
				LEFT JOIN mdm.tblEntity E ON E.Name =S.EntityName AND E.Model_ID=M.ID     
				LEFT JOIN mdm.tblAttribute A ON A.Name=S.AttributeName AND E.ID=A.Entity_ID AND A.MemberType_ID=S.MemberType_ID    
			WHERE ((@Batch_ID IS NULL) OR Batch_ID = @Batch_ID) AND ((@Status_ID IS NULL) OR (S.Status_ID = @Status_ID))    
					AND ((@BatchStatus_ID IS NULL) OR (B.Status_ID = @BatchStatus_ID) OR (@BatchStatus_ID = 6 AND B.Status_ID <> 5))  -- Status_ID 6 (Enum value - AllButCleared), Status_ID 5 (Enum value - Cleared)'  
		END		  
  
	IF @StagingType_ID = 3  
		BEGIN  
			SET @SQL = @SQL + N'   
				''MEMBER_RELATIONSHIP'' as StagingRecordType,V.Name as VersionName,V.MUID as VersionMUID,ModelName,M.MUID as ModelMUID,HierarchyName,H.MUID as HierarchyMUID,EntityName,E.MUID as EntityMUID,    
				null as MemberName,MemberCode,S.MemberType_ID,null as AttributeName,null as AttributeMUID,null as AttributeValue,    
				TargetCode,TargetType_ID,S.Status_ID,S.ErrorCode     
			FROM mdm.tblStgRelationship S     
				INNER JOIN mdm.tblModel M ON M.[Name] = S.ModelName     
				INNER JOIN mdm.tblStgBatch B ON B.ID=S.Batch_ID    
				INNER JOIN mdm.tblModelVersion V ON B.Version_ID=V.ID    
				LEFT JOIN mdm.tblEntity E ON E.Name =S.EntityName AND E.Model_ID=M.ID     
				LEFT JOIN mdm.tblHierarchy H ON H.Name=S.HierarchyName AND H.Entity_ID=E.ID    
			WHERE ((@Batch_ID IS NULL) OR Batch_ID = @Batch_ID) AND ((@Status_ID IS NULL) OR (S.Status_ID = @Status_ID))    
					AND ((@BatchStatus_ID IS NULL) OR (B.Status_ID = @BatchStatus_ID) OR (@BatchStatus_ID = 6 AND B.Status_ID <> 5))  -- Status_ID 6 (Enum value - AllButCleared), Status_ID 5 (Enum value - Cleared)'  
	    END		  
  
	IF @StagingType_ID = 4  
		BEGIN  
			SET @SQL = @SQL + N'   
			StagingRecordType    
			,VersionName    
			,VersionMUID    
			,ModelName    
			,ModelMUID    
			,HierarchyName    
			,HierarchyMUID    
			,EntityName    
			,EntityMUID    
			,MemberName    
			,MemberCode    
			,MemberType_ID    
			,AttributeName    
			,AttributeMUID    
			,AttributeValue    
			,TargetCode    
			,TargetType_ID    
			,Status_ID    
			,ErrorCode     
			FROM    
			(    
			SELECT     
				''MEMBER'' as StagingRecordType,V.Name as VersionName,V.MUID as VersionMUID,ModelName,M.MUID as ModelMUID,HierarchyName,H.MUID as HierarchyMUID,EntityName,E.MUID as EntityMUID,    
				MemberName,MemberCode,S.MemberType_ID,null as AttributeName,null as AttributeMUID,null as AttributeValue,    
				null as TargetCode,null as TargetType_ID,S.Status_ID,S.ErrorCode    
			FROM mdm.tblStgMember S     
				INNER JOIN mdm.tblModel M ON M.[Name] = S.ModelName     
				INNER JOIN mdm.tblStgBatch B ON B.ID=S.Batch_ID    
				INNER JOIN mdm.tblModelVersion V ON B.Version_ID=V.ID    
				LEFT JOIN mdm.tblEntity E ON E.Name =S.EntityName AND E.Model_ID=M.ID     
				LEFT JOIN mdm.tblHierarchy H ON H.Name=S.HierarchyName AND H.Entity_ID=E.ID    
			WHERE ((@Batch_ID IS NULL) OR Batch_ID = @Batch_ID) AND ((@Status_ID IS NULL) OR (S.Status_ID = @Status_ID)) AND ((@BatchStatus_ID IS NULL) OR (B.Status_ID = @BatchStatus_ID) OR (@BatchStatus_ID = 6 AND B.Status_ID <> 5))  -- Status_ID 6 (Enum value - AllButCleared), Status_ID 5 (Enum value - Cleared)     
			UNION ALL    
			SELECT     
				''MEMBER_ATTRIBUTE'' as StagingRecordType,V.Name as VersionName,V.MUID as VersionMUID,ModelName,M.MUID as ModelMUID,null as HierarchyName,null as HierarchyMUID,EntityName,E.MUID as EntityMUID,    
				null as MemberName,MemberCode,S.MemberType_ID,AttributeName,A.MUID as AttributeMUID,AttributeValue,    
				null as TargetCode,null as TargetType_ID,S.Status_ID,S.ErrorCode    
    
			FROM mdm.tblStgMemberAttribute S    
				INNER JOIN mdm.tblModel M ON M.[Name] = S.ModelName    
				INNER JOIN mdm.tblStgBatch B ON B.ID=S.Batch_ID    
				INNER JOIN mdm.tblModelVersion V ON B.Version_ID=V.ID    
				LEFT JOIN mdm.tblEntity E ON E.Name =S.EntityName AND E.Model_ID=M.ID     
				LEFT JOIN mdm.tblAttribute A ON A.Name=S.AttributeName AND E.ID=A.Entity_ID AND A.MemberType_ID=S.MemberType_ID    
			WHERE ((@Batch_ID IS NULL) OR Batch_ID = @Batch_ID) AND ((@Status_ID IS NULL) OR (S.Status_ID = @Status_ID)) AND ((@BatchStatus_ID IS NULL) OR (B.Status_ID = @BatchStatus_ID) OR (@BatchStatus_ID = 6 AND B.Status_ID <> 5))  -- Status_ID 6 (Enum value - AllButCleared), Status_ID 5 (Enum value - Cleared)     
			UNION ALL    
			SELECT     
				''MEMBER_RELATIONSHIP'' as StagingRecordType,V.Name as VersionName,V.MUID as VersionMUID,ModelName,M.MUID as ModelMUID,HierarchyName,H.MUID as HierarchyMUID,EntityName,E.MUID as EntityMUID,    
				null as MemberName,MemberCode,S.MemberType_ID,null as AttributeName,null as AttributeMUID,null as AttributeValue,    
				TargetCode,TargetType_ID,S.Status_ID,S.ErrorCode    
			FROM mdm.tblStgRelationship S     
				INNER JOIN mdm.tblModel M ON M.[Name] = S.ModelName     
				INNER JOIN mdm.tblStgBatch B ON B.ID=S.Batch_ID    
				INNER JOIN mdm.tblModelVersion V ON B.Version_ID=V.ID    
				LEFT JOIN mdm.tblEntity E ON E.Name =S.EntityName AND E.Model_ID=M.ID     
				LEFT JOIN mdm.tblHierarchy H ON H.Name=S.HierarchyName AND H.Entity_ID=E.ID    
			WHERE ((@Batch_ID IS NULL) OR Batch_ID = @Batch_ID) AND ((@Status_ID IS NULL) OR (S.Status_ID = @Status_ID)) AND ((@BatchStatus_ID IS NULL) OR (B.Status_ID = @BatchStatus_ID) OR (@BatchStatus_ID = 6 AND B.Status_ID <> 5))  -- Status_ID 6 (Enum value - AllButCleared), Status_ID 5 (Enum value - Cleared)     
			) X ORDER BY X.EntityName,X.MemberCode'  
		END  
	  
	    -- execute the dynamic sql	  
    	EXEC sp_executesql @SQL, @ParamList, @Batch_ID, @BatchStatus_ID, @Status_ID  
  
	    SET NOCOUNT OFF  
END; --proc
GO
