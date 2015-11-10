SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpUserSaveByMUID]  
(  
    @SystemUser_ID    INT, --Person performing save  
   @User_ID        INT,  
   @User_MUID	   UNIQUEIDENTIFIER = NULL,  
   @SID            NVARCHAR(250),  
   @UserName       NVARCHAR(100), --Username  
   @Status_ID      INT = 0, -- 1=Active, 0=Create, 3=Clone  
   @DisplayName    NVARCHAR(256) = NULL,  
   @Description    NVARCHAR(500) = NULL,  
   @EmailAddress   NVARCHAR(250) = NULL,  
   @Return_ID      INT = NULL OUTPUT,  
   @Return_MUID    UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @NewUser_ID	INT  
    DECLARE @Role_ID	INT  
    DECLARE @NewRole_ID INT  
        print @User_MUID  
    --This is a user update or clone.   
    IF (@User_MUID IS NOT NULL AND CAST(@User_MUID  AS BINARY) <> 0x0 AND (EXISTS (SELECT MUID FROM mdm.tblUser WHERE MUID = @User_MUID)) )  
        BEGIN  
            If(@Status_ID = 3)  
            BEGIN   
                --Since the user exist. Set Status Id to 1 and update the user.  
                SELECT @Status_ID = 1  
            END  
  
            If(@Status_ID = 1) --update operation, ignore the User_ID and get it from the table  
            BEGIN   
                SELECT @User_ID = (SELECT ID FROM mdm.tblUser WHERE MUID = @User_MUID AND Status_ID = 1)  
            END  
        END  
    ELSE  
        BEGIN   
            If(@Status_ID =0 )  
            BEGIN  
                SELECT @User_MUID = newid() -- Create might be needed.   
                 ---Check is user exists.Find the user.  
                IF ((@SID  Is NULL OR LEN(@SID) = 0) AND (@UserName IS NULL OR LEN(@UserName) = 0) )  
                    SELECT @User_ID = NULL  
                ELSE  
                BEGIN  
                    IF (@SID IS NOT NULL AND LEN(@SID) <> 0)  
                        --SID takes priority over name  
                        SELECT 	@User_ID = U.ID   
                        FROM 	mdm.tblUser AS U  
                        WHERE	U.SID = @SID   
                        AND (U.Status_ID = 1 OR U.Status_ID = 2);  
                      
                    --If SID is empty or UserId is null use the name to find the user id.  
                    IF @User_ID IS NULL AND @UserName = CAST(N'Built-InAdministrator' AS NVARCHAR(100))  
                        SET @User_ID = 1;  
                    ELSE IF (@User_ID IS NULL)  
                        SELECT 	@User_ID = U.ID   
                        FROM 	mdm.tblUser AS U  
                        WHERE	U.UserName = @UserName   
                        AND (U.Status_ID = 1 OR U.Status_ID = 2);  
                END  
                IF(@User_ID <> 0)  
                    BEGIN  
                     UPDATE  mdm.tblUser SET Status_ID = 1, [MUID] = @User_MUID WHERE ID = @User_ID  
                     SELECT @Status_ID = 1  
                    END  
            END--End Status id check.  
        END  --End MUID CHECK   
  
    IF (@Status_ID = 1)   
    BEGIN  
        IF (EXISTS (SELECT ID FROM mdm.tblUser WHERE ID = @User_ID AND Status_ID = 1))  
        BEGIN  
          UPDATE  
             mdm.tblUser  
          SET  
             SID = ISNULL(@SID,SID),  
             UserName = @UserName,  
             Status_ID = ISNULL(@Status_ID,Status_ID),  
             DisplayName = ISNULL(@DisplayName,DisplayName),  
             Description = ISNULL(@Description,Description),  
             EmailAddress = ISNULL(@EmailAddress,EmailAddress),  
             LastChgUserID = @SystemUser_ID,  
             LastChgDTM = GETUTCDATE()  
          FROM  
             mdm.tblUser  
          WHERE  
             ID = @User_ID  
         
          SELECT @Return_ID = @User_ID  
          SELECT @Return_MUID = (SELECT MUID FROM mdm.tblUser WHERE ID = @User_ID)  
              
       END  
      ELSE  
        BEGIN  
            RAISERROR('MDSERR500004|The principal cannot be updated because the principal identifier is not valid. The identifier must have an existing GUID, name, or both.', 16, 1);  
            RETURN       
        END  
    END  
    ELSE   
       BEGIN  
        If(@Status_ID = 3 or @Status_ID = 0)  
            BEGIN  
          INSERT INTO mdm.tblUser  
             (  
             [Status_ID],  
             [SID],  
             [UserName],  
             [DisplayName],  
             [Description],  
             [EmailAddress],  
             [LastLoginDTM],  
             [EnterDTM],  
             [EnterUserID],  
             [LastChgDTM],  
             [LastChgUserID],  
             [MUID]  
             )  
          SELECT  
             1,  
             @SID,  
             @UserName,  
             ISNULL(@DisplayName,N''),  
             ISNULL(@Description,N''),     
             ISNULL(@EmailAddress,N''),  
             NULL,  
             GETUTCDATE(),  
             @SystemUser_ID,  
             GETUTCDATE(),  
             @SystemUser_ID,  
             @User_MUID  
  
  
          SELECT @NewUser_ID=SCOPE_IDENTITY()  
          SELECT @Return_ID = @NewUser_ID  
          SELECT @Return_MUID = (SELECT MUID FROM mdm.tblUser WHERE ID = @NewUser_ID)  
          END  
  
       END  
  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR500055|The user cannot be saved. A database error occurred.', 16, 1);  
            RETURN(1)       
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
