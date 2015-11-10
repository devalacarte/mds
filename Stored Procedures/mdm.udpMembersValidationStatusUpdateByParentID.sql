SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpMembersValidationStatusUpdateByParentID 11,13,1,4  
exec mdm.udpMembersValidationStatusUpdateByParentID 29,19,3,5  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMembersValidationStatusUpdateByParentID]  
(  
	@Entity_ID				INT,  
	@Version_ID		   		INT,  
	@Parent_ID				INT,  
	@ValidationStatus_ID 	INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	-- Update the all member records, for all membertypes, for non-committed versions, for the specified Entity and Apex Member_ID.  
	DECLARE   
		 @ChildEntityID			INT  
		,@ChildAttributeName	sysname  
		,@ChildEntityTable		sysname  
		,@SQL					NVARCHAR(MAX)  
		,@tblEN					sysname;		--Entity table  
  
	CREATE	TABLE #Entity	  
	(  
		ID INT IDENTITY (1, 1) NOT NULL,   
		EntityID int,  
		EntityName NVARCHAR(250) COLLATE database_default,  
		AttributeName sysname COLLATE database_default NULL,  
		ChildEntityID int NULL,  
		ChildEntityMemberTypeID int NULL,  
		ChildEntityName NVARCHAR(250) COLLATE database_default NULL,  
		ChildAttributeName sysname COLLATE database_default NULL,  
		ProcessSeq int  
	);  
  
	INSERT INTO #Entity  
	EXEC mdm.udpEntitiesGetByValidationProcessSeq NULL, @Entity_ID;  
  
	SELECT	  
		@ChildEntityID = ChildEntityID,  
		@ChildAttributeName = ChildAttributeName    
	FROM  
		#Entity;  
  
	IF @ChildEntityID IS NOT NULL BEGIN  
	  
		SELECT   
			@tblEN = mdm.udfTableNameGetByID(@Entity_ID, 1),  
			@ChildEntityTable = mdm.udfTableNameGetByID(@ChildEntityID, 1);  
  
		SELECT @SQL = N'  
			UPDATE mdm.' + quotename(@ChildEntityTable) + N' SET  
				ValidationStatus_ID = @ValidationStatus_ID  
			FROM mdm.' + quotename(@ChildEntityTable) + N' AS t  
			INNER JOIN mdm.tblModelVersion AS v   
				ON t.Version_ID = v.ID   
			WHERE	  
				v.ID = @Version_ID  
				AND v.Status_ID <> 3  
				AND t.ValidationStatus_ID <> @ValidationStatus_ID  
				AND t.' + quotename(@ChildAttributeName) + N' = @Parent_ID;  
			 ';  
  
		--PRINT @SQL;  
		EXEC sp_executesql @SQL, N'@Version_ID INT, @ValidationStatus_ID INT, @Parent_ID INT', @Version_ID, @ValidationStatus_ID, @Parent_ID;  
  
	END; --if  
  
	SET NOCOUNT OFF;  
END; --proc
GO
