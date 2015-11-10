SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
  
CREATE FUNCTION [mdm].[udfSecurableIDGetByObjectID]  
(  
    @Object_ID      INT,  
    @Securable_MUID UNIQUEIDENTIFIER,  
    @Securable_Name NVARCHAR(50) = NULL --Model is the only parameter accepted here  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
    DECLARE @Securable_ID INT = NULL;  
      
    IF (@Securable_MUID IS NOT NULL AND @Securable_MUID <> 0x0) BEGIN  
        IF @Object_ID = 1        -- Model  
            SELECT @Securable_ID = ID FROM mdm.tblModel WHERE MUID = @Securable_MUID;  
        ELSE IF @Object_ID = 3 or @Object_ID = 8 or @Object_ID = 9 or @Object_ID = 10 -- Entity  
            SELECT @Securable_ID = ID FROM mdm.tblEntity WHERE MUID = @Securable_MUID;  
        ELSE IF @Object_ID = 4    -- Attribute  
            SELECT @Securable_ID = ID FROM mdm.tblAttribute WHERE MUID = @Securable_MUID;  
        ELSE IF @Object_ID = 5    -- Attribute Group  
            SELECT @Securable_ID = ID FROM mdm.tblAttributeGroup WHERE MUID = @Securable_MUID;  
    END ELSE IF @Securable_Name IS NOT NULL BEGIN    
        IF @Object_ID = 1 -- Model  
            SELECT @Securable_ID = ID FROM mdm.tblModel WHERE Name = @Securable_Name;  
        ELSE --Securable id cannot be looked up by name for other object types return 0  
            SET @Securable_ID = 0;  
    END; --if  
      
    RETURN @Securable_ID;  
END; --fn
GO
