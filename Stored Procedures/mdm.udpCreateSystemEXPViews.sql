SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	--Create for All Entities  
	DECLARE @Entities TABLE(ID INT)  
	DECLARE @EntityID INT  
	INSERT INTO @Entities SELECT ID FROM mdm.tblEntity ORDER BY ID  
	WHILE(SELECT COUNT(*) FROM @Entities) <> 0  
	BEGIN  
		SELECT TOP 1 @EntityID = ID FROM @Entities  
		EXEC mdm.udpCreateSystemEXPViews @EntityID,1  
		EXEC mdm.udpCreateSystemEXPViews @EntityID,2  
		EXEC mdm.udpCreateSystemEXPViews @EntityID,3  
		DELETE FROM @Entities WHERE ID=@EntityID  
	END  
  
	--account  
	EXEC mdm.udpCreateSystemEXPViews 41,1;  
	EXEC mdm.udpCreateSystemEXPViews 7,2;  
	EXEC mdm.udpCreateSystemEXPViews 7,3;  
  
	exec mdm.udpcreateallviews  
  
	--vld Branch  
	SELECT top 100 * FROM mdm.viw_SYSTEM_8_41_CHILDATTRIBUTES_EXP WHERE Version_ID = 21 ORDER BY Code  
  
	-_Account  
	SELECT * FROM mdm.viw_SYSTEM_2_7_CHILDATTRIBUTES_EXP WHERE Version_ID=4 order by Code;  
	SELECT * FROM mdm.viw_SYSTEM_2_9_CHILDATTRIBUTES_EXP WHERE Version_ID=4 order by Code;  
	  
	SELECT * FROM mdm.viw_SYSTEM_2_7_PARENTATTRIBUTES_EXP;  
	SELECT * FROM mdm.viw_SYSTEM_2_7_COLLECTIONATTRIBUTES_EXP;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpCreateSystemEXPViews]   
