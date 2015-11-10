SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    Wrapper for mdm.udpEntityHierarchyDelete  
*/  
CREATE PROCEDURE [mdm].[udpEntityHierarchyDeleteByMUID]  
(  
    @User_ID        INT,  
    @Hierarchy_MUID	UNIQUEIDENTIFIER,  
    @Entity_MUID	UNIQUEIDENTIFIER    
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @Hierarchy_ID INT,  
            @Entity_ID INT,  
            @ErrorMsg NVARCHAR(250);  
        
    SELECT  @Entity_ID = ID FROM mdm.tblEntity WHERE MUID = @Entity_MUID;  
  
    --Test for invalid parameters  
    IF (@Entity_ID IS NULL) --Invalid Entity_MUID  
    BEGIN  
        RAISERROR('MDSERR200040|The explicit hierarchy cannot be deleted. The entity ID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    SELECT  @Hierarchy_ID = ID FROM mdm.tblHierarchy WHERE MUID = @Hierarchy_MUID;  
  
    IF (@Hierarchy_ID IS NULL) --Invalid Hierarchy_MUID  
    BEGIN  
        RAISERROR('MDSERR200029|The explicit hierarchy cannot be deleted. The explicit hierarchy ID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    EXEC mdm.udpEntityHierarchyDelete @User_ID, @Hierarchy_ID, @Entity_ID  
  
    SET NOCOUNT OFF;  
END; --proc
GO
