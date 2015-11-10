SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Adds or updates an administrator record (ID=1) in the MDS database.  
  
If the user name and/or SID is already present in the table as a non-administrator, the  
@PromoteNonAdmin parameter must be set to 1 to allow that user to be promoted to an  
administrator because doing so will result in the loss of any explicit permissions   
assignments for the user.  
  
Example  : EXEC [mdm].[udpSecuritySetAdministrator] @UserName='REDMOND\mdsusr03', @SID = 'S-1-5-21-2127521184-1604012920-1887927527-5587136', @PromoteNonAdmin = 1  
*/  
CREATE PROCEDURE [mdm].[udpSecuritySetAdministrator]  
    @UserName NVARCHAR(100),  
    @SID NVARCHAR(250),  
    @DisplayName NVARCHAR(256) = NULL,  
    @Description NVARCHAR(500) = NULL,  
    @EmailAddress NVARCHAR(100) = NULL,  
    @PromoteNonAdmin BIT = 0  
AS  
BEGIN  
    SET NOCOUNT ON;  
        
    DECLARE @ActiveStatus_ID	INT = 1,  
            @AdminUser_ID		INT = 1,  
            @AllowPermission_ID	BIT = 1,		  
            @User_ID			INT,  
            @UserForeignType_ID	TINYINT = 1;  
  
    --Validate @UserName  
    IF @UserName IS NULL   
    BEGIN  
        RAISERROR('MDSERR100037|The user name is not valid.', 16, 1);  
        RETURN;  
    END;--if  
  
    --Validate @SID  
    IF @SID IS NULL   
    BEGIN  
        RAISERROR('MDSERR100038|The Security Identifier (SID) is not valid.', 16, 1);  
        RETURN;  
    END;--if  
  
    --Start transaction, being careful to check if we are nested    
    DECLARE @TranCounter INT;    
    SET @TranCounter = @@TRANCOUNT;    
    IF @TranCounter > 0 SAVE TRANSACTION TX;    
    ELSE BEGIN TRANSACTION;    
    
    BEGIN TRY    
        --Create a new administrator record if none exists. This logic    
        --enables recovery from an accidential deletion of the administrator    
        --record and its permissions. Temporary identifiers are used for  
        --the record to ensure unique constraints are not violated on  
        --the user table.  
        IF NOT EXISTS(SELECT 1 FROM [mdm].[tblUser] WHERE ID = @AdminUser_ID)    
        BEGIN    
            SET IDENTITY_INSERT [mdm].[tblUser] ON;    
                
            INSERT INTO [mdm].[tblUser] (    
                ID,     
                Status_ID,    
                SID,     
                UserName,     
                DisplayName,     
                Description,     
                EmailAddress,     
                EnterDTM,     
                EnterUserID,     
                LastChgDTM,     
                LastChgUserID)    
            VALUES (    
                @AdminUser_ID,    
                @ActiveStatus_ID,    
                NEWID(),  
                NEWID(),  
                N'',    
                N'',    
                N'',    
                GETDATE(),    
                @AdminUser_ID,    
                GETDATE(),    
                @AdminUser_ID)    
                    
            SET IDENTITY_INSERT [mdm].[tblUser] OFF;    
        END   
  
        DECLARE @ExistingUserIDs mdm.IdList;  
          
        --Get the IDs of any existing records for the new administrator.  
        --Due to the unique constraints on the table, both SID and UserName  
        --must be compared.  
        INSERT INTO @ExistingUserIDs (ID)  
        SELECT ID   
        FROM [mdm].[tblUser]  
        WHERE   
            (UserName = @UserName OR SID = @SID)  
            AND ID <> @AdminUser_ID  
  
        --If any existing IDs for the new administrator are found,  
        --reassign ownership and audit information for those IDs to  
        --the administrator record and delete the existing user  
        --records.  
        IF EXISTS(SELECT 1 FROM @ExistingUserIDs)  
        BEGIN    
            --Only promote an existing non-admin user if allowed.    
            IF @PromoteNonAdmin <> 1    
            BEGIN    
                RAISERROR('MDSERR100109|The user already exists as a non-administrator. Set the @PromoteNonAdmin parameter to 1 to allow deletion of the existing user record.', 16, 1);    
                RETURN;    
            END    
            ELSE    
            BEGIN  
                DECLARE @ExistingUser_ID INT,  
                        @TableName NVARCHAR(MAX),  
                        @ColumnName NVARCHAR(MAX),  
                        @UpdateQuery NVARCHAR(MAX);  
              
                ----------------------------------------------------------------------  
                -- Remove existing user permissions and preferences.                --  
                ----------------------------------------------------------------------  
                --Prepare a cursor to remove all permissions for existing user records  
                -- and mark the records as inactive.  
                DECLARE InactivateUserCursor CURSOR FORWARD_ONLY FOR  
                SELECT ID  
                FROM @ExistingUserIDs  
                  
                OPEN InactivateUserCursor  
                FETCH NEXT FROM InactivateUserCursor  
                    INTO @ExistingUser_ID  
                  
                --Remove all security assignments and preferences for the user and  
                --deactivate the user account.  
                WHILE @@FETCH_STATUS = 0  
                BEGIN  
                    EXEC [mdm].[udpUserDelete] @AdminUser_ID, @ExistingUser_ID    
                    EXEC [mdm].[udpUserPreferencesDelete] @ExistingUser_ID  
                      
                    FETCH NEXT FROM InactivateUserCursor  
                    INTO @ExistingUser_ID  
                END  
  
                CLOSE InactivateUserCursor  
                DEALLOCATE InactivateUserCursor  
  
                ----------------------------------------------------------------------  
                -- Update notification entries for the new administrator.           --  
                ----------------------------------------------------------------------  
                UPDATE [mdm].[tblBRBusinessRule]  
                SET   
                    NotificationUserID = @AdminUser_ID  
                WHERE   
                    NotificationUserID IN (SELECT ID FROM @ExistingUserIDs)  
  
                ----------------------------------------------------------------------  
                -- Update foreign keys for the new administrator.                   --  
                ----------------------------------------------------------------------  
                --Prepare a cursor that can be used to update all foreign  
                --keys for existing user records to point to the administrator  
                --record.  
                DECLARE ForeignKeyCursor CURSOR FORWARD_ONLY FOR  
                SELECT  
                    QUOTENAME(FK.TABLE_SCHEMA) + N'.' + QUOTENAME(FK.TABLE_NAME) AS TableName,  
                    QUOTENAME(CU.COLUMN_NAME) AS ColumnName  
                FROM   
                    INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS C  
                    INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS FK ON C.CONSTRAINT_NAME = FK.CONSTRAINT_NAME  
                    INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS PK ON C.UNIQUE_CONSTRAINT_NAME = PK.CONSTRAINT_NAME  
                    INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU ON C.CONSTRAINT_NAME = CU.CONSTRAINT_NAME  
                WHERE   
                    PK.TABLE_SCHEMA = N'mdm'  
                    AND PK.TABLE_NAME = N'tblUser'  
  
                OPEN ForeignKeyCursor  
                FETCH NEXT FROM ForeignKeyCursor  
                    INTO @TableName, @ColumnName  
  
                --Update all foreign keys for the new admin user.  
                WHILE @@FETCH_STATUS = 0  
                BEGIN  
                    SET @UpdateQuery =   
                        N'UPDATE ' + @TableName   
                        + N' SET ' + @ColumnName + N' = @AdminUser_ID'  
                        + N' WHERE ' + @ColumnName + N' IN (SELECT ID FROM @ExistingUserIDs)';  
  
                    --PRINT @UpdateQuery;  
                      
                    EXEC sp_executesql @UpdateQuery, N'@AdminUser_ID INT, @ExistingUserIDs mdm.IdList READONLY',  
                        @AdminUser_ID = @AdminUser_ID,  
                        @ExistingUserIDs = @ExistingUserIDs;  
                      
                    FETCH NEXT FROM ForeignKeyCursor  
                        INTO @TableName, @ColumnName  
                END  
  
                CLOSE ForeignKeyCursor  
                DEALLOCATE ForeignKeyCursor  
  
                ----------------------------------------------------------------------  
                -- Update EnterUserID references for the new administrator.         --  
                ----------------------------------------------------------------------  
                --Prepare a cursor that can be used to update EnterUserID audit  
                --information to point to the administrator record.  
                DECLARE EnterUserIDCursor CURSOR FORWARD_ONLY FOR  
                SELECT  
                    QUOTENAME(C.TABLE_SCHEMA) + N'.' + QUOTENAME(C.TABLE_NAME) AS TableName,  
                    QUOTENAME(C.COLUMN_NAME) AS ColumnName  
                FROM   
                    INFORMATION_SCHEMA.COLUMNS C   
                WHERE TABLE_SCHEMA = N'mdm'  
                    AND COLUMN_NAME = N'EnterUserID'  
                    AND DATA_TYPE = N'int'  
                    AND EXISTS(SELECT 1 FROM sys.objects O  
                                WHERE O.type = N'U' -- USER TABLE  
                                AND O.object_id = OBJECT_ID(N'[' + C.TABLE_SCHEMA + N'].[' + C.TABLE_NAME + N']'))  
  
                OPEN EnterUserIDCursor  
                FETCH NEXT FROM EnterUserIDCursor  
                    INTO @TableName, @ColumnName  
  
                WHILE @@FETCH_STATUS = 0  
                BEGIN  
                    SET @UpdateQuery =   
                        N'UPDATE ' + @TableName   
                        + N' SET ' + @ColumnName + N' = @AdminUser_ID'  
                        + N' WHERE ' + @ColumnName + N' IN (SELECT ID FROM @ExistingUserIDs)';  
  
                    --PRINT @UpdateQuery;  
                      
                    EXEC sp_executesql @UpdateQuery, N'@AdminUser_ID INT, @ExistingUserIDs mdm.IdList READONLY',  
                        @AdminUser_ID = @AdminUser_ID,  
                        @ExistingUserIDs = @ExistingUserIDs;  
                      
                    FETCH NEXT FROM EnterUserIDCursor  
                        INTO @TableName, @ColumnName  
                END  
  
                CLOSE EnterUserIDCursor  
                DEALLOCATE EnterUserIDCursor  
  
                ----------------------------------------------------------------------  
                -- Update LastChgUserID references for the new administrator.       --  
                ----------------------------------------------------------------------  
                --Prepare a cursor that can be used to update LastChgUserID audit  
                --information to point to the administrator record.  
                DECLARE LastChgUserIDCursor CURSOR FORWARD_ONLY FOR  
                SELECT  
                    QUOTENAME(C.TABLE_SCHEMA) + N'.' + QUOTENAME(C.TABLE_NAME) AS TableName,  
                    QUOTENAME(C.COLUMN_NAME) AS ColumnName  
                FROM   
                    INFORMATION_SCHEMA.COLUMNS C   
                WHERE TABLE_SCHEMA = N'mdm'  
                    AND COLUMN_NAME = N'LastChgUserID'  
                    AND DATA_TYPE = N'int'  
                    AND EXISTS(SELECT 1 FROM sys.objects O  
                                WHERE O.type = N'U' -- USER TABLE  
                                AND O.object_id = OBJECT_ID(N'[' + C.TABLE_SCHEMA + N'].[' + C.TABLE_NAME + N']'))  
  
                OPEN LastChgUserIDCursor  
                FETCH NEXT FROM LastChgUserIDCursor  
                    INTO @TableName, @ColumnName  
  
                WHILE @@FETCH_STATUS = 0  
                BEGIN  
                    SET @UpdateQuery =   
                        N'UPDATE ' + @TableName   
                        + N' SET ' + @ColumnName + N' = @AdminUser_ID'  
                        + N' WHERE ' + @ColumnName + N' IN (SELECT ID FROM @ExistingUserIDs)';  
  
                    --PRINT @UpdateQuery;  
                      
                    EXEC sp_executesql @UpdateQuery, N'@AdminUser_ID INT, @ExistingUserIDs mdm.IdList READONLY',  
                        @AdminUser_ID = @AdminUser_ID,  
                        @ExistingUserIDs = @ExistingUserIDs;  
                      
                    FETCH NEXT FROM LastChgUserIDCursor  
                        INTO @TableName, @ColumnName  
                END  
  
                CLOSE LastChgUserIDCursor  
                DEALLOCATE LastChgUserIDCursor  
              
                BEGIN TRY    
                    --Attempt to delete the existing user record(s).  
                    DELETE FROM [mdm].[tblUser] WHERE ID IN (SELECT ID FROM @ExistingUserIDs)   
                END TRY    
                BEGIN CATCH    
                    --IF the deletion failed above, update the user name and SID  
                    --in the existing record(s) to avoid table constraint violations when   
                    --setting the new administrator record.    
                    UPDATE [mdm].[tblUser]     
                    SET   
                        UserName = CAST(MUID AS NVARCHAR(100)),  
                        SID = CAST(MUID AS NVARCHAR(100))   
                    WHERE   
                        ID IN (SELECT ID FROM @ExistingUserIDs)   
                END CATCH  
            END    
        END    
    
        --Update the administrator user record with the new values.  
        UPDATE [mdm].[tblUser]    
        SET     
            UserName = @UserName,    
            SID = @SID,    
            DisplayName = ISNULL(@DisplayName, @UserName),    
            EmailAddress = ISNULL(@EmailAddress, N''),    
            Description = ISNULL(@Description, N''),    
            Status_ID = @ActiveStatus_ID,    
            LastChgUserID = @AdminUser_ID,    
            LastChgDTM = GETDATE()    
        WHERE    
            ID = @AdminUser_ID    
    
        --Ensure the administrator has all navigation permissions.    
        DELETE FROM mdm.tblNavigationSecurity   
        WHERE   
            Foreign_ID = @AdminUser_ID   
            AND ForeignType_ID = @UserForeignType_ID  
              
        INSERT INTO [mdm].[tblNavigationSecurity]    
            (Navigation_ID, Foreign_ID, ForeignType_ID, Permission_ID, EnterUserID, LastChgUserID)     
        SELECT   
            ID, @AdminUser_ID, @UserForeignType_ID, @AllowPermission_ID, @AdminUser_ID, @AdminUser_ID     
        FROM   
            mdm.tblNavigation    
    
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
      
        RETURN(1);      
    END CATCH;  
      
    SET NOCOUNT OFF;  
END;
GO
