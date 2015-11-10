SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Procedure  : mdm.udpHierarchyDerivedAncestorsGet  
Component  : Hierarchy Explorer  
Description: mdm.udpHierarchyDerivedAncestorsGet returns a list of ascendants associated with a specific member in a Derived Hierarchy  
Parameters : Version ID, Hierarchy ID, Member ID, Item_ID  
               Member ID represents the entity member ID or attribute member ID.  It is the "starting point" [of the hierarchy] to use when fetching the ancestors.  
               Item ID represents the entity ID or attribute ID corresponding to the Member_ID (-1 simulates leaf).  
               Item type ID represents the type of item: 0=Entity; 1=DBA; 2=Hierarchy; 3=Consolidated DBA (Common.HierarchyItemType)  
Return     : Table: Member ID (INT), Item_ID (INT), Object ID, Level number (TINYINT)  
               Object_ID references the values in mdm.tblSecurityObject and corresponds to the object type within the hierarchy: 3=Entity; 4=Attribute; 6=EXplicit Hierarchy.  
Example 1  : EXEC mdm.udpHierarchyDerivedAncestorsGet 20,  9, 265, 1, 32, 0  
SELECT * FROM mdm.viw_SYSTEM_7_9_PARENTCHILD_DERIVED  
*/  
  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpHierarchyDerivedAncestorsGet]  
