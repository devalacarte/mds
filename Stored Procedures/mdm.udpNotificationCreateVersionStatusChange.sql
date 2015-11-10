SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    select * from mdm.viw_SYSTEM_SCHEMA_VERSION where ID = 20;  
  
    EXEC mdm.udpNotificationCreateVersionStatusChange 1, 20, 1;  
  
    SELECT * FROM mdm.tblNotificationQueue;  
*/  
CREATE PROCEDURE [mdm].[udpNotificationCreateVersionStatusChange]  
(  
     @User_ID INT  
    ,@Version_ID INT  
    ,@PriorStatus_ID INT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
        @NotificationType INT,	          
        @LocalizedNotificationTypeName NVARCHAR(100) = N'Version Status Change',  
        @LocalizedPriorStatus NVARCHAR(100) = N'',  
        @LocalizedNewStatus NVARCHAR(100) = N'',  
        @CurrentLanguageCode INT = 1033, -- Default language code is English (US).  
        @StringLanguageCode NVARCHAR(100) = N'',  
        @ErrorMsg NVARCHAR(MAX);  
              
      
    --Get the Notification Type ID for Validation Issues  
    SELECT @NotificationType = [ID] FROM mdm.tblNotificationType WHERE [Description] = @LocalizedNotificationTypeName;  
  
    IF (@NotificationType IS NULL) BEGIN  
        RAISERROR('MDSERR100028|Notification Type ''Validation Issue'' not found.', 16, 1);  
        RETURN;    
    END; --if  
  
    -- Use default language code to get the notification language code.  
    SELECT @StringLanguageCode = mdm.udfLocalizedStringGet(N'NotificationLCID', @CurrentLanguageCode, 1033);  
      
    IF @StringLanguageCode <> N'' BEGIN  
        SELECT @CurrentLanguageCode = CONVERT(INT, @StringLanguageCode)  
    END; -- if  
  
    SELECT @LocalizedPriorStatus = L.[ListOption] FROM mdm.tblList L WHERE L.ListCode = N'lstVersionStatus' AND L.OptionID = @PriorStatus_ID;  
    SELECT @LocalizedNewStatus = v.[Status] FROM mdm.viw_SYSTEM_SCHEMA_VERSION v WHERE v.ID = @Version_ID;  
  
    -- Get the localized message texts based on the notification language code in tblLocalizedStrings.  
    SELECT @LocalizedNotificationTypeName = mdm.udfLocalizedStringGet(N'NotificationVersionStatusChange', @CurrentLanguageCode, @LocalizedNotificationTypeName);  
    SELECT @LocalizedPriorStatus = mdm.udfLocalizedStringGet(N'NotificationVersionStatus' + @LocalizedPriorStatus, @CurrentLanguageCode, @LocalizedPriorStatus);  
    SELECT @LocalizedNewStatus = mdm.udfLocalizedStringGet(N'NotificationVersionStatus' + @LocalizedNewStatus, @CurrentLanguageCode, @LocalizedNewStatus);  
              
    SELECT @LocalizedPriorStatus = IsNULL(@LocalizedPriorStatus, N'');  
    SELECT @LocalizedNewStatus = IsNULL(@LocalizedNewStatus, N'');  
      
    BEGIN TRAN  
        DECLARE @newQueueRecord AS TABLE (ID INT, Model_ID INT);  
          
        INSERT INTO mdm.tblNotificationQueue (  
             NotificationType_ID  
            ,NotificationSourceID  
            ,Version_ID  
            ,Model_ID  
            ,[Description]  
            ,[Message]  
            ,EnterDTM  
            ,EnterUserID  
        )  
        OUTPUT inserted.ID, inserted.Model_ID INTO @newQueueRecord  
        SELECT    
            @NotificationType  
            ,v.ID  
            ,v.ID  
            ,v.Model_ID  
            ,@LocalizedNotificationTypeName  
            ,N'<notification>' +  
                N'<model>' + (SELECT v.[Model_Name] FOR XML PATH('')) + N'</model>' +  
                N'<model_id>' + CAST(v.[Model_ID] AS NVARCHAR(30)) + N'</model_id>' +  
                N'<version>' + (SELECT v.[Name] FOR XML PATH('')) + N'</version>' +  
                N'<version_description>' + (SELECT v.[Description] FOR XML PATH('')) + N'</version_description>' +  
                N'<version_id>' + CAST(v.[ID] AS NVARCHAR(30))  + N'</version_id>' +  
                N'<prior_status>' + @LocalizedPriorStatus  + N'</prior_status>' +  
                N'<new_status>' + @LocalizedNewStatus  + N'</new_status>' +  
                N'<issued>' + (SELECT convert(NVARCHAR,GETUTCDATE()) FOR XML PATH('')) + N'</issued>' +  
             N'</notification>'  
            ,GETUTCDATE()  
            ,@User_ID  
        FROM mdm.viw_SYSTEM_SCHEMA_VERSION v   
        WHERE v.ID = @Version_ID  
  
        IF (@@ERROR <> 0) BEGIN  
            RAISERROR('MDSERR100029|Cannot insert into notification queue because of general insert error.', 16, 1);  
            ROLLBACK TRAN;  
            RETURN;    
        END; --if  
  
        DECLARE @ModelUserList TABLE (  
             RowNumber INT IDENTITY(1,1) NOT NULL  
            ,ID INT  
            ,UserName NVARCHAR(MAX) COLLATE database_default  
            ,Name NVARCHAR(MAX) COLLATE database_default  
            ,Description NVARCHAR(MAX) COLLATE database_default  
            ,EmailAddress NVARCHAR(MAX) COLLATE database_default  
            ,Privilege_ID INT  
            ,Privilege_Name NVARCHAR(MAX) COLLATE database_default  
            );  
  
        DECLARE   
             @newQueueID INT  
            ,@Model_ID INT  
            ,@ModelObject_ID INT = 1  
            ,@DenyPriviledge INT = 1;  
  
        SELECT  
             @newQueueID = q.ID  
            ,@Model_ID = q.Model_ID  
        FROM @newQueueRecord q;  
                              
        INSERT INTO @ModelUserList EXECUTE mdm.udpUserListGetByItem @ModelObject_ID, @Model_ID   
          
        -- Insert into mdm.tblNotificationUsers  
        INSERT INTO mdm.tblNotificationUsers (  
            Notification_ID,  
            [User_ID]  
        )  
        SELECT @newQueueID, u.[ID]  
        FROM @ModelUserList u  
        WHERE u.Privilege_ID <> @DenyPriviledge;  
          
        IF (@@ERROR <> 0) BEGIN  
            RAISERROR('MDSERR100030|Cannot insert into notification users because of general insert error.', 16, 1);  
            ROLLBACK TRAN;  
            RETURN;    
        END; --if  
  
    COMMIT TRAN;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
