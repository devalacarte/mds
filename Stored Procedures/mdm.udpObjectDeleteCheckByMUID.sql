SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @RET AS INT;  
	EXEC mdm.udpObjectDeleteCheckByMUID 'FD8C1505-B2CB-44AE-B683-ED595145C8D0',7,@RET OUTPUT;  
	SELECT @RET;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpObjectDeleteCheckByMUID]  
(  
	@Object_MUID		    UNIQUEIDENTIFIER,  
	@ObjectType_ID		INT,	  
	@Return_ID			INT = NULL OUTPUT  
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
    DerivedHierarchyDetail = 3,  
    Version = 4,  
    Entity = 5,  
    Hierarchy = 6,  
    Attribute = 7,  
    AttributeGroup = 8,  
    StagingBatch = 9,  
    VersionFlag = 10  
  
	Returns  
	--------------------------------------  
	0: OK to Delete  
	Non-zero: NOT OK to Delete  
*/  
  
  
	DECLARE	@ObjectID   INT,  
	        @Ret        INT,  
            @EntityID   INT;  
  
	--Default the Value  
	SELECT @Return_ID = 0;  
  
	IF @ObjectType_ID = 1 BEGIN --Model  
        IF EXISTS (SELECT 1 FROM mdm.tblModel WHERE MUID = @Object_MUID and IsSystem =1)  
            BEGIN  
                SET @Return_ID = 1;  
            END  
        ELSE  
            BEGIN  
		        SET @Return_ID = 0;  
		    END  
  
	END	ELSE IF @ObjectType_ID = 5 BEGIN --Entity  
		SELECT @ObjectID = ID FROM mdm.tblEntity WHERE MUID = @Object_MUID  
  
		IF EXISTS(SELECT 1 FROM mdm.tblAttribute WHERE DomainEntity_ID = @ObjectID) BEGIN  
			SET @Return_ID = 200023;  
		END ELSE IF EXISTS(SELECT 1 FROM mdm.tblBRBusinessRule WHERE Foreign_ID = @ObjectID) BEGIN  
			SET @Return_ID = 200024;  
		END ELSE IF EXISTS(SELECT 1 FROM mdm.tblDerivedHierarchyDetail WHERE Foreign_ID = @ObjectID AND ForeignType_ID = 0) BEGIN  
			SET @Return_ID = 200025;  
		END ELSE BEGIN  
            EXEC mdm.udpSubscriptionViewCheck @Entity_ID = @ObjectID, @Return_ID = @Ret output  
            IF @Ret > 0  
                SET @Return_ID = 200052;  
        END; --if			  
  
	END	ELSE IF @ObjectType_ID = 7 BEGIN --Attribute  
		SELECT @ObjectID = ID, @EntityID = Entity_ID FROM mdm.tblAttribute WHERE MUID = @Object_MUID  
  
		IF EXISTS(SELECT 1 FROM mdm.tblDerivedHierarchyDetail WHERE Foreign_ID = @ObjectID AND ForeignType_ID = 1) BEGIN  
			SET @Return_ID = 200028;  
		END ELSE IF EXISTS(SELECT 1 FROM mdm.tblBRItemProperties WHERE   
			(PropertyType_ID = 2 OR PropertyType_ID = 4) AND [Value] = CONVERT(NVARCHAR(999),@ObjectID)) BEGIN  
			SET @Return_ID = 200027;  
		END ELSE IF EXISTS (SELECT  1 FROM INFORMATION_SCHEMA.COLUMNS  s  
				INNER JOIN mdm.tblAttribute a ON  
					a.Name = s.COLUMN_NAME   
				INNER JOIN mdm.tblSubscriptionView sv  
					ON  sv.Name = s.TABLE_NAME AND   
					sv.Entity_ID = @EntityID AND    
					s.TABLE_SCHEMA = 'mdm'   
				WHERE a.MUID = @Object_MUID AND  
					  a.Entity_ID = @EntityID)  
				BEGIN  
					SET @Return_ID = 200052;  
         END;  
	END ELSE IF @ObjectType_ID = 6 BEGIN --Hierarchy  
		SELECT @ObjectID = ID FROM mdm.tblHierarchy WHERE MUID = @Object_MUID  
  
		IF EXISTS(SELECT 1 FROM mdm.tblDerivedHierarchyDetail WHERE Foreign_ID = @ObjectID AND ForeignType_ID = 2) BEGIN  
			SET @Return_ID = 200030;  
		END ELSE IF EXISTS(  
			-- Check if there are any consolidation or collection rules.  If this is the last hierarchy (current count = 1)  
			-- then prevent the deletion until the BR has been deleted.  
			SELECT	1  
			FROM	mdm.tblBRBusinessRule br INNER JOIN   
					mdm.tblHierarchy h ON   
						br.Foreign_ID = h.Entity_ID AND  
						br.ForeignType_ID = 2 AND  
						h.ID = @ObjectID  
			WHERE  
				 (SELECT COUNT(ID) FROM mdm.tblHierarchy hr WHERE h.Entity_ID = hr.Entity_ID) = 1   
			UNION  
			-- Check if there are any leaf rules that refer to consolidation attributes  
			SELECT 1 FROM mdm.tblBRItemProperties WHERE PropertyType_ID = 3 AND [Value] = CONVERT(NVARCHAR(999),@ObjectID)  
		) BEGIN  
			SET @Return_ID = 200031;  
		END; --if  
  
	END	ELSE IF @ObjectType_ID = 10 BEGIN --Version Flag  
		SELECT @ObjectID = ID FROM mdm.tblModelVersionFlag WHERE MUID = @Object_MUID  
  
		IF EXISTS(SELECT 1 FROM mdm.tblModelVersion WHERE VersionFlag_ID = @ObjectID) BEGIN  
			SET @Return_ID = 200035  
		END; --if  
  
	END	ELSE IF @ObjectType_ID = 2 OR @ObjectType_ID = 3 BEGIN --Derived Hierarchy or Derived Hierarchy Level  
		SELECT @ObjectID = ID FROM mdm.tblDerivedHierarchy WHERE MUID = @Object_MUID  
  
        EXEC mdm.udpSubscriptionViewCheck @DerivedHierarchy_ID = @ObjectID, @ViewFormat_ID = 8 /*Levels*/, @Return_ID = @Ret output  
        IF @Ret > 0  
            -- No reason to differentiate between Subscription with Levels vs. with ParentChild.  See TFS 360606  
            SET @Return_ID = 200049; -- SET @Return_ID = 200050;  
        ELSE  
        BEGIN  
            EXEC mdm.udpSubscriptionViewCheck @DerivedHierarchy_ID = @ObjectID, @ViewFormat_ID = 7 /*ParentChild*/, @MarkDirtyFlag = 1, @Return_ID = @Ret output  
            IF @Ret > 0  
                SET @Return_ID = 200049;  
        END  
	END ELSE  
		SET @Return_ID = 0;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
