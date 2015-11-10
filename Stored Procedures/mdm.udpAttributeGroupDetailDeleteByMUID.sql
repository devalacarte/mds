SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	Wrapper for mdm.udpAttributeGroupDetailDelete sproc.  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpAttributeGroupDetailDeleteByMUID]  
(  
   @User_ID				INT,  
   @AttributeGroup_MUID UNIQUEIDENTIFIER,  
   @Type_ID				INT --Attributes = 1,Users = 2,UserGroups = 3  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
      
	DECLARE @AttributeGroup_ID	INT;  
	SELECT @AttributeGroup_ID = ID FROM mdm.tblAttributeGroup WHERE MUID = @AttributeGroup_MUID;  
  
    EXEC mdm.udpAttributeGroupDetailDelete @User_ID, @AttributeGroup_ID, @Type_ID  
  
	SET NOCOUNT OFF;  
END; --proc
GO