(  
    @User_ID		INT,  
    @Version_ID		INT,  
    @Hierarchy_ID	INT,  
    @Member_ID		INT,  
	@MemberType_ID	INT,  
    @Item_ID		INT,  
	@ItemType_ID	INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
	  
    DECLARE @ParamList  NVARCHAR(MAX);  
    SET @ParamList = N'@Version_ID      INT  
                      ,@Member_ID		INT  
                      ,@MemberType_ID	INT  
                      ,@Item_ID			INT  
                      ,@ItemType_ID		INT';      
          
	DECLARE @SQL			NVARCHAR(MAX)  
	DECLARE @Model_ID	    INT  
	DECLARE @Entity_ID	    INT  
	DECLARE @viwHR			sysname  
	DECLARE @Level			SMALLINT    --Tracking variable  
  
	SELECT @Model_ID = Model_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID  
  
	SET @viwHR  = CAST(N'viw_SYSTEM_' + CAST(@Model_ID as NVARCHAR(10)) + N'_' +  CAST(@Hierarchy_ID as NVARCHAR(10)) + N'_PARENTCHILD_DERIVED' AS sysname)  
	SET @Level  = 0  
  
	--Temporary table to store list of ascendants (ancestors)  
	CREATE TABLE #tblAncestor (Parent_ID INT, ParentType_ID INT,Child_ID INT, ChildType_ID INT,Item_ID INT, ItemType_ID INT, ParentItem_ID INT, ParentItemType_ID INT,ChildEntity_MUID UNIQUEIDENTIFIER, ParentEntity_MUID UNIQUEIDENTIFIER, LevelNumber SMALLINT IDENTITY (0, 1),ParentCode NVARCHAR(250),ParentName NVARCHAR(250),Code NVARCHAR(250),[Name] NVARCHAR(250),Item_MUID UNIQUEIDENTIFIER,Privilege_ID INT)  
  
	--Top 1 is used because of Recursive Derived Hierarchies  
	--Insert base record  
	SET @SQL = N'  
		INSERT INTO #tblAncestor   
		SELECT TOP 1 Parent_ID, ParentType_ID, Child_ID, ChildType_ID, Item_ID, ItemType_ID, ParentItem_ID, ParentItemType_ID, Entity_MUID, ParentEntity_MUID, ParentCode, ParentName, ChildCode, ChildName, Item_MUID,-1  
		FROM mdm.' + quotename(@viwHR) + N'   
		WHERE Version_ID = @Version_ID   
		    AND Child_ID = @Member_ID   
		    AND ChildType_ID = @MemberType_ID   
		    AND Item_ID = @Item_ID  
		    AND ItemType_ID = @ItemType_ID  
		ORDER BY Child_ID;';	  
	--PRINT @SQL;		      
	EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Member_ID, @MemberType_ID, @Item_ID, @ItemType_ID;  
  
	--Collect ascendants (ancestors) of target member  
	WHILE EXISTS (SELECT 1 FROM #tblAncestor WHERE LevelNumber = @Level) AND @Level < 22 BEGIN  
		SELECT   
			  @Member_ID = Parent_ID  
		    , @MemberType_ID=ParentType_ID,@Item_ID = ParentItem_ID, @ItemType_ID = ParentItemType_ID   
		FROM #tblAncestor   
		WHERE LevelNumber = @Level;  
         	  
		IF @Member_ID=0 BREAK  
		SET @SQL = N'  
			INSERT INTO #tblAncestor   
			SELECT TOP 1 Parent_ID, ParentType_ID, Child_ID, ChildType_ID, Item_ID, ItemType_ID, ParentItem_ID, ParentItemType_ID, Entity_MUID, ParentEntity_MUID, ParentCode, ParentName, ChildCode, ChildName, Item_MUID,-1  
			FROM mdm.' + quotename(@viwHR) + N'   
			WHERE Version_ID = @Version_ID   
			    AND Child_ID = @Member_ID   
			    AND ChildType_ID = @MemberType_ID   
			    AND Item_ID = @Item_ID   
			    AND ItemType_ID = @ItemType_ID  
			 ORDER BY Child_ID;';  
		EXEC sp_executesql @SQL, @ParamList, @Version_ID, @Member_ID, @MemberType_ID, @Item_ID, @ItemType_ID;  
		SET @Level = @Level + 1;  
	END; --while  
  
	--Loop thru the temp table and look up the privilege  
	DECLARE @TempMember_ID INT  
	DECLARE @TempMemberType_ID INT  
	DECLARE @TempPrivilege_ID INT=0;  
	DECLARE @TempEntity_MUID UNIQUEIDENTIFIER  
	DECLARE @TempEntity_ID INT;  
	WHILE EXISTS (SELECT 1 FROM #tblAncestor WHERE Privilege_ID = -1)  
	BEGIN  
		SET @TempMember_ID = (SELECT TOP 1 Parent_ID from #tblAncestor WHERE Privilege_ID = -1 ORDER BY ParentCode);		  
		SET @TempEntity_MUID = (SELECT TOP 1 ParentEntity_MUID from #tblAncestor WHERE Privilege_ID = -1 ORDER BY ParentCode);  
		SET @TempEntity_ID = (SELECT ID FROM mdm.tblEntity WHERE MUID = @TempEntity_MUID);  
		SET @TempMemberType_ID = (SELECT TOP 1 ParentType_ID from #tblAncestor WHERE Privilege_ID = -1 ORDER BY ParentCode);	  
		EXEC mdm.udpSecurityMemberResolverGet @User_ID=@User_ID,@Version_ID=@Version_ID,@Hierarchy_ID=@Hierarchy_ID,@HierarchyType_ID=1,@Entity_ID=@TempEntity_ID,@Member_ID=@TempMember_ID,@MemberType_ID=@TempMemberType_ID,@Privilege_ID=@TempPrivilege_ID OUTPUT;  
		  
		IF @TempPrivilege_ID = 1 BREAK; --Once you have hit a denied member then exit as nothing else above can be visible  
  
		UPDATE #tblAncestor   
		SET Privilege_ID = @TempPrivilege_ID  
		WHERE   
		ISNULL(ParentEntity_MUID,0x0) = ISNULL(@TempEntity_MUID,0x0) --Logical Root has a null ParentMuid  
		AND ParentType_ID = @TempMemberType_ID  
		AND Parent_ID = @TempMember_ID  
	END  
  
	SELECT  
		Parent_ID as ID,  
		ParentType_ID as MemberType_ID,  
		ParentItem_ID as Item_ID,  
		ParentItemType_ID as ItemType_ID,  
		LevelNumber = ABS(ISNULL(LevelNumber, @Level) - @Level) - 1,  
		--New Columns For API - The ones above can be removed after the webui is converted to use API  
		ParentEntity_MUID,  
		ParentCode,  
		ParentName,  
		ParentType_ID,  
		ChildEntity_MUID,  
		ChildType_ID,  
		Code,  
		[Name],  
		Item_MUID AS RelationshipId,  
		ItemType_ID AS RelationshipTypeId,  
		Privilege_ID AS Privilege_ID  
	FROM   
		#tblAncestor  
	  
	WHERE  
			Privilege_ID > 0  
			  
	ORDER  BY   
		LevelNumber;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
