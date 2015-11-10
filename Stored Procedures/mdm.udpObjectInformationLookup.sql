SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	--Model (ObjectTypeID = 1)  
	DECLARE @ID INT, @Name NVARCHAR(MAX), @MUID UniqueIdentifier, @PrivilegeID INT;	  
	EXEC mdm.udpObjectInformationLookup   
		 @UserID			= 1  
		,@ObjectMUID		= NULL  
		,@ObjectID			= NULL  
		,@ObjectName		= 'Product'  
		,@ObjectTypeID		= 1  
		,@ObjectSubTypeID	= NULL  
		,@ParentObjectID	= NULL  
		,@ParentObjectMUID	= NULL  
		,@ID				= @ID			OUTPUT  
		,@Name				= @Name			OUTPUT  
		,@MUID				= @MUID			OUTPUT  
		,@PrivilegeID		= @PrivilegeID	OUTPUT		  
	SELECT @ID, @Name, @MUID, @PrivilegeID;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpObjectInformationLookup]  
(  
	@UserID				INT = NULL,  
	@ObjectMUID			UNIQUEIDENTIFIER = NULL,	--\  
	@ObjectID			INT = NULL,					--One of these 3 always required  
	@ObjectName			NVARCHAR(MAX) = NULL,		--/  
	@ObjectTypeID		TINYINT,					--Always required value  
	@ObjectSubTypeID	INTEGER=NULL,				--Not Required.  Only used for ObjectType of 4 and 6  
	@ParentObjectID		INT = NULL,					--\ One of these always required (except Model)  
	@ParentObjectMUID	UNIQUEIDENTIFIER = NULL,	--/  
	@ID					INTEGER = NULL OUTPUT,  
	@Name				NVARCHAR(MAX) = NULL OUTPUT,  
	@MUID				UNIQUEIDENTIFIER = NULL OUTPUT,  
	@PrivilegeID		INTEGER = NULL OUTPUT  
)  
WITH EXECUTE AS CALLER  
AS BEGIN  
	SET NOCOUNT ON;  
	  
