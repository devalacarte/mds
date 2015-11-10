SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Wrapper to mdm.udpDerivedHierarchyDelete proc.  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpDerivedHierarchyDeleteByMUID]  
(  
   @MUID  UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
    DECLARE @ID INT;  
        
    SELECT  @ID = ID FROM mdm.tblDerivedHierarchy WHERE MUID = @MUID  
  
    EXEC mdm.udpDerivedHierarchyDelete @ID  
  
	SET NOCOUNT OFF  
END --proc
GO
