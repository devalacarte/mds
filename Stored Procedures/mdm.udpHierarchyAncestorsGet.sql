SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Procedure  : mdm.udpHierarchyAncestorsGet  
Component  : Hierarchy Explorer  
Description: mdm.udpHierarchyAncestorsGet returns a list of ascendants associated with a specific member  
Parameters : Version ID, Hierarchy ID, Member ID, Member type ID  
Return     : Table: Member ID (INT), MemberType_ID (INT), LevelNumber (TINYINT)  
Example 1  : EXEC mdm.udpHierarchyAncestorsGet 4, 6, 38, 1, 0  
Example 1  : EXEC mdm.udpHierarchyAncestorsGet 4, 6, 38, 1, 1  
*/  
  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpHierarchyAncestorsGet]  
(  
   @User_ID			INT,  
   @Version_ID		INT,  
   @Hierarchy_ID	INT,  
   @Member_ID		INT,  
   @MemberType_ID	TINYINT,  
   @IncludeSelf		BIT = 0,  
   @ReturnTree		BIT = 0  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @SQL			NVARCHAR(max)  
	DECLARE @Entity_ID		INT  
	DECLARE @Hierarchy_Muid	UNIQUEIDENTIFIER  
	DECLARE @Entity_Muid	UNIQUEIDENTIFIER  
	DECLARE @viwHR			sysname  
	DECLARE @Level			INT --Counter variable  
  
	SELECT @Entity_ID = Entity_ID,@Hierarchy_Muid=MUID FROM mdm.tblHierarchy WHERE ID = @Hierarchy_ID  
	SELECT @Entity_Muid = MUID FROM mdm.tblEntity WHERE ID=@Entity_ID  
	SELECT @viwHR = mdm.udfViewNameGetByID(@Entity_ID,4,0);   
	  
	--Temporary table to store list of ascendants (ancestors)  
	CREATE TABLE #tblAncestor (ParentID INT, MemberType_ID INT, LevelNumber SMALLINT,ParentCode NVARCHAR(250),ParentName NVarchar(250),Code NVarchar(250),[Name] NVarchar(250),Privilege_ID INT)  
  
	--Create base record  
	IF @IncludeSelf = 1 INSERT INTO #tblAncestor SELECT @Member_ID, @MemberType_ID, 0,'','','',''  
  
	--Create first level (if it exists)  
	SET @Level = 1  
	SET @SQL = N'  
		INSERT INTO #tblAncestor   
		SELECT Parent_ID, 2, 1,Parent_Code,Parent_Name,Child_Code,Child_Name,-1   
		FROM mdm.' + quotename(@viwHR) + N'  
		WHERE Version_ID = @Version_ID  
			AND Hierarchy_ID = @Hierarchy_ID  
			AND ChildType_ID = @MemberType_ID   
			AND ' + CASE @MemberType_ID WHEN 1 THEN N'Child_EN_ID' WHEN 2 THEN N'Child_HP_ID' END + N' = @Member_ID;';  
	EXEC sp_executesql @SQL,   
	    N'@Version_ID INT, @Hierarchy_ID INT, @Member_ID INT, @MemberType_ID TINYINT',   
	    @Version_ID, @Hierarchy_ID, @Member_ID, @MemberType_ID  
  
	--Collect ascendants (ancestors) of target member  
	WHILE EXISTS (SELECT 1 FROM #tblAncestor WHERE LevelNumber = @Level) AND @Level < 22 BEGIN  
		SET @SQL = N'  
			INSERT INTO #tblAncestor   
			SELECT DISTINCT Parent_ID, ChildType_ID,@Level+1, Parent_Code,Parent_Name,Child_Code,Child_Name,-1   
			FROM mdm.' + quotename(@viwHR) + N'  
			WHERE Version_ID = @Version_ID AND Hierarchy_ID = @Hierarchy_ID   
				AND ChildType_ID = 2 AND Child_HP_ID IN (SELECT ParentID FROM #tblAncestor WHERE LevelNumber = @Level);';  
		    
		  EXEC sp_executesql @SQL,   
		    N'@Version_ID INT, @Hierarchy_ID INT, @Level INT OUTPUT',   
		    @Version_ID, @Hierarchy_ID, @Level OUTPUT;  
		  SET @Level = @Level + 1;  
	END; --while  
	  
	--Loop thru the temp table and look up the privilege  
	DECLARE @TempMember_ID INT  
	DECLARE @TempMemberType_ID INT  
	DECLARE @TempPrivilege_ID INT=0;  
	WHILE EXISTS (SELECT 1 FROM #tblAncestor WHERE Privilege_ID = -1)  
	BEGIN		  
		SET @TempMember_ID = (SELECT TOP 1 ParentID from #tblAncestor WHERE Privilege_ID = -1);		  
		SET @TempMemberType_ID = (SELECT TOP 1 MemberType_ID from #tblAncestor WHERE Privilege_ID = -1);	  
		EXEC mdm.udpSecurityMemberResolverGet @User_ID=@User_ID,@Version_ID=@Version_ID,@Hierarchy_ID=@Hierarchy_ID,@HierarchyType_ID=0,@Entity_ID=@Entity_ID,@Member_ID=@TempMember_ID,@MemberType_ID=@TempMemberType_ID,@Privilege_ID=@TempPrivilege_ID OUTPUT;  
		  
		IF @TempPrivilege_ID = 1 BREAK; --Once you have hit a denied member then exit as nothing else above can be visible  
		  
		UPDATE #tblAncestor SET Privilege_ID = @TempPrivilege_ID  
		WHERE   
		MemberType_ID = @TempMemberType_ID  
		AND ISNULL(ParentID,0) = ISNULL(@TempMember_ID,0)  
	END  
	  
	IF @ReturnTree = 1  
	BEGIN  
		SELECT 			   
			@Member_ID MemberID,  
			@MemberType_ID MemberTypeID,  
			ParentID AncestorID,   
			2 AncestorMemberTypeID,  
			ABS(LevelNumber-@Level)-2 LevelNumber  
		FROM   
			#tblAncestor  
		ORDER BY   
			LevelNumber  
	END  
	ELSE  
	BEGIN  
		SELECT   
			ParentID as ID,   
			MemberType_ID,   
			Object_ID = CASE MemberType_ID WHEN 1 THEN 8 WHEN 2 THEN 9 WHEN 3 THEN 10 ELSE 0 END,  
			ABS(LevelNumber-@Level)-2 LevelNumber,  
			--New Columns For API - The ones above can be removed after the webui is converted to use API  
			ParentCode,  
			ParentName,  
			2 AS ParentType_ID,  
			@Entity_Muid as ParentEntity_MUID,		   
			Code,  
			[Name],  
			MemberType_ID AS ChildType_ID,  
			@Entity_Muid AS ChildEntity_MUID,  
			@Hierarchy_Muid AS RelationShipId,  
			2 AS RelationShipTypeId, --2 is Hierarchy  
			Privilege_ID AS Privilege_ID		   
		FROM   
			#tblAncestor  
		WHERE  
			Privilege_ID > 0  
		ORDER BY   
			LevelNumber  
	END  
	  
	  
  
	DROP TABLE #tblAncestor  
  
	SET NOCOUNT OFF  
END --proc
GO
