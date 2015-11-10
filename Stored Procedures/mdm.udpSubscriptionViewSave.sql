SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
EXEC mdm.udpSubscriptionViewSave  
    @SubscriptionView_ID	=  NULL,   
    @Entity_ID		= 9999999,  
    @Model_ID		= 9999999,  
    @DerivedHierarchy_ID	= 9999999,  
    @ModelVersion_ID		= 9999999,  
    @ModelVersionFlag_ID	= 9999999,  
    @ViewFormat_ID			= 10,  
    @Levels					= 1,  
    @SubscriptionViewName	= ''  
  
  
*/  
CREATE PROCEDURE [mdm].[udpSubscriptionViewSave]  
(  
    @SubscriptionView_ID	INT = NULL,   
    @Entity_ID				INT,  
    @Model_ID				INT,  
    @DerivedHierarchy_ID	INT = NULL,  
    @ModelVersion_ID		INT,  
    @ModelVersionFlag_ID	INT = NULL,  
    @ViewFormat_ID			INT,  
    @Levels					INT,  
    @SubscriptionViewName	sysname,  
    @Return_ID				INT = NULL OUTPUT,  
    @Return_MUID			UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
      
    DECLARE @e AS NVARCHAR(200),  
            @MaxLevels INT,  
            @IsValidParam bit;  
   
    --Initialize output parameters and local variables  
    SELECT 	@Return_ID = NULL,  
            @MaxLevels = 0;  
              
    --Test for invalid parameters  
    SET @IsValidParam = 1;  
  
    --Validate Model_ID    		  
    EXECUTE @IsValidParam  = mdm.udpIDParameterCheck @Model_ID, 1,NULL,NULL,1  
    IF (@IsValidParam = 0)  
    BEGIN  
        RAISERROR('MDSERR100011|The Model ID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    --Validate ViewFormat_ID  
    EXECUTE @IsValidParam  = mdm.udpIDParameterCheck @ViewFormat_ID, NULL,1,8,1  
    IF (@IsValidParam = 0)  
    BEGIN  
        RAISERROR('MDSERR100014|The View Format ID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    --Must enter @SubscriptionViewName  
    IF  (@SubscriptionViewName IS NULL OR LEN(@SubscriptionViewName) = 0 )   
    BEGIN  
        RAISERROR('MDSERR100021|A subscription view name is required.', 16, 1);  
        RETURN;  
    END;  
         
    --Check for duplicate subscription view name   
    IF (EXISTS (SELECT [Name] FROM mdm.tblSubscriptionView WHERE RTRIM(LTRIM([Name])) = @SubscriptionViewName AND ID <> ISNULL(@SubscriptionView_ID,ID)))  
    BEGIN  
        RAISERROR('MDSERR100015|The subscription view name already exists.', 16, 1);  
        RETURN;  
    END;  
  
    --Check for subscription view length  
    IF LEN(@SubscriptionViewName) > 128  
    BEGIN  
        RAISERROR('MDSERR100016|The subscription view name must be fewer than 128 characters.', 16, 1);  
        RETURN;  
    END;  
      
    --Business rule checks:     
    --  View can be for either an Entity or Derived Hierarchy  
    IF ((@Entity_ID IS NULL OR @Entity_ID = 0 ) AND (@DerivedHierarchy_ID IS NULL OR @DerivedHierarchy_ID = 0)) OR  
       (@Entity_ID IS NOT NULL AND @DerivedHierarchy_ID IS NOT NULL)   
    BEGIN  
        RAISERROR('MDSERR100017|A subscription view can be generated for either an entity or a derived hierarchy, but not for both.', 16, 1);  
        RETURN;  
    END;  
    ELSE BEGIN  
      
        --Validate @Entity_ID  
        IF (@DerivedHierarchy_ID IS NULL OR @DerivedHierarchy_ID = 0) EXECUTE @IsValidParam = mdm.udpIDParameterCheck @Entity_ID, 5,NULL,NULL,0  
        IF (@IsValidParam = 0)  
        BEGIN  
            RAISERROR('MDSERR100004|The Entity ID is not valid.', 16, 1);  
            RETURN;  
        END;  
      
        --Validate DerivedHierarchy_ID  
        IF (@Entity_ID IS NULL OR @Entity_ID = 0) EXECUTE @IsValidParam  = mdm.udpIDParameterCheck @DerivedHierarchy_ID, 2,NULL,NULL,0  
        IF (@IsValidParam = 0)  
        BEGIN  
            RAISERROR('MDSERR100006|The DerivedHierarchy ID is not valid.', 16, 1);  
            RETURN;  
        END;  
      
    END;  
          
    --Business rule checks:     
    --  View can be based off Version or Version Flag  
    IF ((@ModelVersion_ID IS NULL OR @ModelVersion_ID = 0 ) AND (@ModelVersionFlag_ID IS NULL OR @ModelVersionFlag_ID = 0)) OR  
       (@ModelVersion_ID IS NOT NULL AND @ModelVersionFlag_ID IS NOT NULL)  
    BEGIN  
        RAISERROR('MDSERR100018|A subscription view can be generated for either a version or a version flag, but not for both.', 16, 1);  
        RETURN;  
      
    END;  
    ELSE BEGIN  
        --Validate ModelVersionFlag  
        IF (@ModelVersionFlag_ID IS NULL OR @ModelVersionFlag_ID = 0) EXECUTE @IsValidParam  = mdm.udpIDParameterCheck @ModelVersion_ID, 4,NULL,NULL,0  
        IF (@IsValidParam = 0)  
        BEGIN  
            RAISERROR('MDSERR100013|The Model Version Flag ID is not valid.', 16, 1);  
            RETURN;  
        END;  
  
        --Validate Model Version  
        IF(@ModelVersion_ID IS NULL OR @ModelVersion_ID = 0 ) EXECUTE @IsValidParam  = mdm.udpIDParameterCheck @ModelVersionFlag_ID, 10,NULL,NULL,0  
        IF (@IsValidParam = 0)  
        BEGIN  
            RAISERROR('MDSERR100012|The Model Version ID is not valid.', 16, 1);  
            RETURN;  
        END;  
    END;  
      
  -- Validate level greater than 0 is entered for Entity Levels or Derived Hierarchy Levels views    
   IF ( (@Entity_ID IS NOT NULL AND @ViewFormat_ID = 6 AND @Levels < 0) OR   
        (@DerivedHierarchy_ID IS NOT NULL AND @ViewFormat_ID = 8 AND @Levels < 0 ))  
   BEGIN   
            RAISERROR('MDSERR100019|The levels are not valid for the selected entity or derived hierarchy.', 16, 1);  
            RETURN;    
    END; --if   
          
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
      
                          
        --Update/Insert SubscriptionView  
        IF (@SubscriptionView_ID IS NOT NULL) BEGIN --Update SubscriptionView  
              
            -- Delete Subscription View  
            EXEC mdm.udpSubscriptionViewDeleteByID @SubscriptionView_ID, 0  
              
            UPDATE mdm.tblSubscriptionView  
                SET Entity_ID = @Entity_ID,  
                    Model_ID = ISNULL(@Model_ID, Model_ID),  
                    DerivedHierarchy_ID = @DerivedHierarchy_ID,  
                    ViewFormat_ID = ISNULL(@ViewFormat_ID, ViewFormat_ID),  
                    ModelVersion_ID = @ModelVersion_ID,  
                    ModelVersionFlag_ID = @ModelVersionFlag_ID,  
                    [Name] = @SubscriptionViewName,  
                    Levels = @Levels  
            WHERE ID = @SubscriptionView_ID  
                      
            --Populate output parameters  
            SELECT @Return_MUID = MUID FROM mdm.tblSubscriptionView WHERE ID = @Entity_ID;  
          
                      
        END  
        ELSE BEGIN  -- Insert SubscriptionView  
              
            --Accept an explicit MUID (for clone operations) or generate a new one  
            SET @Return_MUID = ISNULL(@Return_MUID, NEWID());  
              
            INSERT INTO mdm.tblSubscriptionView	(  
                    Entity_ID,  
                    Model_ID,  
                    DerivedHierarchy_ID,  
                    ViewFormat_ID,  
                    ModelVersion_ID,  
                    ModelVersionFlag_ID,  
                    [Name],  
                    Levels,  
                    MUID)  
            VALUES (  
                    @Entity_ID,  
                    @Model_ID,  
                    @DerivedHierarchy_ID,  
                    @ViewFormat_ID,  
                    @ModelVersion_ID,  
                    @ModelVersionFlag_ID,  
                    @SubscriptionViewName,  
                    @Levels,  
                    @Return_MUID)  
              
            --Save the identity value  
            SET @SubscriptionView_ID =  SCOPE_IDENTITY();	  
        END  
  
                      
        --Return values  
        SET @Return_ID = @SubscriptionView_ID;  
          
        -- Regenerate Subscription View	  
        EXEC mdm.udpCreateSubscriptionViews @Return_ID, @Entity_ID, @Model_ID,	@DerivedHierarchy_ID, @ModelVersion_ID,	@ModelVersionFlag_ID, @ViewFormat_ID, @Levels,	@SubscriptionViewName  
  
        --Commit only if we are not nested  
        IF @TranCounter = 0 COMMIT TRANSACTION;  
        RETURN(0);  
  
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
  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RETURN(1);  
          
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
