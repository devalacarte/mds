SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesSaveByMUID]  
(  
    @SystemUser_ID      INT,  
    @Principal_MUID     UNIQUEIDENTIFIER,  
    @PrincipalType_ID   INT,  
    @Principal_Name     NVARCHAR(50) = NULL,  
    @PrincipalType_Name NVARCHAR(20) = NULL,  
    @RoleAccess_MUID    UNIQUEIDENTIFIER = NULL,  
    @Object_ID          INT,  
    @Privilege_ID       INT,  
    @Model_MUID         UNIQUEIDENTIFIER,  
    @Model_Name         NVARCHAR(100) = NULL,  
    @Securable_MUID     UNIQUEIDENTIFIER,  
    @Securable_Name     NVARCHAR(100)=NULL,  
    @Status_ID          INT = 0,  
    @Return_ID          INT = NULL OUTPUT,  
    @Return_MUID        UNIQUEIDENTIFIER = NULL OUTPUT   
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE   
        @Role_ID        INT,  
        @Description    NVARCHAR(100),  
        @Principal_ID   INT,  
        @Model_ID       INT,  
        @Securable_ID   INT,   
        @RoleAccess_ID  INT,  
        @NewUser_ID     INT,  
        @IsModelAdmin   BIT,  
        @Return_Value   INT,  
  
        --PrincipalTypes  
        @PrincipalType_UserAccount INT = 1,  
        @PrincipalType_Group INT = 2,  
  
        --Statuses  
        @Status_Create INT = 0,  
        @Status_Active INT = 1,  
        @Status_Inactive INT = 2,  
        @Status_Clone INT = 3  
    ;  
      
    --Lookup the integerIDs for the MUIDs  
    IF(@PrincipalType_ID = @PrincipalType_UserAccount)  
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
        IF(@PrincipalType_ID = @PrincipalType_Group )  
        BEGIN  
            IF( @Principal_MUID IS NOT NULL AND CAST(@Principal_MUID  AS BINARY) <> 0x0  
                    AND EXISTS(SELECT ID from mdm.tblUserGroup WHERE MUID=@Principal_MUID))  
            BEGIN  
                SELECT @Principal_ID = (SELECT ID FROM mdm.tblUserGroup WHERE MUID=@Principal_MUID)  
            END  
            ELSE IF( @Principal_Name IS NOT NULL AND EXISTS(SELECT ID from mdm.tblUserGroup WHERE UPPER(Name) = UPPER(@Principal_Name)))  
            BEGIN  
                SELECT @Principal_ID = (SELECT ID FROM mdm.tblUserGroup WHERE UPPER(Name) = UPPER(@Principal_Name))  
            END  
        END  
    END  
          
    IF @Principal_ID IS NULL OR @Principal_ID = 0   
    BEGIN  
        RAISERROR('MDSERR500025|The principal ID for the user or group is not valid.', 16, 1);  
        RETURN;     
    END  
  
    -- Find the role id.  
    SELECT      
        @Role_ID = Role_ID    
    FROM      
        mdm.tblSecurityAccessControl    
    WHERE      
        Principal_ID = @Principal_ID  AND  
        PrincipalType_ID = @PrincipalType_ID    
          
    --Check the Role Access MUID  
    IF(@RoleAccess_MUID IS NOT NULL AND CAST(@RoleAccess_MUID  AS BINARY) <> 0x0)  
    BEGIN  
        If( EXISTS(SELECT ID from mdm.tblSecurityRoleAccess WHERE MUID=@RoleAccess_MUID))  
        BEGIN  
            SELECT   
                @RoleAccess_ID = RoleAccess_ID,  
                @Model_MUID = Model_MUID,  
                @Securable_MUID =  Securable_MUID,  
                @Object_ID = Object_ID  
            FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL   
            WHERE RoleAccess_MUID = @RoleAccess_MUID  
        END  
    END  
    If( @Model_MUID IS NOT NULL AND CAST(@Model_MUID  AS BINARY) <> 0x0  
            AND EXISTS(SELECT ID from mdm.tblModel WHERE MUID=@Model_MUID))  
    BEGIN  
        SELECT @Model_ID = ID FROM mdm.tblModel WHERE MUID=@Model_MUID  
    END  
    ELSE IF ( @Model_Name IS NOT NULL AND EXISTS(SELECT ID from mdm.tblModel WHERE Name=@Model_Name))  
    BEGIN  
        SELECT @Model_ID = ID, @Model_MUID = MUID FROM mdm.tblModel WHERE  Name=@Model_Name  
    END  
    ELSE  
    BEGIN  
        RAISERROR('MDSERR500027|The model permission cannot be saved. The model GUID is not valid.', 16, 1);  
        RETURN;  
    END  
  
    EXEC mdm.udpUserIsModelAdministrator @User_ID=@SystemUser_ID, @ObjectType_ID=1, @Object_MUID=@Model_MUID, @Object_Name=NULL, @ObjectContext_MUID=NULL,   
        @ObjectContext_Name=NULL, @Return_ID=@IsModelAdmin output  
  
    IF @IsModelAdmin = 0  
    BEGIN  
        RAISERROR('MDSERR120002|The user does not have permission to perform this operation.', 16, 1);  
        RETURN;  
    END  
  
    SELECT @Securable_ID = [mdm].[udfSecurableIDGetByObjectID](@Object_ID, @Securable_MUID, @Securable_Name)  
  
    If(@Securable_ID IS NULL OR @Securable_ID = 0 )  
    BEGIN  
        RAISERROR('MDSERR500028|The model permission cannot be saved. The object GUID is not valid.', 16, 1);  
        RETURN;    
    END  
      
    --Check the Role Access MUID to determine if it is an udpate, clone or a create operation.  
    IF(@RoleAccess_MUID IS NOT NULL AND CAST(@RoleAccess_MUID  AS BINARY) <> 0x0)  
    BEGIN  
        IF( EXISTS(SELECT ID FROM mdm.tblSecurityRoleAccess WHERE MUID=@RoleAccess_MUID))  
        BEGIN  
            --Update operation.  
            SELECT @RoleAccess_ID = (SELECT ID FROM mdm.tblSecurityRoleAccess WHERE MUID=@RoleAccess_MUID)  
            IF (@Status_ID = @Status_Clone)  
            BEGIN  
                SET @Status_ID = @Status_Active   
            END  
        END  
        ELSE IF (@Status_ID = @Status_Clone)  
        BEGIN   --Its a clone operation.                       
            EXEC  @Return_Value = [mdm].[udpSecurityPrivilegesSave]    
                @SystemUser_ID,    
                @Principal_ID,    
                @PrincipalType_ID,    
                @Principal_Name,    
                @PrincipalType_Name,    
                @RoleAccess_ID,    
                @Object_ID,    
                @Privilege_ID,    
                @Model_ID,    
                @Securable_ID,    
                @Securable_Name,                                        
                @RoleAccess_MUID,  
                @Return_ID OUTPUT,    
                @Return_MUID OUTPUT    
  
            RETURN(1)   
        END -- Clone   
  
    END -- MUID Check   
        --Create the new security role.  
    ELSE  
    BEGIN  
        IF (@Status_ID = @Status_Active)  
        BEGIN  
            RAISERROR('MDSERR500033|The model permission cannot be saved. The ID is not valid.', 16, 1);  
            RETURN;    
        END  
        ELSE IF (@Status_ID = @Status_Clone)  
        BEGIN  
            RAISERROR('MDSERR500034|The model permission cannot be copied. The ID is not valid.', 16, 1);  
            RETURN;    
        END  
    END  
  
    IF (@Status_ID = @Status_Create AND @RoleAccess_ID IS NOT NULL AND @RoleAccess_ID > 0 )  
    BEGIN  
        RAISERROR('MDSERR500035|The model permission cannot be created. A model permission already exists.', 16, 1);  
        RETURN;    
    END  
    ELSE IF(@Status_ID = @Status_Active AND @RoleAccess_ID IS NULL OR @RoleAccess_ID = 0 )  
    BEGIN  
        RAISERROR('MDSERR500033|The model permission cannot be saved. The ID is not valid.', 16, 1);  
        RETURN;    
    END   
    ELSE IF(@Status_ID = @Status_Create)  
    BEGIN  
      
        -- IF we can locate a record for the same user, create should result in an error as no new record   
        -- can be added.   
        If(EXISTS (SELECT ID FROM mdm.tblSecurityRoleAccess WHERE Model_ID = @Model_ID AND Role_ID = @Role_ID AND   
            Securable_ID = @Securable_ID AND Object_ID =  @Object_ID ))  
        BEGIN  
            RAISERROR('MDSERR500035|The model permission cannot be created. A model permission already exists.', 16, 1);  
            RETURN;  
        END  
        SET @RoleAccess_ID = 0   
    END   
      
    EXEC    @Return_Value = [mdm].[udpSecurityPrivilegesSave]  
            @SystemUser_ID,  
            @Principal_ID,  
            @PrincipalType_ID,  
            @Principal_Name,  
            @PrincipalType_Name,  
            @RoleAccess_ID,  
            @Object_ID,  
            @Privilege_ID,  
            @Model_ID,  
            @Securable_ID,  
            @Securable_Name,  
            NULL,  
            @Return_ID OUTPUT,  
            @Return_MUID OUTPUT  
  
    SET NOCOUNT OFF  
END --proc
GO
