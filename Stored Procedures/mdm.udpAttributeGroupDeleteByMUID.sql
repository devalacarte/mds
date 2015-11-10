SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpAttributeGroupDelete null,1;  
    SELECT * FROM mdm.tblAttributeGroup;  
*/  
CREATE PROCEDURE [mdm].[udpAttributeGroupDeleteByMUID]  
(  
    @MUID	UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @AttributeGroup_ID INT;  
        
    SELECT @AttributeGroup_ID = ID from mdm.tblAttributeGroup WHERE MUID = @MUID;  
  
    --Test for invalid parameters  
    IF (@AttributeGroup_ID IS NULL) --Invalid AttributeGroup MUID  
    BEGIN  
        RAISERROR('MDSERR200033|The attribute group cannot be deleted. The attribute group ID is not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
  
    EXEC mdm.udpAttributeGroupDelete @AttributeGroup_ID;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
