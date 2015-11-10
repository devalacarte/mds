SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    The procedure assumes 1 and only 1 record should exists in the table.  
      
    exec mdm.udpSystemSave @SchemaVersion = '10.50.166.1234'  
*/  
CREATE PROCEDURE [mdm].[udpSystemSave]  
    @ProductName NVARCHAR(250)=NULL,   
    @ProductVersion NVARCHAR(250)=NULL,   
    @ProductRegistrationKey NVARCHAR(250)=NULL,   
    @SchemaVersion NVARCHAR(250)=NULL  
AS    
/*WITH*/  
BEGIN    
    SET NOCOUNT ON;    
    
    --Initialize output parameters and local variables    
    SELECT     
        @ProductName = NULLIF(LTRIM(RTRIM(@ProductName)), N''),    
        @ProductVersion = NULLIF(LTRIM(RTRIM(@ProductVersion)), N''),  
        @ProductRegistrationKey = NULLIF(LTRIM(RTRIM(@ProductRegistrationKey)), N''),   
        @SchemaVersion = NULLIF(LTRIM(RTRIM(@SchemaVersion)), N'')   
     
    IF EXISTS(SELECT 1 FROM mdm.tblSystem)  
    BEGIN  
        BEGIN TRY    
        
                UPDATE mdm.tblSystem  
                 SET [ProductName] = ISNULL(@ProductName, [ProductName])  
                  ,[ProductVersion] = ISNULL(@ProductVersion,[ProductVersion])  
                  ,[ProductRegistrationKey] = ISNULL(@ProductRegistrationKey,[ProductRegistrationKey])  
                  ,[SchemaVersion] = ISNULL(@SchemaVersion,[SchemaVersion])  
                  ,[LastChgUserID] = SYSTEM_USER   
                  ,[LastChgDTM] = GETUTCDATE()  
                 WHERE [ID] = (SELECT MAX([ID]) FROM mdm.tblSystem)  
            
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
        
            RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);    
        
            RETURN(1);    
        
        END CATCH;    
    END  
    SET NOCOUNT OFF;    
END;
GO
