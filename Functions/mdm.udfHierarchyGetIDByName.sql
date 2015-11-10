SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfHierarchyGetIDByName(NULL, 'Metadata', NULL, 'Attribute Metadata Definition', NULL, 'Main')  
	SELECT mdm.udfHierarchyGetIDByName(NULL, 'Product', NULL, 'Product', '6AB728F2-90B1-429A-ADBE-87CA045B287D', NULL)  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfHierarchyGetIDByName]  
(  
	@Model_MUID				UNIQUEIDENTIFIER,  
	@Model_Name				NVARCHAR(50),  
	@Entity_MUID			UNIQUEIDENTIFIER,   
	@Entity_Name			NVARCHAR(50),  
	@Hierarchy_MUID			UNIQUEIDENTIFIER,   
	@Hierarchy_Name			NVARCHAR(50)  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
    DECLARE @Entity_ID INT,  
            @Hierarchy_ID INT;  
          
	IF (@Entity_Name IS NOT NULL OR @Entity_MUID IS NOT NULL)  
	BEGIN  
	    SELECT @Entity_ID = mdm.udfEntityGetIDByName(@Model_MUID, @Model_Name, @Entity_MUID, @Entity_Name)   
        SELECT @Entity_ID = ISNULL(@Entity_ID, -2);  
  
	    IF (@Entity_ID < 0) --Invalid Model ID or Entity ID  
            RETURN @Entity_ID;  
  
	    SET @Hierarchy_ID = ISNULL((SELECT ID FROM mdm.tblHierarchy WHERE   
	        (@Hierarchy_MUID IS NULL OR MUID = @Hierarchy_MUID) AND (@Hierarchy_Name IS NULL OR [Name] = @Hierarchy_Name) AND (@Hierarchy_MUID IS NOT NULL OR @Hierarchy_Name IS NOT NULL)  
	        AND Entity_ID = @Entity_ID),-1);  
  
    END  
    ELSE  
	     SET @Hierarchy_ID = ISNULL((SELECT ID FROM mdm.tblHierarchy WHERE   
         @Hierarchy_MUID IS NOT NULL AND MUID = @Hierarchy_MUID), -1);  
  
	RETURN @Hierarchy_ID;  
END; --fn
GO
