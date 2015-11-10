SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    Deletes all subscription views that match the given criteria.   
    Parameters that are null or less than 1 are ignored, but at least one   
    of the parameter must have a valid value (i.e. value > 0).   
      
    EXEC mdm.udpSubscriptionViewsDelete 1, 0;  
*/  
CREATE PROCEDURE [mdm].[udpSubscriptionViewsDelete]  
(  
    @Model_ID               INT = NULL,  
    @Version_ID             INT = NULL,  
    @Entity_ID              INT = NULL,  
    @DerivedHierarchy_ID    INT = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    -- Change invalid input id's to null  
    IF (@Model_ID <= 0)   
    BEGIN  
        SET @Model_ID = NULL;  
    END           
    IF (@Version_ID <= 0)   
    BEGIN  
        SET @Version_ID = NULL;  
    END           
    IF (@Entity_ID <= 0)   
    BEGIN  
        SET @Entity_ID = NULL;  
    END           
    IF (@DerivedHierarchy_ID <= 0)   
    BEGIN  
        SET @DerivedHierarchy_ID = NULL;  
    END   
      
    -- Ensure at least one valid parameter was provided  
    IF (@Model_ID IS NULL AND @Version_ID IS NULL AND @Entity_ID IS NULL AND @DerivedHierarchy_ID IS NULL)  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);   
        RETURN;  
    END   
      
    -- Get a list of all subscription views that match the given criteria  
    DECLARE @SubscriptionViewIDs mdm.IdList;           
    INSERT INTO @SubscriptionViewIDs (ID)   
    SELECT ID FROM mdm.tblSubscriptionView sv  
    WHERE   
        (@Model_ID IS NULL OR @Model_ID = sv.Model_ID) AND  
        (@Version_ID IS NULL OR @Version_ID = sv.ModelVersion_ID) AND  
        (@Entity_ID IS NULL OR @Entity_ID = sv.Entity_ID) AND  
        (@DerivedHierarchy_ID IS NULL OR @DerivedHierarchy_ID = sv.DerivedHierarchy_ID);  
            
  
    DECLARE @DeleteView BIT = 1; -- constant  
    DECLARE @SubscriptionViewID INT;  
    WHILE EXISTS(SELECT 1 FROM @SubscriptionViewIDs)  
    BEGIN   
        -- Get the next subscription view id  
        SET @SubscriptionViewID = (SELECT TOP 1 ID FROM @SubscriptionViewIDs);  
          
        -- Delete the subscription view  
        EXEC mdm.udpSubscriptionViewDeleteByID @SubscriptionViewID, @DeleteView;  
          
        -- Remove the deleted subscription view from the ID list  
        DELETE FROM @SubscriptionViewIDs WHERE ID = @SubscriptionViewID;  
    END  
          
    SET NOCOUNT OFF;  
END;
GO
