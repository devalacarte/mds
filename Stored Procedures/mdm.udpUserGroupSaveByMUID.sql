SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE  [mdm].[udpUserGroupSaveByMUID]  
(  
    @SystemUser_ID	INT,  
    @UserGroup_MUID	UNIQUEIDENTIFIER = NULL,  
    @UserGroupType_ID INT,   
    @Status_ID		INT = 0, -- 1=Active, 2=Delete, 3=Copy  
    @SID			NVARCHAR(250) = NULL,  
    @Name			NVARCHAR(355) = NULL,  
    @Description	NVARCHAR(256) = NULL,  
    @Return_ID      INT = NULL OUTPUT,  
    @Return_MUID		UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS   
BEGIN    
    SET NOCOUNT ON    
    
    DECLARE @NewUserGroup_ID	INT,    
    @Role_ID			INT,    
    @NewRole_ID			INT,    
    @ErrorMessage       NVARCHAR(4000),     
    @UserGroup_ID	INT    
  
    --Try to locate the record using the supplied muid.  
    IF (@UserGroup_MUID IS NOT NULL AND @UserGroup_MUID <> 0x0 AND (EXISTS (SELECT MUID FROM mdm.tblUserGroup WHERE MUID = @UserGroup_MUID)) )    
        BEGIN  
            IF (@Status_ID = 3)  OR (@Status_ID = 1)  
            BEGIN    
                SELECT @Status_ID = 1  -- update the existing user group.     
                SELECT @UserGroup_ID = (SELECT ID FROM mdm.tblUserGroup WHERE MUID = @UserGroup_MUID AND Status_ID = 1)    
                Print @UserGroup_ID  
            END  
    END  
    If(@Status_ID = 0)    
            BEGIN    
                SELECT @UserGroup_MUID = newid() -- Create might be needed.     
                ---Check if an inactive group exist.Find the group    
                --Print 'Check if group exist.Find the group'  
                IF ((@SID  Is NULL OR LEN(@SID) = 0) AND (@Name IS NULL OR LEN(@Name) = 0) )    
                    SELECT @UserGroup_ID = 0    
                ELSE    
                BEGIN    
                    IF (@SID IS NOT NULL AND LEN(@SID) <> 0)    
                        --Print 'Try to locate using SID'  
                    BEGIN  
                        --SID takes priority over name. And the sid can locate a unique record.  
                         If( (SELECT COUNT(*) from mdm.tblUserGroup where SID = @SID)  = 1)  
                            SELECT 	@UserGroup_ID = U.ID FROM mdm.tblUserGroup AS U  WHERE U.SID = @SID    
                      
                        --If group id 0 use the name and sid to find the the group id.    
                        If((@UserGroup_ID = 0 OR @UserGroup_ID is NULL) AND @Name IS NOT NULL AND LEN(@Name) <> 0)  
                        BEGIN  
                             If( (SELECT COUNT(*) from mdm.tblUserGroup where SID = @SID AND Name = @Name)  = 1)  
                                 SELECT 	@UserGroup_ID = U.ID   FROM	mdm.tblUserGroup AS U WHERE U.Name = @Name  AND U.SID = @SID     
                              Else if ((SELECT COUNT(*) from mdm.tblUserGroup where SID = @SID AND Name = @Name)  > 1)  
                                BEGIN    
                                    SELECT  @ErrorMessage = N'MDSERR500015|Name and Security Identifier (SID) combination must be unique for group update, create, and copy operations. Name: {0}, Security Identifier: {1}.|' + @Name + '|' + @SID;  
                                    RAISERROR(@ErrorMessage, 16, 1, @Name, @SID);  
                                    RETURN	    
                                END   
                        END  
                    END  
                    --If SID is empty or UserId is 0 use the name to find the user id.    
                    If(@Name IS NOT NULL AND LEN(@Name) <> 0 AND (@UserGroup_ID = 0 OR @UserGroup_ID IS NULL) )  
                    BEGIN  
                        --Print 'Try to locate using Name'  
                        IF @Name = CAST(N'Built-InAdministrator' AS NVARCHAR(100))    
                                SET @UserGroup_ID = 1;    
                        ELSE IF ((SELECT COUNT(*) from mdm.tblUserGroup where Name = @Name)  = 1)    
                            SELECT 	@UserGroup_ID = U.ID   FROM	mdm.tblUserGroup AS U WHERE U.Name = @Name     
                        ELSE IF ((SELECT COUNT(*) from mdm.tblUserGroup where Name = @Name)  > 1)  
                            BEGIN    
                                SELECT  @ErrorMessage = N'MDSERR500015|Name and Security Identifier (SID) combination must be unique for group update, create, and copy operations. Name: {0}, Security Identifier: {1}.|' + @Name + '|' + @SID;  
                                RAISERROR(@ErrorMessage, 16, 1, @Name, @SID);  
                                RETURN	    
                            END   
                    END  
                END  
                --PRINT @UserGroup_ID  
                IF(@UserGroup_ID <> 0 AND @UserGroup_ID IS NOT NULL)    
                    BEGIN    
                    IF ((SELECT Status_ID FROM mdm.tblUserGroup WHERE ID = @UserGroup_ID)= 2 )   
                        BEGIN  
                             UPDATE  mdm.tblUserGroup SET Status_ID = 1, [MUID] = @UserGroup_MUID WHERE ID = @UserGroup_ID   
                             SELECT @Status_ID = 1    
                        END  
                    ELSE  
                        BEGIN    
                            RAISERROR('MDSERR500016|A group with that name already exists.', 16, 1);  
                            RETURN	    
                        END   
                    END    
            END--End Status id check.    
    
    --Update the Group    
    IF (@Status_ID = 1)     
            BEGIN     
                IF (EXISTS (SELECT ID FROM mdm.tblUserGroup WHERE ID = @UserGroup_ID AND Status_ID = 1))    
                BEGIN    
                --PRINT @UserGroup_ID  
                    --Before we begin update lets check the sid and name combination to make sure its unique.    
                    IF (@SID IS NOT NULL Or @Name IS NOT NULL)     
                    IF (((SELECT COUNT(*) FROM mdm.tblUserGroup WHERE SID = ISNULL(@SID, SID) AND [Name] = ISNULL(@Name, [Name])) > 1 )  OR  
                        (SELECT ID FROM mdm.tblUserGroup WHERE SID = ISNULL(@SID, SID) AND [Name] = ISNULL(@Name, [Name])) != @UserGroup_ID )     
                    BEGIN    
                        SELECT  @ErrorMessage = N'MDSERR500015|Name and Security Identifier (SID) combination must be unique for group update, create, and copy operations. Name: {0}, Security Identifier: {1}.|' + @Name + '|' + @SID;  
                        RAISERROR(@ErrorMessage, 16, 1, @Name, @SID);  
                        RETURN	    
                    END   
                      
                      
                    UPDATE    
                        tblUserGroup    
                    SET    
                        Status_ID = ISNULL(@Status_ID,Status_ID),    
                        UserGroupType_ID = ISNULL(@UserGroupType_ID, UserGroupType_ID),    
                        SID = ISNULL(@SID, SID),    
                        [Name] = ISNULL(@Name, [Name]),    
                        Description = ISNULL(@Description,Description),    
                        LastChgUserID = @SystemUser_ID,    
                        LastChgDTM = GETUTCDATE()    
                    FROM    
                        mdm.tblUserGroup    
                    WHERE    
                        ID = @UserGroup_ID   
                          
    
                    SELECT @Return_ID = @UserGroup_ID    
                    SELECT @Return_MUID = (SELECT MUID FROM mdm.tblUserGroup WHERE ID = @UserGroup_ID)    
                END    
            ELSE     
                BEGIN    
                    RAISERROR('MDSERR500004|The principal cannot be updated because the principal identifier is not valid. The identifier must have an existing GUID, name, or both.', 16, 1);  
                    RETURN	       
                END     
        END    
    ELSE    
        BEGIN    
        --Clone or Create    
        If(@Status_ID = 3 or @Status_ID = 0)    
        BEGIN    
        If(@Status_ID = 3 AND @UserGroup_MUID IS NULL OR @UserGroup_MUID = 0x0)  
        BEGIN    
            RAISERROR('MDSERR500004|The principal cannot be updated because the principal identifier is not valid. The identifier must have an existing GUID, name, or both.', 16, 1);  
            RETURN	       
        END     
          
        INSERT INTO mdm.tblUserGroup    
            (    
            [UserGroupType_ID],    
            [Status_ID] ,    
            [Name] ,    
            [SID],    
            [Description],    
            [EnterDTM] ,    
            [EnterUserID]  ,    
            [LastChgDTM] ,    
            [LastChgUserID],    
            [MUID]    
            )    
    
        SELECT    
            @UserGroupType_ID,    
            1,    
            ISNULL(@Name,N''),    
            @SID,    
            ISNULL(@Description,N''),    
            GETUTCDATE(),    
            @SystemUser_ID,    
            GETUTCDATE(),    
            @SystemUser_ID,    
            @UserGroup_MUID    
    
        SELECT @NewUserGroup_ID = SCOPE_IDENTITY()    
        SELECT @Return_ID = @NewUserGroup_ID    
        SELECT @Return_MUID = (SELECT MUID FROM mdm.tblUserGroup WHERE ID = @NewUserGroup_ID)    
            
        END    
            
    
    END    
    IF @@ERROR <> 0    
        BEGIN    
            RAISERROR('MDSERR500060|The group cannot be saved. A database error occurred.', 16, 1);  
            RETURN(1)	        
        END    
    
    SET NOCOUNT OFF    
END  
--proc
GO
