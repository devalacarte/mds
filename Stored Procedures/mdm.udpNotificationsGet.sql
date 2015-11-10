SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
EXEC mdm.udpNotificationsGet  
  
*/  
CREATE PROCEDURE [mdm].[udpNotificationsGet]  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @notifications TABLE (  
         RowNumber INT IDENTITY(1,1) NOT NULL  
        ,ID INT NOT NULL  
        ,NotificationTypeID INT NOT NULL  
        ,UserID INT  
        ,VersionID INT  
        ,EntityID INT  
        ,MemberID INT  
        ,MemberTypeID INT  
        ,BusinessRule_ID INT  
        ,CanUserSeeNotification BIT NULL    
        );  
  
    --Use a temporary table to keep track of all ID's affected  
    INSERT INTO @notifications (ID, NotificationTypeID, UserID, VersionID, EntityID, MemberID, MemberTypeID, BusinessRule_ID, CanUserSeeNotification)  
    SELECT   
        DISTINCT nq.[ID], nq.NotificationType_ID, nu.[User_ID], nq.Version_ID, nq.Entity_ID, nq.Member_ID, nq.MemberType_ID, nq.BRBusinessRule_ID, 1  
    FROM mdm.tblNotificationQueue nq   
        INNER JOIN mdm.tblNotificationType nt ON nq.NotificationType_ID = nt.[ID]   
        INNER JOIN mdm.tblNotificationUsers nu ON nq.ID = nu.Notification_ID   
        INNER JOIN mdm.tblUser us ON nu.[User_ID] = us.[ID] AND ISNULL(us.EmailAddress,N'') <> N''  
    WHERE nq.SentDTM is Null   
      
    DECLARE   
        @id				    INT,  
        @notificationtypeId INT,  
        @userId 			INT,  
        @versionId  		INT,  
        @entityId	    	INT,  
        @memberId		    INT,  
        @memberTypeId	    INT,  
        @emptyCriteria      mdm.MemberGetCriteria,  
        @memberCount        INT;  
  
    DECLARE  
        @MemberReturnOptionData                     TINYINT = 1,  
        @MemberReturnOptionCount                    TINYINT = 2,  
        @MemberReturnOptionMembershipInformation    TINYINT = 4  
  
  
    -- Get a list of all users referenced in the notifications table, and for each user mark as hidden those   
    -- notifications that pertain to business rules that reference attributes that the user cannot see.  
    DECLARE @users TABLE (  
         RowNumber INT IDENTITY(1,1) NOT NULL  
        ,ID INT NOT NULL  
        );  
    INSERT INTO @users (ID) SELECT DISTINCT UserID FROM @notifications;  
    DECLARE @Counter INT    = 1,  
            @MaxCounter INT = (SELECT MAX(RowNumber) FROM @users);  
    WHILE @Counter <= @MaxCounter  
    BEGIN  
        SELECT TOP 1 @userId = ID FROM @users WHERE RowNumber = @Counter;  
        UPDATE @notifications   
        SET CanUserSeeNotification = 0  
        WHERE   
            UserID = @userId AND   
            (BusinessRule_ID IS NOT NULL AND  
            BusinessRule_ID NOT IN (SELECT BusinessRule_ID FROM mdm.udfSecurityUserBusinessRuleList(@userId, NULL, NULL)));  
        SET @Counter += 1;  
    END  
  
    -- Mark as hidden notifications where the user cannot see the Member.  
    SELECT @Counter = 1,  
           @MaxCounter = (SELECT MAX(RowNumber) FROM @notifications);  
    WHILE @Counter <= @MaxCounter  
    BEGIN  
        SELECT TOP 1  
             @id                 = ID  
            ,@notificationtypeId = NotificationTypeID   
            ,@userId             = UserID  
            ,@versionId          = VersionID  
            ,@entityId           = EntityID  
            ,@memberId           = MemberID  
            ,@memberTypeId       = MemberTypeID  
            ,@Counter            = RowNumber  
        FROM @notifications  
        WHERE   
            CanUserSeeNotification = 1 AND -- skip notifications that are already marked as hidden to the user.  
            RowNumber >= @Counter              
        ORDER BY RowNumber;  
          
        IF (@Counter IS NULL)  
        BEGIN  
            BREAK;  
        END;  
  
        IF (@entityId IS NOT NULL AND @memberId IS NOT NULL AND @memberTypeId IS NOT NULL)   
        BEGIN  
            -- Call udpMembersGet to determine if the user can see the member.  
            SET @memberCount = 0;  
            EXEC mdm.udpMembersGet     
                    @User_ID            = @userId,    
                    @Version_ID         = @versionId,    
                    @Hierarchy_ID       = NULL,    
                    @HierarchyType_ID   = NULL,  
                    @Entity_ID          = @entityId,    
                    @Parent_ID          = NULL,  
                    @Member_ID          = @memberId,  
                    @MemberType_ID      = @memberTypeId,    
                    @Attribute_ID       = NULL,  
                    @AttributeValue     = NULL,  
                    @PageNumber         = 1,    
                    @PageSize           = 0,    
                    @SortColumn         = NULL,    
                    @SortDirection      = NULL,    
                    @SearchTable        = @emptyCriteria,    
                    @AttributeGroup_ID  = NULL,    
                    @MemberReturnOption = @MemberReturnOptionCount, -- Getting the count is sufficient to determine if the user can see the member.  
                    @IDOnly             = 0,    
                    @ColumnString       = NULL,  
                    @MemberCount        = @memberCount OUTPUT;   
            IF (COALESCE(@memberCount, 0) = 0)  
            BEGIN  
                UPDATE @notifications SET CanUserSeeNotification = 0 WHERE RowNumber = @Counter;    
            END  
        END   
        SET @Counter += 1;  
    END  
  
    -- Get all Notifications due to be sent out, sorted by User then Type  
    SELECT	  
        DISTINCT  
        nq.[ID],  
        nq.NotificationType_ID,  
        nt.TextStyleSheet,  
        nt.HTMLStyleSheet,  
        nq.[Message],  
        nu.[User_ID],  
        us.EmailAddress,  
        up.PreferenceValue as EmailFormat,  
        ts.SettingValue as DefaultEmailFormat  
    FROM	  
        @notifications tt   
        INNER JOIN mdm.tblNotificationQueue nq ON tt.[ID] = nq.[ID]   
        INNER JOIN mdm.tblNotificationType nt ON nq.NotificationType_ID = nt.[ID]   
        INNER JOIN mdm.tblNotificationUsers nu ON nq.ID = nu.Notification_ID   
        INNER JOIN mdm.tblUser us ON nu.[User_ID] = us.[ID] AND tt.UserID = us.[ID]  
        LEFT JOIN  mdm.tblUserPreference up on nu.[User_ID] = up.[User_ID] and up.PreferenceName = N'lstEmail'   
        LEFT JOIN  mdm.tblSystemSetting ts ON ts.SettingName = N'EmailFormat'  
    WHERE  
        tt.CanUserSeeNotification = 1  
    ORDER BY  
        nq.NotificationType_ID,  
        nu.[User_ID]  
  
    SET NOCOUNT OFF  
END --proc
GO
