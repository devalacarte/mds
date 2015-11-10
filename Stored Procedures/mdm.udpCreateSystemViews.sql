SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    mdm.udpCreateSystemViews  
*/  
CREATE PROCEDURE [mdm].[udpCreateSystemViews]  
(  
    @Model_ID	INT,  
    @NewItem	INT = 0 --any non zero value results in only that entity being generated  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Defer view generation if we are in the middle of an upgrade or demo-rebuild  
    IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
        DECLARE @Entity_ID 			INT,  
                @Type_ID			INT,  
                @EntityName 		sysname,  
                @IsFlat				BIT,  
                @SQL				NVARCHAR(MAX);  
          
        DECLARE @TempTable TABLE   
        (  
             RowNumber	INT IDENTITY (1, 1) PRIMARY KEY CLUSTERED NOT NULL   
            ,ID			INT NOT NULL  
            ,IsFlat		BIT NOT NULL  
        );  
  
        SET @NewItem = ISNULL(@NewItem, 0);  
                      
        --Start transaction, being careful to check if we are nested	  
        DECLARE @TranCounter INT;   
        SET @TranCounter = @@TRANCOUNT;  
        IF @TranCounter > 0 SAVE TRANSACTION TX;  
        ELSE BEGIN TRANSACTION;  
          
        BEGIN TRY  
            INSERT INTO @TempTable   
            SELECT ID, IsFlat   
            FROM mdm.tblEntity   
            WHERE Model_ID = @Model_ID AND ((@NewItem = 0) OR (ID = @NewItem));  
                          
            DECLARE @Counter INT = 1 ;  
            DECLARE @MaxCounter INT = (SELECT MAX(RowNumber) FROM @TempTable);  
            --Delete Views.    
            IF @NewItem = 0  
            BEGIN  
                EXEC mdm.udpDeleteViews @Model_ID , 1  
            END  
              
            WHILE @Counter <= @MaxCounter  
                BEGIN  
              
                SELECT @Entity_ID = ID  
                    , @IsFlat = IsFlat   
                FROM @TempTable   
                WHERE [RowNumber] = @Counter;  
                  
                --Leaf Views  
                EXEC mdm.udpCreateSystemAttributeViews @Entity_ID, 1, 0;					  
                EXEC mdm.udpCreateSystemAttributeViews @Entity_ID, 1, 4;					  
  
                IF @IsFlat = 0 BEGIN  
                    --Consolidated Views  
                    EXEC mdm.udpCreateSystemAttributeViews @Entity_ID, 2, 0;						  
                    EXEC mdm.udpCreateSystemAttributeViews @Entity_ID, 2, 4;						  
  
                    --Collection Views  
                    EXEC mdm.udpCreateSystemAttributeViews @Entity_ID, 3, 0;						  
                    EXEC mdm.udpCreateSystemAttributeViews @Entity_ID, 3, 4;  
                      
                END; --if  
  
                IF @IsFlat = 0 BEGIN  
                    --Standard Hierarchy Views  
                    EXEC mdm.udpCreateSystemLevelViews @Entity_ID;  
                    EXEC mdm.udpCreateSystemParentChildViews @Entity_ID;  
                    EXEC mdm.udpCreateSystemEXPViews @Entity_ID, 2;  
                    EXEC mdm.udpCreateSystemEXPViews @Entity_ID, 3;  
                END; --if  
                --Leaf XML - must be after the consolidated views as it consumes them  
                EXEC mdm.udpCreateSystemEXPViews @Entity_ID, 1;  
  
                SET @Counter = @Counter+1;  
  
            END; --while  
              
  
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