/*  
    ObjectType_ID  
	--------------------------------------  
    Unknown = 0,  
    Model = 1,  
    DerivedHierarchy = 2,  
    DerivedHierarchyDetail = 3,  
    Version = 4,  
    Entity = 5,  
    Hierarchy = 6,  
    Attribute = 7,  
    AttributeGroup = 8,  
    StagingBatch = 9,  
    VersionFlag = 10,  
    ExportView = 20  
  
	IF @ObjectSubType_ID IS NULL SET @ObjectSubType_ID =1  --If there is a SubType, default to 1 (Leaf)  
	IF @User_ID IS NULL SET @User_ID =0  
*/	  
  
	IF @ObjectTypeID = 1 --Model  
		BEGIN  
			EXEC mdm.udpInformationLookupModel 	  
					 @User_ID		= @UserID		  
					,@Model_MUID	= @ObjectMUID	  
					,@Model_ID		= @ObjectID  
					,@Model_Name	= @ObjectName  
					,@ID			= @ID			OUTPUT  
					,@Name			= @Name			OUTPUT  
					,@MUID			= @MUID			OUTPUT  
					,@Privilege_ID	= @PrivilegeID	OUTPUT  
		END  
	ELSE IF @ObjectTypeID = 2 -- Derived Hierarchy  
		BEGIN  
			EXEC mdm.udpInformationLookupDerivedHierarchy  
					 @User_ID				= @UserID						  
					,@DerivedHierarchy_MUID	= @ObjectMUID				  
					,@DerivedHierarchy_ID	= @ObjectID				  
					,@DerivedHierarchy_Name	= @ObjectName				  
					,@Model_ID				= @ParentObjectID			  
					,@Model_MUID			= @ParentObjectMUID		  
					,@ID					= @ID			OUTPUT	 					  
					,@Name					= @Name			OUTPUT				  
					,@MUID					= @MUID			OUTPUT				  
					,@Privilege_ID			= @PrivilegeID	OUTPUT			  
		END  
	ELSE IF @ObjectTypeID = 3 -- Derived Hierarchy Detail  
		BEGIN  
		 EXEC mdm.udpInformationLookupDerivedHierarchyDetail	  
				 @DerivedHierarchyDetail_MUID	= @ObjectMUID  
				,@DerivedHierarchyDetail_ID		= @ObjectID  
				,@DerivedHierarchyDetail_Name	= @ObjectName  
				,@DerivedHierarchy_ID			= @ParentObjectID			  
				,@DerivedHierarchy_MUID			= @ParentObjectMUID		  
				,@ID							= @ID			OUTPUT	 					  
				,@Name							= @Name			OUTPUT				  
				,@MUID							= @MUID			OUTPUT				  
				,@Privilege_ID					= @PrivilegeID	OUTPUT			  
		END  
	ELSE IF @ObjectTypeID = 4 -- Version  
		BEGIN  
			EXEC mdm.udpInformationLookupVersion  
				 @User_ID		= @UserID	  
				,@Version_MUID	= @ObjectMUID				  
				,@Version_ID	= @ObjectID				  
				,@Version_Name	= @ObjectName				  
				,@Model_ID		= @ParentObjectID			  
				,@Model_MUID	= @ParentObjectMUID		  
				,@ID			= @ID			OUTPUT	 					  
				,@Name			= @Name			OUTPUT				  
				,@MUID			= @MUID			OUTPUT				  
				,@Privilege_ID	= @PrivilegeID	OUTPUT	  
		END	  
	ELSE IF @ObjectTypeID = 5 -- Entity  
		BEGIN  
			EXEC  mdm.udpInformationLookupEntity  
					 @User_ID		= @UserID						  
					,@Entity_MUID	= @ObjectMUID				  
					,@Entity_ID		= @ObjectID				  
					,@Entity_Name	= @ObjectName				  
					,@MemberType_ID = @ObjectSubTypeID		  
					,@Model_ID		= @ParentObjectID			  
					,@Model_MUID	= @ParentObjectMUID		  
					,@ID			= @ID			OUTPUT	 					  
					,@Name			= @Name			OUTPUT				  
					,@MUID			= @MUID			OUTPUT				  
					,@Privilege_ID	= @PrivilegeID	OUTPUT			  
		END	  
	ELSE IF @ObjectTypeID = 6 -- Hierarchy  
		BEGIN  
			EXEC  mdm.udpInformationLookupHierarchy  
					 @User_ID			= @UserID						  
					,@Hierarchy_MUID	= @ObjectMUID				  
					,@Hierarchy_ID		= @ObjectID				  
					,@Hierarchy_Name	= @ObjectName					  
					,@Entity_ID			= @ParentObjectID			  
					,@Entity_MUID		= @ParentObjectMUID		  
					,@ID				= @ID			OUTPUT	 					  
					,@Name				= @Name			OUTPUT				  
					,@MUID				= @MUID			OUTPUT				  
					,@Privilege_ID		= @PrivilegeID	OUTPUT			  
		END	  
	ELSE IF @ObjectTypeID = 7 -- Attribute  
		BEGIN  
			EXEC  mdm.udpInformationLookupAttribute  
					@User_ID			= @UserID						  
					,@Attribute_MUID	= @ObjectMUID				  
					,@Attribute_ID		= @ObjectID				  
					,@Attribute_Name	= @ObjectName				  
					,@MemberType_ID		= @ObjectSubTypeID		  
					,@Entity_ID			= @ParentObjectID			  
					,@Entity_MUID		= @ParentObjectMUID		  
					,@ID				= @ID			OUTPUT	 					  
					,@Name				= @Name			OUTPUT				  
					,@MUID				= @MUID			OUTPUT				  
					,@Privilege_ID		= @PrivilegeID	OUTPUT			  
		END	  
	ELSE IF @ObjectTypeID = 8 -- Attribute Group  
		BEGIN  
			EXEC  mdm.udpInformationLookupAttributeGroup  
					 @User_ID				= @UserID						  
					,@AttributeGroup_MUID	= @ObjectMUID				  
					,@AttributeGroup_ID		= @ObjectID				  
					,@AttributeGroup_Name	= @ObjectName					  
					,@Entity_ID				= @ParentObjectID			  
					,@Entity_MUID			= @ParentObjectMUID		  
					,@ID					= @ID			OUTPUT	 					  
					,@Name					= @Name			OUTPUT				  
					,@MUID					= @MUID			OUTPUT				  
					,@Privilege_ID			= @PrivilegeID	OUTPUT			  
		END		  
	ELSE IF @ObjectTypeID = 9 -- Staging Batch  
		BEGIN  
			EXEC  mdm.udpInformationLookupStagingBatch  
					 @StagingBatch_MUID	= @ObjectMUID				  
					,@StagingBatch_ID	= @ObjectID				  
					,@StagingBatch_Name	= @ObjectName				  
					,@ID				= @ID			OUTPUT	 					  
					,@Name				= @Name			OUTPUT				  
					,@MUID				= @MUID			OUTPUT				  
					,@Privilege_ID		= @PrivilegeID	OUTPUT			  
		END  
	ELSE IF @ObjectTypeID = 10 -- Version Flag  
		BEGIN  
			EXEC  mdm.udpInformationLookupVersionFlag  
					 @User_ID			= @UserID						  
					,@VersionFlag_MUID	= @ObjectMUID				  
					,@VersionFlag_ID	= @ObjectID				  
					,@VersionFlag_Name	= @ObjectName				  
					,@Model_ID			= @ParentObjectID			  
					,@Model_MUID		= @ParentObjectMUID		  
					,@ID				= @ID			OUTPUT	 					  
					,@Name				= @Name			OUTPUT				  
					,@MUID				= @MUID			OUTPUT				  
					,@Privilege_ID		= @PrivilegeID	OUTPUT			  
		END  
	ELSE IF @ObjectTypeID = 20 -- Export View  
		BEGIN  
			EXEC  mdm.udpInformationLookupExportView  
					 @ExportView_MUID	= @ObjectMUID				  
					,@ExportView_ID		= @ObjectID				  
					,@ExportView_Name	= @ObjectName				  
					,@ID				= @ID			OUTPUT	 					  
					,@Name				= @Name			OUTPUT				  
					,@MUID				= @MUID			OUTPUT				  
					,@Privilege_ID		= @PrivilegeID	OUTPUT			  
		END									  
	  
	--SELECT   
	--	@ID = ObjectID,   
	--	@Name = [Name],   
	--	@MUID = MUID,  
	--	@PrivilegeID=PrivilegeID  
	--FROM   
	--	mdm.viw_SYSTEM_SCHEMA_MUID   
	--WHERE   
	--	ObjectTypeID = @ObjectTypeID   
	--	AND ISNULL(ObjectSubTypeID,@ObjectSubType_ID) = @ObjectSubType_ID  
	--	AND ISNULL(UserID,@User_ID) = @User_ID  
	--	AND (@ObjectID IS NULL OR (ObjectID =@ObjectID))  
	--	AND (@ObjectName IS NULL OR ([Name] = @ObjectName ))  
	--	AND (@ObjectMUID IS NULL OR (MUID = @ObjectMUID))  
 --       AND Coalesce(ParentObjectID, '') = Coalesce(@ParentObjectID, ParentObjectID,'')--Model has a NULL parent  
 --       AND Coalesce(ParentObjectMUID, 0x0) = Coalesce(@ParentObjectMUID, ParentObjectMUID,0x0)--Model has a NULL parent  
	--	AND PrivilegeID > 1 --Needed to make sure that all Denied objects are treated as the same as invalid(non existent) objects  
  
	  
	SET NOCOUNT OFF;  
END; --proc
GO
