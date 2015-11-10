SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpAttributeDeleteByMUID 'B88C0CB4-0F30-409D-9297-F6711092B018',1,1  
  
    select * from mdm.tblAttribute  
*/  
CREATE PROCEDURE [mdm].[udpAttributeDeleteByMUID]  
(  
    @Attribute_MUID		UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @Attribute_ID   INT,  
            @MemberType_ID	TINYINT,  
            @CreateViewsInd	BIT;  
  
    SELECT  @Attribute_ID = ID, @MemberType_ID = MemberType_ID FROM mdm.tblAttribute WHERE MUID = @Attribute_MUID;  
  
    --Test for invalid parameters  
    IF (@Attribute_ID IS NULL) --Invalid Attribute_MUID  
    BEGIN  
        RAISERROR('MDSERR200026|The attribute cannot be deleted. The attribute ID is not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    SET @CreateViewsInd = 1; --Create views  
  
    EXEC mdm.udpAttributeDelete @Attribute_ID, @MemberType_ID, @CreateViewsInd  
  
    SET NOCOUNT OFF;  
END; --proc
GO
