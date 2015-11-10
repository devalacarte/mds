SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
This stored procedure determines if a user is an administrator a model.  A model administrator must have update permission of   
the model and all underlying child objects.  This can be determined by passing in the Model Id itself or it can be determined   
by passing in child objects (if that is all that is available) and then based on the FK links it can be determined if the user  
is an administrator of the model.  
  
The object context is optional and need only be passed in if the object Muid is not passed in, which is the case in add mode.  
  
declare @ret as INT  
exec mdm.udpUserIsModelAdministrator  
	1,  
    7,   
	NULL,   
	'EE851F25-8919-460F-8485-99D319C70AF2',   
    NULL,  
	@ret OUTPUT  
select @ret  
  
declare @ret as INT  
exec mdm.udpUserIsModelAdministrator  
	1,  
    5,   
	NULL,  
    'Department',   
	NULL,   
    NULL,   
	@ret OUTPUT  
select @ret  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserIsModelAdministrator]  
(  
	@User_ID	            INT,                        -- User id to check .  
	@ObjectType_ID			INT,	                    -- The object type of the Muid being passed in.  
	@Object_MUID			UNIQUEIDENTIFIER = NULL,    -- The object's Muid.  Not passed in during add mode.  
	@Object_Name			NVARCHAR(250) = NULL,       -- The object's Name.  Not passed in during add mode.  
	@ObjectContext_MUID	    UNIQUEIDENTIFIER = NULL,    -- The object's context (or parent) Muid.  
	@ObjectContext_Name		NVARCHAR(250) = NULL,       -- The object's context (or parent) name.  
	@Return_ID				INT = NULL OUTPUT           -- The result: True if the user is a model admin.  False otherwise.  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
/*  
    ObjectType_ID's that are checked.  
	--------------------------------------  
    Model = 1,  
    DerivedHierarchy = 2,  
    DerivedHierarchyLevel = 3,  
    Version = 4,  
    Entity = 5,  
    Hierarchy = 6,  
    Attribute = 7,  
    AttributeGroup = 8,  
    VersionFlag = 10  
*/  
  
    DECLARE @EmptyMuid UNIQUEIDENTIFIER SET @EmptyMuid = CONVERT(UNIQUEIDENTIFIER, 0x0);  
  
    -- In an add scenario the object Muid will not be supplied.   
    IF @Object_MUID = @EmptyMuid  
        SET @Object_MUID = NULL;  
    IF @Object_Name = CAST(N'' AS NVARCHAR(250))  
        SET @Object_Name = NULL;  
  
    --Null out the context Muid and Name if it is not supplied.   
    IF @ObjectContext_MUID = @EmptyMuid  
        SET @ObjectContext_MUID = NULL;  
    IF @ObjectContext_Name = CAST(N'' AS NVARCHAR(250))  
        SET @ObjectContext_Name = NULL;  
      
    IF @Object_MUID IS NULL AND @Object_Name IS NULL AND @ObjectContext_MUID IS NULL AND @ObjectContext_Name IS NULL  
    BEGIN  
        SET @Return_ID = 0;  
        RETURN;  
    END  
  
    IF (@Object_MUID IS NULL AND @Object_Name IS NOT NULL) AND (@ObjectContext_MUID IS NULL AND @ObjectContext_Name IS NULL) AND @ObjectType_ID <> 1 -- Model's don't need context  
    BEGIN  
        SET @Return_ID = 0;  
        RETURN;  
    END  
  
	IF @ObjectType_ID = 1 --Model  
		BEGIN  
			SELECT  
				@Return_ID = acl.IsAdministrator  
			FROM  
				mdm.tblModel itm INNER JOIN	  
                mdm.udfSecurityUserModelList(@User_ID) AS acl  
        		    ON	acl.ID = itm.ID			  
                    AND (itm.MUID = @Object_MUID OR itm.Name = @Object_Name)  
		END  
	ELSE IF @ObjectType_ID = 5 --Entity  
		BEGIN  
            IF @Object_MUID IS NOT NULL  
                SELECT  
	                @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.viw_SYSTEM_SCHEMA_ENTITY itm INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON  ((itm.MUID = @Object_MUID)  
                        OR  (itm.Name = @Object_Name AND (((@ObjectContext_MUID IS NULL) OR (itm.Model_MUID = @ObjectContext_MUID)) AND ((@ObjectContext_Name IS NULL) OR (itm.Model_Name = @ObjectContext_Name))))  
                        )  
	                    AND	acl.ID = itm.Model_ID			  
            ELSE  
                SELECT  
                    @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.tblModel ctx INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON ((@ObjectContext_MUID IS NULL) OR (ctx.MUID = @ObjectContext_MUID))  
                        AND ((@ObjectContext_Name IS NULL) OR (ctx.Name = @ObjectContext_Name))  
                        AND	acl.ID = ctx.ID			  
  
		END  
	ELSE IF @ObjectType_ID = 7 --Attribute  
		BEGIN  
            IF @Object_MUID IS NOT NULL  
                SELECT  
	                @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES itm INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON  ((itm.Attribute_MUID = @Object_MUID)  
                        OR  (itm.Attribute_Name = @Object_Name AND (((@ObjectContext_MUID IS NULL) OR (itm.Entity_MUID = @ObjectContext_MUID)) AND ((@ObjectContext_Name IS NULL) OR (itm.Entity_Name = @ObjectContext_Name))))  
                        )  
	                    AND	acl.ID = itm.Model_ID  
            ELSE  
                SELECT  
                    @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.tblEntity ctx INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON ((@ObjectContext_MUID IS NULL) OR (ctx.MUID = @ObjectContext_MUID))  
                        AND ((@ObjectContext_Name IS NULL ) OR (ctx.Name = @ObjectContext_Name))  
                        AND	acl.ID = ctx.Model_ID			  
  
		END  
	ELSE IF @ObjectType_ID = 8 --Attribute Group  
		BEGIN  
            IF @Object_MUID IS NOT NULL  
                SELECT  
                    @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.viw_SYSTEM_SCHEMA_ATTRIBUTEGROUPS itm INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON  ((itm.MUID = @Object_MUID)  
                        OR  (itm.Name = @Object_Name AND (((@ObjectContext_MUID IS NULL) OR (itm.Entity_MUID = @ObjectContext_MUID)) AND ((@ObjectContext_Name IS NULL) OR (itm.Entity_Name = @ObjectContext_Name))))  
                        )  
                        AND	acl.ID = itm.Model_ID			  
            ELSE  
                SELECT  
                    @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.tblEntity ctx INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON ((@ObjectContext_MUID IS NULL) OR (ctx.MUID = @ObjectContext_MUID))  
                        AND ((@ObjectContext_Name IS NULL) OR (ctx.Name = @ObjectContext_Name))  
                        AND	acl.ID = ctx.Model_ID			  
  
		END  
	ELSE IF @ObjectType_ID = 6 --Hierarchy  
		BEGIN  
            IF @Object_MUID IS NOT NULL  
            SELECT  
	            @Return_ID = acl.IsAdministrator  
            FROM  
                mdm.viw_SYSTEM_SCHEMA_HIERARCHY_EXPLICIT itm INNER JOIN  
                mdm.udfSecurityUserModelList(@User_ID) AS acl  
                    ON  ((itm.Hierarchy_MUID = @Object_MUID)  
                    OR  (itm.Hierarchy_Name = @Object_Name AND (((@ObjectContext_MUID IS NULL) OR (itm.Entity_MUID = @ObjectContext_MUID)) AND ((@ObjectContext_Name IS NULL) OR (itm.Entity_Name = @ObjectContext_Name))))  
                    )  
	                AND	acl.ID = itm.Model_ID			  
            ELSE  
                SELECT  
                    @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.tblEntity ctx INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON ((@ObjectContext_MUID IS NULL) OR (ctx.MUID = @ObjectContext_MUID))  
                        AND ((@ObjectContext_Name IS NULL) OR (ctx.Name = @ObjectContext_Name))  
                        AND	acl.ID = ctx.Model_ID			  
  
		END  
	ELSE IF @ObjectType_ID = 2 --Derived Hierarchy  
		BEGIN  
            IF @Object_MUID IS NOT NULL  
                SELECT  
	                @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED itm INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON  ((itm.Hierarchy_MUID = @Object_MUID)  
                        OR  (itm.Hierarchy_Name = @Object_Name AND (((@ObjectContext_MUID IS NULL) OR (itm.Model_MUID = @ObjectContext_MUID)) AND ((@ObjectContext_Name IS NULL) OR (itm.Model_Name = @ObjectContext_Name))))  
                        )  
	                    AND	acl.ID = itm.Model_ID			  
            ELSE  
                SELECT  
                    @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.tblModel ctx INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON ((@ObjectContext_MUID IS NULL) OR (ctx.MUID = @ObjectContext_MUID))  
                        AND ((@ObjectContext_Name IS NULL) OR (ctx.Name = @ObjectContext_Name))  
                        AND	acl.ID = ctx.ID			  
		END  
	ELSE IF @ObjectType_ID = 3 --Derived Hierarchy Level  
		BEGIN  
            IF @Object_MUID IS NOT NULL  
                SELECT  
	                @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS itm INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON  ((itm.MUID = @Object_MUID)  
                        OR  (itm.Name = @Object_Name AND (((@ObjectContext_MUID IS NULL) OR (itm.Hierarchy_MUID = @ObjectContext_MUID)) AND ((@ObjectContext_Name IS NULL) OR (itm.Hierarchy_Name = @ObjectContext_Name))))  
                        )  
	                    AND	acl.ID = itm.Model_ID			  
            ELSE  
                SELECT  
                    @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.tblDerivedHierarchy ctx INNER JOIN  
                    mdm.tblModel mdl   
                        ON ctx.Model_ID = mdl.ID  
                    INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON ((@ObjectContext_MUID IS NULL) OR (ctx.MUID = @ObjectContext_MUID))  
                        AND ((@ObjectContext_Name IS NULL) OR (ctx.Name = @ObjectContext_Name))  
                        AND	acl.ID = mdl.ID			  
		END  
	ELSE IF @ObjectType_ID = 10 --Version Flag  
		BEGIN  
            IF @Object_MUID IS NOT NULL  
                SELECT  
	                @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.viw_SYSTEM_SCHEMA_VERSION_FLAGS itm INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON  ((itm.MUID = @Object_MUID)  
                        OR  (itm.Name = @Object_Name AND (((@ObjectContext_MUID IS NULL) OR (itm.Model_MUID = @ObjectContext_MUID)) AND ((@ObjectContext_Name IS NULL) OR (itm.Model_Name = @ObjectContext_Name))))  
                        )  
	                    AND	acl.ID = itm.Model_ID			  
            ELSE  
                SELECT  
                    @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.tblModel ctx INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON ((@ObjectContext_MUID IS NULL) OR (ctx.MUID = @ObjectContext_MUID))  
                        AND ((@ObjectContext_Name IS NULL) OR (ctx.Name = @ObjectContext_Name))  
                        AND	acl.ID = ctx.ID			  
  
		END  
	ELSE IF @ObjectType_ID = 4 --Version  
		BEGIN  
            IF @Object_MUID IS NOT NULL  
                SELECT  
	                @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.viw_SYSTEM_SCHEMA_VERSION itm INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON  ((itm.MUID = @Object_MUID)  
                        OR  (itm.Name = @Object_Name AND (((@ObjectContext_MUID IS NULL) OR (itm.Model_MUID = @ObjectContext_MUID)) AND ((@ObjectContext_Name IS NULL) OR (itm.Model_Name = @ObjectContext_Name))))  
                        )  
	                    AND	acl.ID = itm.Model_ID			  
            ELSE  
                SELECT  
                    @Return_ID = acl.IsAdministrator  
                FROM  
                    mdm.tblModel ctx INNER JOIN  
                    mdm.udfSecurityUserModelList(@User_ID) AS acl  
                        ON ((@ObjectContext_MUID IS NULL) OR (ctx.MUID = @ObjectContext_MUID))  
                        AND ((@ObjectContext_Name IS NULL) OR (ctx.Name = @ObjectContext_Name))  
                        AND	acl.ID = ctx.ID			  
  
		END  
  
  
    SET @Return_ID = ISNULL(@Return_ID,0)  
  
	SET NOCOUNT OFF  
END --proc
GO
