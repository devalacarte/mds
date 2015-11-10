SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
	EXEC mdm.udpSecurityRoleAccessMemberCopy 1, 2, 3  
*/  
CREATE PROCEDURE [mdm].[udpSecurityRoleAccessMemberCopy]  
(  
	@User_ID				INT,  
    @SourceVersion_ID		INT,		--Version to copy security assignments from  
    @TargetVersion_ID		INT,		--Version to copy security assignments to  
    @MapMembersByID			BIT = 0,	--Default is to join by [Code], but permit joining on [AsOf_ID] too  
    @DeleteTarget			BIT = 0,	--If true, delete all target rows before copying source rows  
    @IgnoreLeastPrivilege	BIT = 0		--If false, only overwrites if new value is stronger than old value  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
	  
	DECLARE   
		@i					INT,  
		@Entity_ID			INT,  
		@MemberType_ID		TINYINT,  
		@SQL				NVARCHAR(MAX);  
	  
	/*=================================================================    
	  Validate parameters  
	  =================================================================*/  
	    
	IF	@SourceVersion_ID IS NULL   
		OR @TargetVersion_ID IS NULL  
		OR @User_ID IS NULL --Ensure required parameters are provided  
		OR NOT EXISTS  
		(  
			SELECT 1 FROM mdm.tblModelVersion AS v1  
			INNER JOIN mdm.tblModelVersion AS v2 ON (v1.Model_ID = v2.Model_ID) --Ensure both Versions in same Model  
			WHERE v1.ID = @SourceVersion_ID --Ensure Version 1 exists  
			AND v2.ID = @TargetVersion_ID --Ensure Version 2 exists  
			AND v1.ID <> v2.ID --Ensure this is not a self-copy  
		)  
		OR NOT EXISTS  
		(  
			SELECT 1 FROM mdm.tblUser WHERE ID = @User_ID --Ensure User exists  
		)  
	BEGIN  
		RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
		RETURN(1);  
	END; --if  
	  
	--Set parameter defaults  
	SELECT   
		@DeleteTarget = ISNULL(@DeleteTarget, 0),   
		@IgnoreLeastPrivilege = ISNULL(@IgnoreLeastPrivilege, 0),  
		@MapMembersByID = ISNULL(@MapMembersByID, 0);  
  
  
	/*=================================================================    
	  Initialize structures  
	  =================================================================*/  
	  
	CREATE TABLE #sram  
	(  
		   Role_ID                      INT NOT NULL,  
		   Privilege_ID					INT NOT NULL,  
		   [Object_ID]					INT NOT NULL,  
		   Entity_ID                    INT NOT NULL,  
		   HierarchyType_ID				TINYINT NOT NULL,  
		   ExplicitHierarchy_ID			INT NULL,  
		   DerivedHierarchy_ID			INT NULL,  
		   Hierarchy_ID					INT NOT NULL,  
		   Item_ID                      INT NOT NULL,  
		   ItemType_ID                  TINYINT NOT NULL,  
		   MemberType_ID				TINYINT NOT NULL,  
		   Member_ID                    INT NOT NULL,  
		   [Description]				NVARCHAR(250) NULL,  
		   MappedMember_ID				INT NULL --Place holder for mapped member ID  
	);  
  
	--Copy all SRAM rows related to the Source Version into a working table  
	INSERT INTO #sram  
	SELECT  
		Role_ID, Privilege_ID, [Object_ID], Entity_ID,   
		HierarchyType_ID, ExplicitHierarchy_ID, DerivedHierarchy_ID, Hierarchy_ID,  
		Item_ID, ItemType_ID, MemberType_ID, Member_ID,   
		[Description],   
		CASE Member_ID WHEN 0 THEN 0 ELSE NULL END --Map virtual roots directly (0-->0)  
	FROM mdm.tblSecurityRoleAccessMember  
	WHERE Version_ID = @SourceVersion_ID; --We are copying the source Version only  
  
  
	/*=================================================================    
	  Map Members across Versions using [Code] or [AsOf_ID]  
	  =================================================================*/  
  
	--Declare & populate loop counter  
	DECLARE @loop TABLE(ID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY CLUSTERED, Entity_ID INT NOT NULL, MemberType_ID TINYINT NOT NULL);  
	INSERT INTO @loop(Entity_ID, MemberType_ID)   
	SELECT DISTINCT Entity_ID, MemberType_ID   
	FROM #sram;  
		  
	--Map each member in the old Version to the same member in the new Version  
	WHILE EXISTS(SELECT 1 FROM @loop) BEGIN  
		SELECT TOP 1 @i = ID, @Entity_ID = Entity_ID, @MemberType_ID = MemberType_ID FROM @loop ORDER BY ID;  
		  
		SET @SQL = N'  
			UPDATE #sram SET   
				MappedMember_ID = en2.ID  
			FROM #sram AS sram  
			INNER JOIN mdm.' + quotename(mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID)) + N' AS en1 ON  
				sram.Member_ID = en1.ID  
			INNER JOIN mdm.' + quotename(mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID)) + N' AS en2 ON  
				' + CASE @MapMembersByID   
						--Either map members using [Code]-->[Code]		  
						WHEN 0 THEN 'en1.[Code] = en2.[Code]'  
						--Else map members using [AsOf_ID]-->[ID]  
						ELSE '(en1.ID = en2.AsOf_ID) OR (en2.ID = en1.AsOf_ID)'  
					END + N'  
			WHERE  
				sram.Entity_ID = @Entity_ID AND  
				sram.MemberType_ID = @MemberType_ID AND  
				sram.Member_ID > 0 AND	--The virtual roots have already been mapped (0-->0)  
				en1.Version_ID = @SourceVersion_ID AND	--Source Version  
				en2.Version_ID = @TargetVersion_ID AND	--Target Version  
				en1.Status_ID = 1 AND en2.Status_ID = 1	--Non-deleted members  
			;';  
		  
		--PRINT @SQL;		  
		EXEC sp_executesql @SQL, N'@SourceVersion_ID INT, @TargetVersion_ID INT, @Entity_ID INT, @MemberType_ID TINYINT', @SourceVersion_ID, @TargetVersion_ID, @Entity_ID, @MemberType_ID;  
	  
		DELETE @loop WHERE ID = @i;  
	END; --while	  
	  
		  
	/*=================================================================    
	  Do the copy operation  
	  =================================================================*/  
	  
	--Perform a MERGE operation  
	MERGE INTO mdm.tblSecurityRoleAccessMember AS dest	  
	--Only copy rows that we managed to map successfully  
	USING (SELECT * FROM #sram WHERE MappedMember_ID IS NOT NULL) AS src  
	--Match criteria is a compound key over (Version, Entity, Hierarchy, Role, Mapped/Member)  
	ON   
	(	dest.Version_ID = @TargetVersion_ID AND --Make sure we're updating the target Version only  
		dest.Entity_ID = src.Entity_ID AND  
		dest.HierarchyType_ID = src.HierarchyType_ID AND   
		dest.Hierarchy_ID = src.Hierarchy_ID AND  
		dest.Role_ID = src.Role_ID AND  
		dest.Member_ID = src.MappedMember_ID --Make sure we're joining on the mapped member  
	)  
	--When a row exists in both the source and the target  
	WHEN MATCHED   
		--And the Privilege_ID values do not already match (performance optimization)  
		AND (src.Privilege_ID <> dest.Privilege_ID)  
		--Then UPDATE the destination Privilege_ID as follows:  
		THEN UPDATE SET   
			dest.Privilege_ID = CASE  
				--If DeleteTarget=T then overwrite blindly  
				WHEN @DeleteTarget = 1 THEN src.Privilege_ID  
				--If DeleteTarget=F AND Ignore=T then overwrite blindly				  
				WHEN @DeleteTarget = 0 AND @IgnoreLeastPrivilege = 1 THEN src.Privilege_ID  
				--If DeleteTarget=F AND Ignore=F then...  
				WHEN @DeleteTarget = 0 AND @IgnoreLeastPrivilege = 0 THEN CASE  
					--Deny always wins  
					WHEN src.Privilege_ID = 1 OR dest.Privilege_ID = 1 THEN 1  
					--Else ReadOnly wins  
					WHEN src.Privilege_ID = 3 OR dest.Privilege_ID = 3 THEN 3  
					--Else it must be ReadWrite  
					ELSE 2  
				END --case  
			END, --case  
			--Reset the Description  
			[Description] = NULL,  
			--Force reprocess to happen later  
			IsInitialized = 0,  
			--Update audit trail  
			LastChgDTM = GETDATE(),  
			LastChgUserID = @User_ID  
	--When a row exists in the source but not the target:  
	WHEN NOT MATCHED BY TARGET  
		--Then INSERT a new row as follows:  
		THEN INSERT  
		(  
			Role_ID, Privilege_ID, [Object_ID],   
			Version_ID, Entity_ID,   
			HierarchyType_ID, ExplicitHierarchy_ID, DerivedHierarchy_ID,   
			Item_ID, ItemType_ID,   
			[Description],   
			MemberType_ID, Member_ID,  
			EnterUserID, LastChgUserID  
		)  
		VALUES  
		(  
			src.Role_ID, src.Privilege_ID, src.[Object_ID],   
			@TargetVersion_ID, src.Entity_ID,   
			src.HierarchyType_ID, src.ExplicitHierarchy_ID, src.DerivedHierarchy_ID,   
			src.Item_ID, src.ItemType_ID,   
			NULL, --Reset the Description  
			src.MemberType_ID, src.MappedMember_ID,  
			@User_ID, @User_ID  
		)  
	--When a row exists in the target but not the source then:  
	WHEN NOT MATCHED BY SOURCE  
		--If and only if DeleteTarget=T then DELETE the target row  
		AND @DeleteTarget = 1 THEN DELETE  
		--Else leave the target row in place  
	;  
  
	--Return the number of rows affected	  
	PRINT @@ROWCOUNT;  
	  
	SET NOCOUNT OFF;  
END; --proc
GO
