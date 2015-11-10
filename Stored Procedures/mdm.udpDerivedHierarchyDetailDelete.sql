SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpDerivedHierarchyDetailDelete 'edmAdmin', NULL, 1  
SELECT * FROM mdm.tblDerivedHierarchy  
*/  
CREATE PROCEDURE [mdm].[udpDerivedHierarchyDetailDelete]  
(  
    @ID			INT = NULL  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @DerivedHierarchy_ID INT,  
            @Model_ID INT,  
            @Entity_ID INT,  
            @LevelDiff INT,  
            @Ret INT;  
  
    BEGIN TRY  
        SELECT   
            @DerivedHierarchy_ID = DerivedHierarchy_ID,  
            @LevelDiff = (SELECT MAX(Level_ID) FROM mdm.tblDerivedHierarchyDetail WHERE DerivedHierarchy_ID = dt.DerivedHierarchy_ID) - Level_ID  
        FROM mdm.tblDerivedHierarchyDetail dt  
        WHERE ID = @ID  
  
        --Verify that the Derived Hierarchy ID is retreived, meaning we also have a valid Level ID  
        IF @DerivedHierarchy_ID IS NULL  
        BEGIN  
            RAISERROR('MDSERR200058|The derived hierarchy level cannot be deleted. The derived hierarchy level ID is not valid.', 16, 1);  
        END;  
  
        --Verify deleting the topmost level.  
        IF @LevelDiff > 0  
        BEGIN  
            RAISERROR('MDSERR200059|The derived hierarchy level cannot be deleted. Only the top level can be deleted.', 16, 1);  
        END;  
          
        --Verify there is no security set on any levels of the derived hierarchy.  
        IF EXISTS (SELECT ID FROM mdm.tblSecurityRoleAccessMember WHERE DerivedHierarchy_ID = @DerivedHierarchy_ID)    
        BEGIN    
            RAISERROR('MDSERR200078|Derived Hierarchy level cannot be deleted. The derived hierarchy has secured members.', 16, 1);  
        END  
  
        --Verify no subscription views exists.  
        EXEC mdm.udpSubscriptionViewCheck @DerivedHierarchy_ID = @DerivedHierarchy_ID, @ViewFormat_ID = 8 /*Levels*/, @Return_ID = @Ret output  
        IF @Ret > 0  
            BEGIN  
                RAISERROR('MDSERR200049|The derived hierarchy was not deleted because a subscription view exists.  To delete the hierarchy, you must first delete all subscription views associated with this derived hierarchy.', 16, 1);  
            END;  
        ELSE  
        BEGIN  
            EXEC mdm.udpSubscriptionViewCheck @DerivedHierarchy_ID = @DerivedHierarchy_ID, @ViewFormat_ID = 7 /*ParentChild*/, @MarkDirtyFlag = 1, @Return_ID = @Ret output  
            IF @Ret > 0  
            BEGIN  
                RAISERROR('MDSERR200049|The derived hierarchy was not deleted because a subscription view exists.  To delete the hierarchy, you must first delete all subscription views associated with this derived hierarchy.', 16, 1);  
            END;  
        END  
  
        SELECT @Entity_ID = Foreign_ID,@Model_ID=Model_ID FROM mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS WHERE ID = @ID AND Object_ID = 3  
  
        --Delete the detail record  
        DELETE FROM mdm.tblDerivedHierarchyDetail WHERE ID = @ID  
  
        --Put a msg onto the SB queue to process member security   
        --for all entities in All versions in the model to be safe - revisit  
        EXEC mdm.udpSecurityMemberProcessRebuildModel @Model_ID = @Model_ID, @ProcessNow=0;	  
          
    END TRY  
  
    BEGIN CATCH  
        -- Get error info  
        DECLARE  
            @ErrorMessage NVARCHAR(4000),  
            @ErrorSeverity INT,  
            @ErrorState INT;  
        EXEC mdm.udpGetErrorInfo  
            @ErrorMessage = @ErrorMessage OUTPUT,  
            @ErrorSeverity = @ErrorSeverity OUTPUT,  
            @ErrorState = @ErrorState OUTPUT;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
        RETURN;      
    END CATCH;  
  
    SET NOCOUNT OFF  
END --proc
GO
