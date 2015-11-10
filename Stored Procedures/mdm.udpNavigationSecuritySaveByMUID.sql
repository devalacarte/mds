SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpNavigationSecuritySaveByMUID]  
(  
    @SystemUser_ID		INT,  
    @Principal_MUID		UNIQUEIDENTIFIER = NULL ,  
    @Principal_Name		NVARCHAR(64) = NULL,  
    @PrincipalType_ID	TINYINT,  
    @MUID				UNIQUEIDENTIFIER = NULL ,  
    @Navigation_ID		INT,  
    @Status_ID			INT = 0, --default behavior is create.  
    @Permission_ID		BIT = 0 ,  
    @Return_ID			INT = NULL OUTPUT,  
    @Return_MUID		UNIQUEIDENTIFIER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
    Declare @Principal_ID as INT  
    DECLARE @NewUser_ID	INT  
  
    --Lookup the integerIDs for the MUIDs  
    IF(@PrincipalType_ID =1)  
    BEGIN  
        IF( @Principal_MUID IS NOT NULL AND CAST(@Principal_MUID  AS BINARY) <> 0x0  
                    AND EXISTS(SELECT ID from mdm.tblUser WHERE MUID=@Principal_MUID))  
        BEGIN  
            SELECT @Principal_ID = (SELECT ID FROM mdm.tblUser WHERE MUID=@Principal_MUID)  
        END  
        ELSE   
        IF( @Principal_Name IS NOT NULL AND EXISTS(SELECT ID from mdm.tblUser WHERE UPPER(UserName) = UPPER(@Principal_Name)))  
        BEGIN  
            SELECT @Principal_ID = (SELECT ID FROM mdm.tblUser WHERE UPPER(UserName) = UPPER(@Principal_Name))  
        END  
    END  
    ELSE  
        BEGIN  
            IF(@PrincipalType_ID =2 )  
            BEGIN  
                IF( @Principal_MUID IS NOT NULL AND CAST(@Principal_MUID  AS BINARY) <>  0x0  
                        AND EXISTS(SELECT ID from mdm.tblUserGroup WHERE MUID=@Principal_MUID))  
                BEGIN  
                    SELECT @Principal_ID = (SELECT ID FROM mdm.tblUserGroup WHERE MUID=@Principal_MUID)  
                END  
                ELSE   
                IF( @Principal_Name IS NOT NULL AND EXISTS(SELECT ID from mdm.tblUserGroup WHERE UPPER(Name) = UPPER(@Principal_Name)))  
                BEGIN  
                SELECT @Principal_ID = (SELECT ID FROM mdm.tblUserGroup WHERE UPPER(Name) = UPPER(@Principal_Name))  
                END  
            END  
        END  
      
    IF(@Principal_ID IS null OR @Principal_ID =0)  
        BEGIN  
            RAISERROR('MDSERR500023|The navigation cannot be saved. The Principal ID is not valid.', 16, 1);  
            RETURN	      
        END  
  
    IF(@MUID IS NOT NULL AND CAST(@MUID  AS BINARY) <> 0x0 AND @Status_ID <>0 )  
    BEGIN  
        IF((EXISTS (SELECT MUID FROM mdm.tblNavigationSecurity WHERE MUID = @MUID)))  
            BEGIN  
                --Update the privileges as part of the clone operation.  
                UPDATE mdm.tblNavigationSecurity SET Permission_ID = @Permission_ID WHERE MUID = @MUID  
                RETURN(1)  
            END  
        ELSE   
            IF(@Status_ID = 3)  
                BEGIN  
                    --Clone  
                    INSERT INTO mdm.tblNavigationSecurity (Navigation_ID, Foreign_ID, ForeignType_ID, EnterDTM, EnterUserID, LastChgDTM, LastChgUserID, MUID, Permission_ID)  
                    SELECT @Navigation_ID,@Principal_ID,@PrincipalType_ID,GETUTCDATE(),@SystemUser_ID,GETUTCDATE(),@SystemUser_ID,@MUID,@Permission_ID;  
                    
                    SELECT @Return_ID = SCOPE_IDENTITY()  
                    SELECT @Return_MUID = (SELECT MUID FROM mdm.tblNavigationSecurity WHERE ID = @Return_ID)  
                    RETURN(1)  
                END  
            ELSE IF(@Status_ID = 1)  
                BEGIN  
                    --update failed.  
                    RAISERROR('MDSERR500009|The function permission cannot be updated because an existing identifier GUID is missing.', 16, 1);  
                    RETURN	  
                END  
    END  
    ELSE   
    IF (@Status_ID = 3)  
      BEGIN  
        --NO MUID was supplied. Look up the muid based on the supplied paramters. Clone operation behaves as update if exists if not report an error.  
        IF(EXISTS (SELECT MUID FROM mdm.tblNavigationSecurity WHERE Foreign_ID = @Principal_ID AND ForeignType_ID = @PrincipalType_ID AND Navigation_ID=@Navigation_ID))  
        BEGIN  
            --Update the privileges as part of the clone operation.  
            UPDATE mdm.tblNavigationSecurity SET Permission_ID = @Permission_ID WHERE Foreign_ID = @Principal_ID AND ForeignType_ID = @PrincipalType_ID AND Navigation_ID=@Navigation_ID     
            RETURN(1)  
        END  
        ELSE  
            --Clone failed. NO Muid was supplied.   
            RAISERROR('MDSERR500008|The FunctionPrivilege cannot be copied because the GUID is missing or not valid.', 16, 1);  
            RETURN	  
      END  
    ELSE IF(@Status_ID = 1)  
        BEGIN  
           --NO MUID was supplied. Look up the muid based on the supplied paramters. Update if exists if not report an error.  
            IF(EXISTS (SELECT MUID FROM mdm.tblNavigationSecurity WHERE Foreign_ID = @Principal_ID AND ForeignType_ID = @PrincipalType_ID AND Navigation_ID=@Navigation_ID))  
            BEGIN  
                --Update the privileges as part of the clone operation.  
                UPDATE mdm.tblNavigationSecurity SET Permission_ID = @Permission_ID WHERE Foreign_ID = @Principal_ID AND ForeignType_ID = @PrincipalType_ID AND Navigation_ID=@Navigation_ID     
                RETURN(1)  
            END  
            ELSE  
                --udpate failed. NO Muid was supplied.   
                RAISERROR('MDSERR500009|The function permission cannot be updated because an existing identifier GUID is missing.', 16, 1);  
                RETURN	  
        END   
    --Create operation.Ignore the muid if one was supplied.  
    ELSE IF(@Status_ID = 0)  
        BEGIN  
            IF(EXISTS (SELECT MUID FROM mdm.tblNavigationSecurity WHERE Foreign_ID = @Principal_ID AND ForeignType_ID = @PrincipalType_ID AND Navigation_ID=@Navigation_ID))  
            BEGIN  
                  UPDATE mdm.tblNavigationSecurity SET Permission_ID = @Permission_ID WHERE Foreign_ID = @Principal_ID AND ForeignType_ID = @PrincipalType_ID AND Navigation_ID=@Navigation_ID     
                  RETURN(1)  
            END  
            ELSE  
            BEGIN  
                INSERT INTO mdm.tblNavigationSecurity (Navigation_ID, Foreign_ID, ForeignType_ID, EnterDTM, EnterUserID, LastChgDTM, LastChgUserID, MUID, Permission_ID)  
                SELECT @Navigation_ID,@Principal_ID,@PrincipalType_ID,GETUTCDATE(),@SystemUser_ID,GETUTCDATE(),@SystemUser_ID,newid(),@Permission_ID;  
            END  
                SELECT @Return_ID = SCOPE_IDENTITY()  
                SELECT @Return_MUID = (SELECT MUID FROM mdm.tblNavigationSecurity WHERE ID = @Return_ID)  
        END  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR500054|The navigation cannot be saved. A database error occurred.', 16, 1);  
            RETURN(1)	      
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
