SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	EXEC mdm.udpAttributeGroupDetailSave 1,1,0,1;  
	SELECT * FROM mdm.tblAttributeGroupDetail;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpAttributeGroupDetailSave]  
(  
   @User_ID				INT,  
   @AttributeGroup_ID   INT,  
   @ID					INT,  
   @Type_ID				INT, --Attributes = 1,Users = 2,UserGroups = 3  
   @ReturnID			INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @TempModel_ID		INT,  
			@TempEntity_ID		INT,  
			@TempMemberType_ID	TINYINT,  
			@TempVersion_ID		INT;  
  
	--Get Entity  
	SELECT @TempEntity_ID = Entity_ID, @TempMemberType_ID = MemberType_ID   
	FROM mdm.tblAttributeGroup   
	WHERE ID = @AttributeGroup_ID;  
  
	--Get MemberType_ID and latest Version  
	SELECT   
		@TempModel_ID = e.Model_ID,  
		@TempVersion_ID = MAX(mv.ID)   
	FROM mdm.tblModelVersion AS mv  
	INNER JOIN mdm.tblEntity AS e ON (mv.Model_ID = e.Model_ID)  
	WHERE e.ID = @TempEntity_ID  
	GROUP BY e.Model_ID;  
  
	IF @Type_ID = 1 BEGIN --Attributes  
  
		INSERT INTO mdm.tblAttributeGroupDetail  
			(AttributeGroup_ID,  
			Attribute_ID,  
			SortOrder,  
			EnterDTM,  
			EnterUserID,  
			EnterVersionID,  
			LastChgDTM,  
			LastChgUserID,  
			LastChgVersionID)  
	  
		SELECT  
			@AttributeGroup_ID,  
			@ID,  
			ISNULL(MAX(SortOrder),0) + 1,               
			GETUTCDATE(),  
			@User_ID,  
			@TempVersion_ID,  
			GETUTCDATE(),  
			@User_ID,  
			@TempVersion_ID  
			FROM  
				mdm.tblAttributeGroupDetail  
			WHERE  
				AttributeGroup_ID = @AttributeGroup_ID;  
  
			SET @ReturnID = SCOPE_IDENTITY();		  
  
	END ELSE IF @Type_ID = 2 BEGIN --Users  
  
		--Assign Read-Only privileges to the user  
		EXEC mdm.udpSecurityPrivilegesSave @User_ID, @ID, 1, Null, Null, Null, 5, 3, @TempModel_ID, @AttributeGroup_ID, '', Null;  
  
	END ELSE IF @Type_ID = 3 BEGIN --User Groups  
  
		--Assign Read-Only privileges to the user group  
		EXEC mdm.udpSecurityPrivilegesSave @User_ID, @ID, 2, Null, Null, Null, 5, 3, @TempModel_ID, @AttributeGroup_ID, '', Null;  
  
	END; --if  
  
	SET NOCOUNT OFF;  
END; --proc
GO
