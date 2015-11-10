SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    Creates notifications from any validation issues in the tblValidationLog table.  
      
    EXEC mdm.udpValidationIssueEH;  
  
    SELECT * FROM mdm.tblNotificationQueue;  
*/  
CREATE PROCEDURE [mdm].[udpValidationIssueEH]  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
         @TempTable TABLE (ID INT NOT NULL);  
    DECLARE @NotificationType INT;  
      
    --Get the Notification Type ID for Validation Issues  
    SELECT @NotificationType = [ID] FROM mdm.tblNotificationType WHERE [Description] = CAST(N'Validation Issue' AS NVARCHAR(100));  
  
    IF (@NotificationType IS NULL) BEGIN  
        RAISERROR('MDSERR100028|Notification Type ''Validation Issue'' not found.', 16, 1);  
        RETURN;    
    END; --if  
       
    --Use a temporary table to keep track of all ID's affected  
    INSERT INTO @TempTable   
    SELECT DISTINCT ValidationIssue_ID  
    FROM mdm.viw_SYSTEM_ISSUE_NOTIFICATION;  
  
    BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        INSERT INTO mdm.tblNotificationQueue (  
            NotificationType_ID,  
            NotificationSourceID,  
            Version_ID,  
            Model_ID,  
            Entity_ID,  
            Hierarchy_ID,  
            Member_ID,  
            MemberType_ID,  
            [Description],  
            [Message],  
            BRBusinessRule_ID,  
            PriorityRank,  
            EnterDTM,  
            EnterUserID,  
            DueDTM  
        ) SELECT DISTINCT   
            @NotificationType,  
            v.ValidationIssue_ID,  
            v.Version_ID,  
            v.Model_ID,  
            v.Entity_ID,  
            CASE WHEN v.Hierarchy_ID = 0 THEN NULL ELSE v.Hierarchy_ID END,  
            v.Member_ID,  
            v.MemberType_ID,  
            v.ConditionText,  
            N'<notification>' +  
                N'<id>' + convert(NVARCHAR,v.ValidationIssue_ID) + N'</id>' +  
                N'<model>' + (SELECT v.ModelName FOR XML PATH('')) + N'</model>' +  
                N'<model_id>' + convert(NVARCHAR, v.Model_ID) + N'</model_id>' +  
                N'<version>' + (SELECT v.VersionName FOR XML PATH('')) + N'</version>' +  
                N'<version_id>' + convert(NVARCHAR, v.Version_ID) + N'</version_id>' +  
                N'<entity>' + (SELECT v.EntityName FOR XML PATH('')) + N'</entity>' +  
                N'<entity_id>' + convert(NVARCHAR, v.Entity_ID) + N'</entity_id>' +  
                N'<member_code>' + (SELECT v.MemberCode FOR XML PATH('')) + N'</member_code>' +  
                N'<member_id>' + convert(NVARCHAR, v.Member_ID) + N'</member_id>' +  
                N'<member_type_id>' + convert(NVARCHAR, v.MemberType_ID) + N'</member_type_id>' +  
                N'<condition_text>' + (SELECT v.ConditionText FOR XML PATH('')) + N'</condition_text>' +  
                N'<action_text>' + (SELECT v.ActionText FOR XML PATH('')) + N'</action_text>' +  
                N'<priority>' + convert(NVARCHAR,v.PriorityRank) + N'</priority>' +  
                N'<issued>' + (SELECT convert(NVARCHAR,v.DateCreated) FOR XML PATH('')) + N'</issued>' +  
                N'<due>' + CASE WHEN v.DateDue is NULL THEN N'None' ELSE convert(NVARCHAR,v.DateDue) END + N'</due>' +  
                N'<hours_past_due>' + CASE WHEN v.DateDue is NULL THEN N'0' WHEN GETUTCDATE() >= v.DateDue THEN convert(NVARCHAR,datediff(hour,v.DateDue,GETUTCDATE())) ELSE N'0' END + N'</hours_past_due>' +  
            N'</notification>',  
            v.BusinessRuleID,  
            v.PriorityRank,  
            v.DateCreated,  
            i.EnterUserID,  
            v.DateDue  
        FROM @TempTable	t   
            INNER JOIN mdm.viw_SYSTEM_ISSUE_NOTIFICATION v ON t.ID = v.ValidationIssue_ID  
            LEFT JOIN mdm.tblValidationLog i ON t.ID = i.ID  
            LEFT JOIN mdm.tblBRBusinessRule b on v.BusinessRuleID = b.[ID]  
        WHERE b.NotificationUserID IS NOT NULL OR b.NotificationGroupID IS NOT NULL;   
  
          
        -- If a notification queue record was inserted then insert the necessary mdm.tblNotificationUsers records.  
        IF (@@ROWCOUNT > 0)   
        BEGIN		  
            INSERT INTO mdm.tblNotificationUsers (  
                Notification_ID,  
                [User_ID]  
            )  
            SELECT q.ID,v.[User_ID]  
            FROM @TempTable	t   
            INNER JOIN mdm.viw_SYSTEM_ISSUE_NOTIFICATION v ON t.ID = v.ValidationIssue_ID  
            INNER JOIN mdm.tblNotificationQueue q ON t.ID = q.NotificationSourceID  
            WHERE q.NotificationType_ID = @NotificationType AND v.User_ID IS NOT NULL;  
        END  
  
        --Now Flag the Issue as being sent to Notification Queue  
        UPDATE vl   
        SET NotificationStatus_ID = 1  
        FROM mdm.tblValidationLog vl  
        INNER JOIN @TempTable t ON vl.ID = t.ID  
  
        COMMIT TRANSACTION;  
  
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
  
        ROLLBACK TRANSACTION;  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
        RETURN;  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
