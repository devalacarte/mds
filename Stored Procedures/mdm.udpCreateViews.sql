SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpCreateViews 1;  
    EXEC mdm.udpCreateAllViews;  
  
    --Test in context of upgrade/demo data build	  
    EXEC sp_getapplock @Resource=N'DeferViewGeneration', @LockMode='Exclusive', @LockOwner='Session', @LockTimeout=0;  
    EXEC mdm.udpCreateViews 1;  
    EXEC sp_releaseapplock @Resource = N'DeferViewGeneration', @LockOwner='Session';  
*/  
CREATE PROCEDURE [mdm].[udpCreateViews]  
(  
    @Model_ID	INT,  
    @NewItem	INT = 0  --any non zero means a new entity was added and we don't need to rebuild all of the views  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Defer view generation if we are in the middle of an upgrade or demo-rebuild  
    IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
        --Start transaction, being careful to check if we are nested  
        DECLARE @TranCounter INT;   
        SET @TranCounter = @@TRANCOUNT;  
        IF @TranCounter > 0 SAVE TRANSACTION TX;  
        ELSE BEGIN TRANSACTION;  
  
        BEGIN TRY  
  
            --deletion of existing procs is handled in udpCreateSystemViews so we don't need to call it here.  
            --Create system views  
            EXEC mdm.udpCreateSystemViews @Model_ID ,@NewItem  
  
            --Create derived hierarchy views  
            EXEC mdm.udpCreateDerivedHierarchyViews @Model_ID   
  
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
  
        END CATCH;  
  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