(  
	@EntityID			INT,  
	@MemberTypeID		TINYINT  
)   
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	--Defer view generation if we are in the middle of an upgrade or demo-rebuild  
	IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
		DECLARE @EntityViewName					sysname,  
				@ParentChildViewName			sysname,  
				@CollectionParentChildViewName	sysname,  
				@ViewName						sysname,  
				@SQL							NVARCHAR(MAX),  
				@MemberType						NVARCHAR(50);  
  
		--Check to see if you are trying to create Parent/Collection Attributes view on a flat entity. If so exit.  
		IF EXISTS(SELECT 1 FROM mdm.tblEntity WHERE ID = @EntityID AND IsFlat = 1 AND @MemberTypeID IN (2, 3)) RETURN(0);  
  
		--Get the view names  
		SELECT   
			@EntityViewName = mdm.udfViewNameGetByID(@EntityID, @MemberTypeID, 0),  
			@ParentChildViewName = mdm.udfViewNameGetByID(@EntityID, 4, 1),  
			@CollectionParentChildViewName = mdm.udfViewNameGetByID(@EntityID, 5, 1),  
			@ViewName = mdm.udfViewNameGetByID(@EntityID, @MemberTypeID, 4);  
		SELECT @MemberType = CONVERT(NVARCHAR(50),@MemberTypeID);  
  
		SET @SQL = N'  
			SELECT   
				 T.*				  
				,T.[Name]				AS [Member_Name]  
				,T.Code				AS [Member_Code]';  
  
		IF EXISTS(SELECT IsFlat FROM mdm.tblEntity WHERE ID = @EntityID AND IsFlat = 0) AND @MemberTypeID IN (1,2) BEGIN  
			SET @SQL = @SQL + N'  
				,PDL.*  
				,CDL.Parent_Code as Collection_Code  
				,CDL.Parent_Name as Collection_Name  
				,CDL.SortOrder AS Collection_SortOrder  
                ,CDL.[Weight] AS Collection_Weight';  
		END   
		ELSE IF EXISTS(SELECT IsFlat FROM mdm.tblEntity WHERE ID = @EntityID AND IsFlat = 0) AND @MemberTypeID =3 BEGIN  
			SET @SQL = @SQL + N'  
				,NULL AS Parent_Code  
				,NULL AS Parent_Name  
				,NULL AS Parent_HierarchyMuid  
				,NULL AS Parent_HierarchyName  
				,CDL.Parent_Code AS Collection_Code  
				,CDL.Parent_Name AS Collection_Name  
                ,CDL.SortOrder AS Collection_SortOrder  
                ,CDL.[Weight] AS Collection_Weight';  
		END   
		ELSE BEGIN  
			SET @SQL = @SQL + N'  
				,NULL AS Parent_Code  
				,NULL AS Parent_Name  
				,NULL AS Parent_HierarchyMuid  
				,NULL AS Parent_HierarchyName  
				,NULL AS Collection_Code  
				,NULL AS Collection_Name  
                ,NULL AS Collection_SortOrder  
                ,NULL AS Collection_Weight';  
		END; --if  
  
		SET @SQL = @SQL + N'  
			FROM   
				mdm.' + quotename(@EntityViewName) + ' AS T';  
		  
		IF EXISTS(SELECT 1 FROM mdm.tblEntity WHERE ID = @EntityID AND IsFlat = 0) AND @MemberTypeID IN (1,2) BEGIN  
			SET @SQL = @SQL + N'	  
			OUTER APPLY (  
				SELECT   
					Parent_Code			AS [Parent_Code],  
					Parent_Name			AS [Parent_Name],  
					Hierarchy_MUID		AS [Parent_HierarchyMuid],   
					Hierarchy_Name		AS [Parent_HierarchyName],  
					Hierarchy_ID		AS [Parent_HierarchyId],  
					Child_SortOrder     AS [Child_SortOrder]  
				FROM  
					mdm.' + quotename(@ParentChildViewName) + N'  
				WHERE   
					Version_ID = T.Version_ID AND   
					T.ID = ' + CASE @MemberTypeID WHEN 1 THEN + ' Child_EN_ID ' WHEN 2 THEN + ' Child_HP_ID ' WHEN 3 THEN + ' Child_EN_ID ' END + N' AND   
					ChildType_ID = ' + CONVERT(NVARCHAR(30), @MemberTypeID) + N'  
				--FOR XML PATH (N''Parent''), ELEMENTS, TYPE  
			) AS PDL --PDL(XmlColumn);'  
		END;  
			IF EXISTS(SELECT 1 FROM mdm.tblEntity WHERE ID = @EntityID AND IsFlat = 0) BEGIN  
			SET @SQL = @SQL + N'	  
			LEFT JOIN  
					mdm.' + quotename(@CollectionParentChildViewName) + N' CDL  
					ON   
					CDL.Version_ID = T.Version_ID AND   
					T.ID = ' + CASE @MemberTypeID WHEN 1 THEN + ' CDL.Child_EN_ID ' WHEN 2 THEN + ' CDL.Child_HP_ID ' WHEN 3 THEN + ' CDL.Child_CN_ID ' END + N' AND   
					CDL.ChildType_ID = ' + CONVERT(NVARCHAR(30), @MemberTypeID) + N'  
				';  
		END; --if  
  
		--Alter or create the view	  
		SET @SQL = CASE  
			WHEN EXISTS(SELECT 1 FROM sys.views WHERE [name] = @ViewName AND [schema_id] = schema_id(N'mdm')) THEN N'ALTER'  
			ELSE N'CREATE'  
		END + N' VIEW mdm.' + quotename(@ViewName) + N'  
			/*WITH ENCRYPTION*/ AS'  
			+ @SQL;  
  
		--PRINT @SQL;  
		EXEC sp_executesql @SQL;  
  
	END; --if  
  
	SET NOCOUNT OFF;  
END --proc
GO
