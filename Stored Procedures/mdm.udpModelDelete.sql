SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpModelDelete '5'  
*/  
CREATE PROCEDURE [mdm].[udpModelDelete]  
(  
    @Model_ID INT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        DECLARE @tblEntityID	TABLE (  
                                RowNumber INT IDENTITY (1, 1) PRIMARY KEY CLUSTERED NOT NULL   
                                ,ID INT NOT NULL);  
        DECLARE @DeleteBRs		mdm.IdList;  
  
        DECLARE @TempID			INT,  
                @ModelName		NVARCHAR(50),  
                @IsSystem       BIT,  
                @Model_MUID		UNIQUEIDENTIFIER	-- needed for metadata deletion  
  
        --Get the name, and isSystem value  
        SELECT  @ModelName = [Name],  
                @IsSystem = IsSystem  
        From mdm.tblModel WHERE ID = @Model_ID;  
  
        --Check for system model If system model prevent deletion by raising error.         
        IF(@IsSystem = 1)  
        BEGIN  
            RAISERROR('MDSERR100043|A system model cannot be deleted.', 16, 1);  
        END;  
  
        --Get the model MUID  
        SELECT @Model_MUID = MUID FROM mdm.tblModel WHERE ID = @Model_ID  
  
        --Delete all derived hierarchies  
        INSERT INTO @tblEntityID   
            SELECT D.ID FROM mdm.tblDerivedHierarchy D WHERE D.Model_ID = @Model_ID;  
        DECLARE @Counter INT = 1 ;  
        DECLARE @MaxCounter INT = (SELECT MAX(RowNumber) FROM @tblEntityID);  
          
        WHILE @Counter <= @MaxCounter  
            BEGIN  
            SELECT @TempID = ID FROM @tblEntityID WHERE [RowNumber] = @Counter ;;  
            EXEC mdm.udpDerivedHierarchyDelete @TempID;  
            SET @Counter = @Counter+1  
        END; --while  
          
        --Delete the subscription views associated with the model  
        EXEC mdm.udpSubscriptionViewsDelete   
            @Model_ID               = @Model_ID,  
            @Version_ID             = NULL,  
            @Entity_ID	            = NULL,  
            @DerivedHierarchy_ID    = NULL;  
  
        --Delete business rules  
        INSERT INTO @DeleteBRs (ID) SELECT br.BusinessRule_ID FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES br WHERE br.Model_ID = @Model_ID;  
        EXEC mdm.udpBusinessRulesDelete @DeleteBRs  
  
        DELETE FROM @tblEntityID;	  
        --Delete all entities within the Model  
        INSERT INTO @tblEntityID SELECT E.ID FROM mdm.tblEntity E WHERE E.Model_ID = @Model_ID;  
        SET @Counter =(SELECT MIN(RowNumber) FROM @tblEntityID) ; --reused table variable so the row won't start at 1.  
        SET @MaxCounter = (SELECT MAX(RowNumber) FROM @tblEntityID);  
          
        WHILE @Counter <= @MaxCounter  
        BEGIN  
            SELECT @TempID = ID FROM @tblEntityID WHERE [RowNumber] = @Counter ;  
            PRINT 'Removing Entity:' + CAST(@Counter as nvarchar(100))  
            EXEC mdm.udpEntityDelete @TempID, 0;  
            SET @Counter = @Counter+1  
        END; --while  
  
        --Delete the security maps  
        --EXEC mdm.udpHierarchyMapDelete @Model_ID = @Model_ID;  
  
        --Delete any attribute groups  
        DELETE FROM mdm.tblAttributeGroup WHERE EnterVersionID IN (SELECT ID FROM mdm.tblModelVersion WHERE Model_ID = @Model_ID);  
        DELETE FROM mdm.tblAttributeGroupDetail WHERE EnterVersionID IN (SELECT ID FROM mdm.tblModelVersion WHERE Model_ID = @Model_ID);  
  
        --Delete any explicitly assigned security privileges  
        DELETE FROM mdm.tblSecurityRoleAccess where Model_ID = @Model_ID;  
        DELETE FROM mdm.tblSecurityRoleAccessMember where Version_ID IN (select ID from mdm.tblModelVersion where Model_ID = @Model_ID);  
  
        --Delete all notification queue related items  
        DELETE FROM mdm.tblNotificationUsers where Notification_ID IN (select ID from mdm.tblNotificationQueue where Model_ID = @Model_ID);		  
        DELETE FROM mdm.tblNotificationQueue where Model_ID = @Model_ID  
  
        --Delete the version record(s)  
        DELETE FROM mdm.tblModelVersion WHERE Model_ID = @Model_ID;  
        DELETE FROM mdm.tblModelVersionFlag WHERE Model_ID = @Model_ID;  
  
        --Delete the log data  
        DELETE FROM mdm.tblValidationLog WHERE Version_ID IN (SELECT ID FROM mdm.tblModelVersion WHERE Model_ID = @Model_ID);  
  
        --Delete the Model record  
        DELETE FROM mdm.tblModel WHERE ID = @Model_ID;  
  
        --(Soft) delete any associated metadata  
        EXEC mdm.udpUserDefinedMetadataDelete @Object_Type = N'Model', @Object_ID = @Model_MUID  
  
        --Commit only if we are not nested  
        IF @TranCounter = 0 COMMIT TRANSACTION;  
  
    END TRY  
    --Compensate as necessary  
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
  
        IF @TranCounter = 0 ROLLBACK TRANSACTION;  
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
  
        --On error, return NULL results  
        --SELECT @Return_ID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
