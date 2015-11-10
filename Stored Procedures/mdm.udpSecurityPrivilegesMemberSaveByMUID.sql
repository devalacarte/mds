SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityPrivilegesMemberSaveByMUID]  
(  
    @SystemUser_ID			INT,  
    @Principal_MUID			UNIQUEIDENTIFIER=NULL,  
    @PrincipalType_ID		INT,  
    @Principal_Name			NVARCHAR(100) = NULL,  
    @PrincipalType_Name		NVARCHAR(20) = NULL,  
    @RoleAccess_MUID		UNIQUEIDENTIFIER = NULL,  
    @Object_ID				INT,  
    @Privilege_ID			INT,  
    @Version_MUID			UNIQUEIDENTIFIER=NULL,  
    @Version_Name			NVARCHAR(50) = NULL,  
    @Entity_MUID			UNIQUEIDENTIFIER=NULL,  
    @Entity_Name			NVARCHAR(50) = NULL,  
    @Hierarchy_MUID			UNIQUEIDENTIFIER = NULL,  
    @Hierarchy_Name			NVARCHAR(50) = NULL,  
    @HierarchyType_ID		SMALLINT,  
    @Item_ID				INT,  
    @ItemType_ID			TINYINT,  
    @Member_ID				INT,  
    @MemberType_ID			TINYINT,  
    @Member_Code NVARCHAR(250) = NULL,  
    @Status_ID				INT = 0,  
    @Securable_Name			NVARCHAR(100) = NULL,  
    @Return_ID				INT = NULL OUTPUT,  
    @Return_MUID			UNIQUEIDENTIFIER = NULL OUTPUT   
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @Role_ID			INT  
    DECLARE @Description		NVARCHAR(500),  
    @Principal_ID				INT ,  
    @Version_ID					INT,  
    @Entity_ID					INT,  
    @Hierarchy_ID				INT,  
    @Securable_ID				INT,   
    @RoleAccess_ID				INT,  
    @TempRoleAccess_ID				INT,  
    @NewUser_ID	INT  
  
    SET  @Principal_ID = 0   
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
                IF( @Principal_MUID IS NOT NULL AND CAST(@Principal_MUID  AS BINARY) <> 0x0  
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
  
        If @Principal_ID IS NULL OR @Principal_ID = 0   
        BEGIN  
            RAISERROR('MDSERR500025|The principal ID for the user or group is not valid.', 16, 1);  
            RETURN     
        END  
      
        IF (@RoleAccess_MUID IS NOT NULL AND CAST(@RoleAccess_MUID  AS BINARY) <> 0x0)    
        BEGIN    
                IF((EXISTS (SELECT ID FROM mdm.tblSecurityRoleAccessMember WHERE MUID=@RoleAccess_MUID)))    
                BEGIN    
                        SELECT @RoleAccess_ID = RoleAccess_ID,      
                                @Version_MUID = Version_MUID,      
                                @Entity_MUID =  Entity_MUID,      
                                @Hierarchy_MUID = Hierarchy_MUID,  
                                @Member_ID = Member_ID,  
                                @HierarchyType_ID = HierarchyType_ID  
                            FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER WHERE RoleAccess_MUID=@RoleAccess_MUID      
                END     
        END     
          
            --Validate other supplied parameters     
    If( @Version_MUID IS NOT NULL AND CAST(@Version_MUID  AS BINARY) <> 0x0    
            AND EXISTS(SELECT ID from mdm.tblModelVersion WHERE MUID=@Version_MUID))    
        BEGIN    
            SELECT @Version_ID = (SELECT ID FROM mdm.tblModelVersion WHERE MUID=@Version_MUID)    
        END    
    ELSE    
        BEGIN    
            RAISERROR('MDSERR500029|The hierarchy permission cannot be saved. The version GUID is not valid.', 16, 1);  
            RETURN       
        END    
        
    
    If( @Entity_MUID IS NOT NULL AND CAST(@Entity_MUID  AS BINARY) <> 0x0    
            AND EXISTS(SELECT ID from mdm.tblEntity WHERE MUID=@Entity_MUID))    
        BEGIN    
            SELECT @Entity_ID = (SELECT ID FROM mdm.tblEntity WHERE MUID=@Entity_MUID)    
        END    
    ELSE    
        BEGIN    
            RAISERROR('MDSERR500030|The hierarchy permission cannot be saved. The entity GUID is not valid.', 16, 1);  
            RETURN       
        END    
          
    -- Check for member Id.   
    IF(@Member_ID = 0 AND @Member_Code IS NOT NULL AND @Member_Code <> '' AND @Member_Code <> 'ROOT')  
    BEGIN  
        EXEC mdm.udpMemberIDGetByCode @Version_ID,@Entity_ID, @Member_Code,@MemberType_ID,@Member_ID OUTPUT  
  
        -- Verify that the member code exists.  
        IF (@Member_ID = 0)   
        BEGIN   
            RAISERROR('MDSERR300002|Error - The member code is not valid.', 16, 1);  
            RETURN;         
        END  
    END  
          
    SELECT	@TempRoleAccess_ID = RoleAccess_ID  FROM	mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER rac     
                    WHERE	rac.Object_ID        = @Object_ID     
                    AND		rac.Version_MUID     = @Version_MUID    
                    AND		rac.Entity_MUID      = @Entity_MUID    
                    AND		rac.Hierarchy_MUID   = @Hierarchy_MUID    
                    AND		rac.HierarchyType_ID = @HierarchyType_ID    
                    AND		rac.Item_ID          = @Item_ID    
                    AND		rac.ItemType_ID      = @ItemType_ID    
                    AND		rac.Member_ID        = @Member_ID    
                    AND		rac.MemberType_ID    = @MemberType_ID    
                    AND		rac.Principal_MUID      = @Principal_MUID    
                    AND		rac.PrincipalType_ID  = @PrincipalType_ID    
    
    If ( @TempRoleAccess_ID IS NOT NULL AND @TempRoleAccess_ID <>0)    
    BEGIN     
    --Role exists update the role.    
        UPDATE mdm.tblSecurityRoleAccessMember SET Privilege_ID = @Privilege_ID WHERE ID = @TempRoleAccess_ID     
        SELECT @Hierarchy_ID = Hierarchy_ID ,@HierarchyType_ID = HierarchyType_ID from mdm.tblSecurityRoleAccessMember      
        WHERE ID = @TempRoleAccess_ID     
        Return(1)    
    END    
            
    
    IF(@HierarchyType_ID =0)    
    BEGIN    
        IF( @Hierarchy_MUID IS NOT NULL AND CAST(@Hierarchy_MUID  AS BINARY) <> 0x0    
                    AND EXISTS(SELECT ID from mdm.tblHierarchy WHERE MUID=@Hierarchy_MUID))    
        BEGIN    
            SELECT @Hierarchy_ID = (SELECT ID FROM mdm.tblHierarchy WHERE MUID=@Hierarchy_MUID)    
              
            -- Verify that the member is a part of the hierarchy.  
            IF (COALESCE(@Hierarchy_ID, 0) > 0 AND COALESCE(@Member_ID, 0) > 0)  
            BEGIN  
                DECLARE @IsMemberInHierarchy BIT = 0;  
                DECLARE @SQL NVARCHAR(MAX) =  
                N'SET @IsMemberInHierarchy =   
                    CASE WHEN EXISTS(  
                                SELECT *  
                                FROM mdm.' + QUOTENAME(mdm.udfTableNameGetByID(@Entity_ID, 4 /*HierarchyTable*/)) + N'  
                                WHERE   
                                Version_ID =    @Version_ID AND  
                                Hierarchy_ID =  @Hierarchy_ID AND  
                                ChildType_ID =  @MemberType_ID AND   
                                @Member_ID =    CASE ChildType_ID   
                                                    WHEN 1 /*Leaf*/         THEN Child_EN_ID   
                                                    WHEN 2 /*Consolidated*/ THEN Child_HP_ID  
                                                    END)  
                        THEN 1 ELSE 0 END;                                          
                ';  
                EXEC sp_executesql @SQL, N'@Version_ID INT, @Hierarchy_ID INT, @MemberType_ID TINYINT, @Member_ID INT, @IsMemberInHierarchy BIT OUTPUT', @Version_ID, @Hierarchy_ID, @MemberType_ID, @Member_ID, @IsMemberInHierarchy OUTPUT;  
                IF (@IsMemberInHierarchy <> 1)  
                BEGIN  
                    RAISERROR('MDSERR300002|Error - The member code is not valid.', 16, 1);  
                    RETURN;         
                END  
            END  
        END    
    END    
    ELSE    
        BEGIN    
            IF(@HierarchyType_ID =1 )    
            BEGIN    
                IF( @Hierarchy_MUID IS NOT NULL AND CAST(@Hierarchy_MUID  AS BINARY) <> 0x0    
                        AND EXISTS(SELECT ID from mdm.tblDerivedHierarchy WHERE MUID=@Hierarchy_MUID))    
                BEGIN    
                    SELECT @Hierarchy_ID = (SELECT ID FROM mdm.tblDerivedHierarchy WHERE MUID=@Hierarchy_MUID)    
                END    
            END    
        END    
            
        If @Hierarchy_ID is NULL OR @Hierarchy_ID = 0     
        BEGIN    
            RAISERROR('MDSERR500031|The hierarchy permission cannot be saved. The hierarchy GUID is not valid.', 16, 1);  
            RETURN       
        END    
          
          
    
  
    
    IF (@RoleAccess_MUID IS NOT NULL AND CAST(@RoleAccess_MUID  AS BINARY) <> 0x0)    
        BEGIN    
            IF((EXISTS (SELECT ID FROM mdm.tblSecurityRoleAccessMember WHERE MUID=@RoleAccess_MUID)))    
                BEGIN    
                    SELECT @RoleAccess_ID = (SELECT ID FROM mdm.tblSecurityRoleAccessMember WHERE MUID=@RoleAccess_MUID)    
                    
                    --Print 'update'     
                    IF (@Status_ID = 3)    
                    BEGIN    
                        SET @Status_ID = 1     
    
                    END    
                    IF(@Status_ID = 0)    
                    BEGIN    
                        SET @RoleAccess_ID = 0  -- ignore the role acces id     
                    END     
                END    
            ELSE     
            BEGIN    
                IF (@Status_ID = 3)    
                BEGIN    
                    --Print 'Clone' --Clone operation.    
                    print @RoleAccess_ID    
                    SELECT	@Role_ID = Role_ID    
                    FROM	mdm.tblSecurityAccessControl    
                    WHERE	Principal_ID = @Principal_ID    
                    AND		PrincipalType_ID = @PrincipalType_ID    
    
    
                    IF @Principal_Name IS NULL     
                    BEGIN    
                        IF @PrincipalType_ID = 1 BEGIN    
                            SELECT @Principal_Name = mdm.udfUserNameGetByUserID(@Principal_ID)    
                        END ELSE BEGIN    
                            SELECT @Principal_Name = Name FROM mdm.tblUserGroup WHERE ID = @Principal_ID    
                        END     
                    END    
    
                    IF @PrincipalType_Name IS NULL BEGIN    
                        IF @PrincipalType_ID = 1 BEGIN    
                            SELECT @PrincipalType_Name = CAST(N'UserAccount' AS NVARCHAR(20))    
                        END ELSE BEGIN    
                            SELECT @PrincipalType_Name = CAST(N'Group' AS NVARCHAR(20))    
                        END     
                    END    
    
                    IF @Role_ID IS NULL BEGIN    
                        --Create a new user account role for this user.    
                        INSERT INTO mdm.tblSecurityRole (Name, EnterUserID, LastChgUserID) VALUES (CAST(N'Role for ' + @PrincipalType_Name + N' ' + @Principal_Name AS NVARCHAR(115)), @SystemUser_ID, @SystemUser_ID)    
                        SET @Role_ID = SCOPE_IDENTITY()    
    
                        INSERT INTO mdm.tblSecurityAccessControl (PrincipalType_ID, Principal_ID, Role_ID, Description, EnterUserID, LastChgUserID)     
                        VALUES (@PrincipalType_ID, @Principal_ID, @Role_ID, CAST(@Principal_Name + N' ' + @PrincipalType_Name AS NVARCHAR(110)), @SystemUser_ID, @SystemUser_ID)    
                    END     
    
                    SELECT	@Description = CAST(@Securable_Name + N' ' + o.Name + N' (' + p.Name + N')' AS NVARCHAR(500))    
                    FROM	mdm.tblSecurityObject o     
                            INNER JOIN mdm.tblSecurityPrivilege p     
                                ON o.ID = @Object_ID AND p.ID = @Privilege_ID    
                    --print 'insert'    
                    INSERT INTO mdm.tblSecurityRoleAccessMember (MUID,Role_ID, Object_ID, Privilege_ID, Version_ID, Entity_ID, ExplicitHierarchy_ID,DerivedHierarchy_ID, HierarchyType_ID, Item_ID, ItemType_ID, Member_ID, MemberType_ID, Description, EnterUserID, LastChgUserID)    
                    VALUES(@RoleAccess_MUID,@Role_ID, @Object_ID, @Privilege_ID, @Version_ID, @Entity_ID, CASE @HierarchyType_ID WHEN 0 THEN @Hierarchy_ID ELSE NULL END,CASE @HierarchyType_ID WHEN 1 THEN @Hierarchy_ID ELSE NULL END, @HierarchyType_ID, @Item_ID, @ItemType_ID, @Member_ID, @MemberType_ID, @Description, @SystemUser_ID, @SystemUser_ID)    
                    SELECT @NewUser_ID=SCOPE_IDENTITY()		    
                      
                    SELECT @Return_ID = @NewUser_ID    
                    SELECT @Return_MUID = (SELECT MUID FROM mdm.tblSecurityRoleAccessMember WHERE ID = @NewUser_ID)    
                    RETURN(1)     
                END -- Clone    
            END -- ELSE    
        END -- muid Check     
    ELSE    
        BEGIN    
            IF (@Status_ID = 1)    
            BEGIN    
                RAISERROR('MDSERR500037|The hierarchy permission cannot be updated. The ID is not valid.', 16, 1);  
                RETURN      
            END    
            ELSE IF (@Status_ID = 3)    
            BEGIN    
                RAISERROR('MDSERR500038|The hierarchy permission cannot be copied. The ID is not valid.', 16, 1);  
                RETURN      
            END    
        END    
    
        IF (@Status_ID = 0 AND (@RoleAccess_ID IS NOT null AND @RoleAccess_ID > 0) )    
        BEGIN    
            RAISERROR('MDSERR500036|The hierarchy permission cannot be created. The ID is not valid.', 16, 1);  
            RETURN      
        END    
        ELSE IF(@Status_ID = 1 AND (@RoleAccess_ID IS  null OR @RoleAccess_ID = 0 ))    
        BEGIN    
                RAISERROR('MDSERR500037|The hierarchy permission cannot be updated. The ID is not valid.', 16, 1);  
                RETURN      
        END     
        ELSE IF(@Status_ID = 0)    
        BEGIN    
            If(EXISTS (SELECT ID FROM mdm.tblSecurityRoleAccessMember where Role_ID = @Role_ID AND     
                 Privilege_ID = @Privilege_ID AND Hierarchy_ID = @Hierarchy_ID AND Entity_ID=@Entity_ID AND     
                Version_ID = @Version_ID AND Object_ID =  @Object_ID  AND Member_ID = @Member_ID AND @Item_ID = Item_ID))    
            BEGIN    
                RAISERROR('MDSERR500026|The hierarchy permission cannot be created. A hierarchy permission already exists.', 16, 1);  
                RETURN      
            END    
            set @RoleAccess_ID = 0     
        END     
    
    --print @RoleAccess_ID    
    --Execute the save stored procedure.    
    DECLARE	@return_value int    
    
    EXEC	@return_value = [mdm].[udpSecurityPrivilegesMemberSave]    
        @SystemUser_ID,    
        @Principal_ID,    
        @PrincipalType_ID,    
        @Principal_Name,    
        @PrincipalType_Name,    
        @RoleAccess_ID,    
        @Object_ID,    
        @Privilege_ID,    
        @Version_ID,    
        @Entity_ID,    
        @Hierarchy_ID,    
        @HierarchyType_ID,    
        @Item_ID,    
        @ItemType_ID,    
        @Member_ID,    
        @MemberType_ID,    
        @Securable_Name,    
        @Return_ID = @Return_ID OUTPUT,    
        @Return_MUID = @Return_MUID OUTPUT    
    
        --RETURN(@return_value)    
    
    SET NOCOUNT OFF    
END --proc
GO
