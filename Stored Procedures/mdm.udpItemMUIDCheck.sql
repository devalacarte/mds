SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
declare @ret as INT  
exec mdm.udpItemMUIDCheck '0F700DE6-5182-4006-B84F-DE6AEE6D54EF', 7, @ret OUTPUT  
select @ret  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpItemMUIDCheck]  
(  
	@MUID			UNIQUEIDENTIFIER,  
	@ObjectType_ID	INT = NULL,	  
	@Return_ID		INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
/*  
    ObjectType_ID  
	--------------------------------------  
    Unknown = 0,  
    Model = 1,  
    DerivedHierarchy = 2,  
    DerivedHierarchyLevel = 3,  
    Version = 4,  
    Entity = 5,  
    Hierarchy = 6,  
    Attribute = 7,  
    AttributeGroup = 8,  
    StagingBatch = 9,  
    VersionFlag = 10  
  
	Returns  
	--------------------------------------  
	0: Item does not exist  
	1: Item does exist  
*/  
  
    --The ordering of the IF ELSE statements is to optimize on the frequency of @ObjectType_ID.  
	IF @ObjectType_ID = 7 -- Attribute  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ID FROM mdm.tblAttribute WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END	  
	ELSE IF @ObjectType_ID = 5 -- Entity  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ID FROM mdm.tblEntity WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END	  
	ELSE IF @ObjectType_ID = 6 -- Hierarchy  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ID FROM mdm.tblHierarchy WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END	  
	ELSE IF @ObjectType_ID = 8 -- Attribute Group  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ID FROM mdm.tblAttributeGroup WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END		  
	ELSE IF @ObjectType_ID = 2 -- Derived Hierarchy  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ID FROM mdm.tblDerivedHierarchy WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END  
	ELSE IF @ObjectType_ID = 3 -- Derived Hierarchy Level  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ID FROM mdm.tblDerivedHierarchyDetail WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END  
	ELSE IF @ObjectType_ID = 4 -- Version  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ID FROM mdm.tblModelVersion WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END	  
	ELSE IF @ObjectType_ID = 10 -- Version Flag  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ID FROM mdm.tblModelVersionFlag WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END  
	ELSE IF @ObjectType_ID = 1 --Model  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ID FROM mdm.tblModel WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END  
	ELSE IF @ObjectType_ID = 9 -- Staging Batch  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ID FROM mdm.tblStgBatch WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END  
	ELSE IF ISNULL(@ObjectType_ID, 0) = 0 -- Unknown, search all types.  NOTE: Next release we should raise an error instead.  
		BEGIN  
            SELECT @Return_ID = CASE WHEN EXISTS(SELECT ObjectID FROM mdm.viw_SYSTEM_SCHEMA_MUID WHERE MUID = @MUID) THEN 1 ELSE 0 END;  
		END  
  
	SET NOCOUNT OFF  
END --proc
GO
