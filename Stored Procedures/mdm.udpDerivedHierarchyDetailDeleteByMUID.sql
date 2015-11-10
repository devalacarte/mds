SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpDerivedHierarchyDetailDeleteByMUID]  
(  
    @DerivedHierarchyLevel_MUID   UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @DerivedHierarchyLevel_ID INT;  
  
    --Translate MUIDs to IDs  
    SELECT  @DerivedHierarchyLevel_ID = ID FROM mdm.tblDerivedHierarchyDetail WHERE MUID = @DerivedHierarchyLevel_MUID;  
  
    --Test for invalid parameters  
    IF @DerivedHierarchyLevel_ID IS NULL --Invalid Entity_MUID  
    BEGIN  
        RAISERROR('MDSERR200058|The derived hierarchy level cannot be deleted. The derived hierarchy level ID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    EXEC mdm.udpDerivedHierarchyDetailDelete @DerivedHierarchyLevel_ID;  
  
    SET NOCOUNT OFF  
END --proc
GO
