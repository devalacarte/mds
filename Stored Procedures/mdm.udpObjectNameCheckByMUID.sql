SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
declare @ret as INT  
exec mdm.udpObjectNameCheckByMUID   
	'Customer',   
	5,   
	'6A3D8AC8-4BD4-46BB-97F8-C8EC7C7CB856',   
	'EFFC762C-AF6E-4F5F-98F4-C640F2DC8413',   
	null,   
	@ret OUTPUT  
  
select @ret  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpObjectNameCheckByMUID]  
(  
	@Name					NVARCHAR(250),  
	@ObjectType_ID			INT,	  
	@Object_MUID			UNIQUEIDENTIFIER,  
	@ObjectContext_MUID	    UNIQUEIDENTIFIER = NULL,  
	@ObjectMemberType_ID	INT = NULL,  
	@Return_ID				INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
	--! This type of proc is a bad idea since it will use the execution plan for the first run for   
	-- all subsequent runs.  Should this be converted to seperate procs?  
	  
	--strip spaces.  Do it here and not in the query to stop table scans.  
	Set @Name = LTRIM(RTRIM(@Name))  
  
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
    VersionFlag = 10  
*/  
    SET @Object_MUID = ISNULL(@Object_MUID, 0x0);  
	IF @ObjectType_ID = 1 --Model  
		BEGIN  
			SELECT  
				@Return_ID = COUNT(*)  
			FROM  
				mdm.tblModel mdl  
			WHERE  
				@Name = LTRIM(RTRIM(mdl.Name)) AND  
                MUID <> @Object_MUID  
  
		END  
	ELSE IF @ObjectType_ID = 5 --Entity  
		BEGIN  
			SELECT  
				@Return_ID = COUNT(*)  
			FROM  
				mdm.tblEntity itm INNER JOIN   
                mdm.tblModel ctx  
                    ON itm.Model_ID = ctx.ID  
                    AND ctx.MUID = @ObjectContext_MUID  
                    AND itm.MUID <> @Object_MUID  
                    AND @Name = LTRIM(RTRIM(itm.Name))   
  
		END  
	ELSE IF @ObjectType_ID = 7 --AttributeName  
		BEGIN  
			SELECT  
				@Return_ID = COUNT(*)  
			FROM  
				mdm.tblAttribute itm INNER JOIN   
                mdm.tblEntity ctx  
                    ON itm.Entity_ID = ctx.ID  
                    AND ctx.MUID = @ObjectContext_MUID  
                    AND itm.MUID <> @Object_MUID  
                    AND @Name = LTRIM(RTRIM(itm.Name))   
				    AND MemberType_ID = @ObjectMemberType_ID   
  
		END  
	ELSE IF @ObjectType_ID = 8 --Attribute Group Name  
		BEGIN  
			SELECT  
				@Return_ID = COUNT(*)  
			FROM  
				mdm.tblAttributeGroup itm INNER JOIN   
                mdm.tblEntity ctx  
                    ON itm.Entity_ID = ctx.ID  
                    AND ctx.MUID = @ObjectContext_MUID  
                    AND itm.MUID <> ISNULL(@Object_MUID, 0x0)  
                    AND @Name = LTRIM(RTRIM(itm.Name))   
				    AND MemberType_ID = @ObjectMemberType_ID   
  
		END  
	ELSE IF @ObjectType_ID = 6 --Hierarchy  
		BEGIN  
			SELECT  
				@Return_ID = COUNT(*)  
			FROM  
				mdm.tblHierarchy itm INNER JOIN   
                mdm.tblEntity ctx  
                    ON itm.Entity_ID = ctx.ID  
                    AND ctx.MUID = @ObjectContext_MUID  
                    AND itm.MUID <> @Object_MUID  
                    AND @Name = LTRIM(RTRIM(itm.Name))   
  
		END  
	ELSE IF @ObjectType_ID = 2 --Derived Hierarchy  
		BEGIN  
			SELECT  
				@Return_ID = COUNT(*)  
			FROM  
				mdm.tblDerivedHierarchy itm INNER JOIN   
                mdm.tblModel ctx  
                    ON itm.Model_ID = ctx.ID  
                    AND ctx.MUID = @ObjectContext_MUID  
                    AND itm.MUID <> @Object_MUID  
                    AND @Name = LTRIM(RTRIM(itm.Name))   
  
		END  
  
	ELSE IF @ObjectType_ID = 10 --Version Flag  
		BEGIN  
			SELECT  
				@Return_ID = COUNT(*)  
			FROM  
				mdm.tblModelVersionFlag itm INNER JOIN   
                mdm.tblModel ctx  
                    ON itm.Model_ID = ctx.ID  
                    AND ctx.MUID = @ObjectContext_MUID  
                    AND itm.MUID <> @Object_MUID  
                    AND @Name = LTRIM(RTRIM(itm.Name))   
				    AND itm.Status_ID = 1  
  
		END  
	ELSE IF @ObjectType_ID = 4 --Version Name  
		BEGIN  
			SELECT  
				@Return_ID = COUNT(*)  
			FROM  
				mdm.tblModelVersion itm INNER JOIN   
                mdm.tblModel ctx  
                    ON itm.Model_ID = ctx.ID  
                    AND ctx.MUID = ISNULL(@ObjectContext_MUID, ctx.MUID)  
                    AND itm.MUID <> @Object_MUID  
                    AND @Name = LTRIM(RTRIM(itm.Name))   
  
		END  
  
  
	SET NOCOUNT OFF  
END --proc
GO
