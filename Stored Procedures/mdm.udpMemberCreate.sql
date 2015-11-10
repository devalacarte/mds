SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpMemberCreate @User_ID=1, @Version_ID = 1, @Hierarchy_ID = 0, @Entity_ID = 7, @MemberType_ID = 1, @MemberName = ' ', @MemberCode = 'NewLeaf2', @LogFlag = 1  
    EXEC mdm.udpMemberCreate @User_ID=1, @Version_ID = 1, @Hierarchy_ID = 1, @Entity_ID = 7, @MemberType_ID = 2, @MemberName = ' ', @MemberCode = 'NewCon2', @LogFlag = 1  
    EXEC mdm.udpMemberCreate @User_ID=1, @Version_ID = 1, @Hierarchy_ID = 0, @Entity_ID = 7, @MemberType_ID = 3, @MemberName = ' ', @MemberCode = 'NewCol2', @LogFlag = 1  
      
*/  
CREATE PROCEDURE [mdm].[udpMemberCreate]  
(  
    @User_ID        INT,  
    @Version_ID     INT,  
    @Hierarchy_ID   INT = NULL,  
    @Entity_ID      INT,  
    @MemberType_ID  TINYINT,  
    @MemberName     NVARCHAR(250) = NULL,  
    @MemberCode     NVARCHAR(250) = NULL,  
    @LogFlag        BIT = NULL, --1 indicates log the transaction  
    @ReturnID		INT = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
          
    DECLARE   
        @SQL				NVARCHAR(MAX),  
        @TableName			sysname,  
        @SecurityTableName	sysname,  
        @Member_ID			INT,  
        @UseMemberSecurity	INT,  
        @SecurityRoleID		INT,  
        @IsValidParam		BIT,  
        @CodeGenEnabled     BIT = 0;  
              
    SET @IsValidParam = 1;  
  
    --Validate @User_ID  
    EXECUTE @IsValidParam = mdm.udpIDParameterCheck @User_ID, 11, NULL, NULL, 1;  
    IF (@IsValidParam = 0)  
    BEGIN  
        RAISERROR('MDSERR100009|The User ID is not valid.', 16, 1);  
        RETURN;  
    END;  
      
    --Validate @Version_ID  
    EXECUTE @IsValidParam = mdm.udpIDParameterCheck @Version_ID, 4, NULL, NULL, 1;  
    IF (@IsValidParam = 0)  
    BEGIN  
        RAISERROR('MDSERR100005|The Version ID is not valid.', 16, 1);  
        RETURN;  
    END;  
      
    --Validate @Entity_ID  
    EXECUTE @IsValidParam = mdm.udpIDParameterCheck @Entity_ID, 5, NULL, NULL, 1;  
    IF (@IsValidParam = 0)  
    BEGIN  
        RAISERROR('MDSERR100004|The Entity ID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    IF ((@MemberType_ID <> 1) AND (@MemberType_ID <> 2) AND (@MemberType_ID <> 3))  
        OR ((@MemberType_ID = 2) AND (@Hierarchy_ID IS NULL))  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN;  
    END;  
  
    --Figure out whether code gen is enabled  
    EXEC @CodeGenEnabled = mdm.udpIsCodeGenEnabled @Entity_ID;  
  
    SELECT   
        --Clean member code value  
        @MemberCode = NULLIF(LTRIM(RTRIM(@MemberCode)), N''),  
        --Clean member name value  
        @MemberName = NULLIF(LTRIM(RTRIM(@MemberName)), N''); --Ditto, except allow NULLs  
  
    IF @MemberCode IS NULL AND (@CodeGenEnabled = 0 OR @MemberType_ID <> 1)  
        BEGIN  
            RAISERROR('MDSERR310022|The code can not be empty', 16, 1);  
            RETURN;  
        END  
      
    IF mdm.udfItemReservedWordCheck(12, @MemberCode) = 1 BEGIN --Currently, reserved words are the same for leaf, consolidation, and collection members  
        RAISERROR('MDSERR100027|The code is a reserved word. Specify a different value.', 16, 1);  
        RETURN;  
    END; --if  
  
    SELECT @TableName = mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID);  
    IF @TableName IS NULL  
    BEGIN  
        RAISERROR('MDSERR100100|The target table for the requested entity and MemberType ID does not exist.', 16, 1);  
        RETURN;    
    END; --if  
  
    SET @SecurityTableName = mdm.udfTableNameGetByID(@Entity_ID, 6);  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
        --If code gen is enabled on this entity  
        IF @CodeGenEnabled = 1  
            BEGIN  
                --Check if the passed in member code is null  
                IF @MemberCode IS NULL  
                    BEGIN   
                        --If the member type is leaf  
                        IF @MemberType_ID = 1  
                            BEGIN  
                                --Generate a new code and assign it  
                                EXEC @MemberCode = mdm.udpGenerateNextCode @Entity_ID = @Entity_ID;  
                            END  
                    END  
                --If the provided code is non-null we still must process it to update the largest code value  
                ELSE  
                    BEGIN  
                        --Gather up the valid user provided codes  
                        DECLARE @CodesToProcess mdm.MemberCodes;  
  
                        INSERT @CodesToProcess (MemberCode)   
                        VALUES (@MemberCode);  
  
                        --Process the user-provided codes to update the code gen info table with the largest one  
                        EXEC mdm.udpProcessCodes @Entity_ID, @CodesToProcess;  
                    END  
            END  
  
        --Insert into the appropriate entity table  
        SET @SQL = N'  
            INSERT INTO mdm.' + quotename(@TableName) + N'  
            (  
                Version_ID,   
                Status_ID,  
                Name,   
                Code,' + CASE @MemberType_ID WHEN 2 THEN N'  
                Hierarchy_ID,' WHEN 3 THEN N'  
                [Owner_ID],' ELSE N'' END + N'  
                EnterDTM,                            
                EnterUserID,                         
                EnterVersionID,   
                LastChgDTM,   
                LastChgUserID,   
                LastChgVersionID  
            )   
            VALUES   
            (  
                @Version_ID  
                ,1   
                ,@Name  
                ,@Code' + CASE @MemberType_ID WHEN 2 THEN N'  
                ,@Hierarchy_ID' WHEN 3 THEN N'  
                ,@User_ID' ELSE N'' END + N'  
                ,GETUTCDATE()  
                ,@User_ID  
                ,@Version_ID  
                ,GETUTCDATE()  
                ,@User_ID  
                ,@Version_ID  
            );  
              
            SET @Member_ID = SCOPE_IDENTITY();';  
              
        --PRINT(@SQL);  
        EXEC sp_executesql @SQL,   
            N'@User_ID INT, @Version_ID INT, @Hierarchy_ID INT, @Name NVARCHAR(250), @Code NVARCHAR(250), @Member_ID INT OUTPUT',   
            @User_ID, @Version_ID, @Hierarchy_ID, @MemberName, @MemberCode, @Member_ID OUTPUT;  
  
        --Create the hierarchy relationship(s) and set the parent to 0 (Root). Children are assigned to all hierarchies.  
        IF @MemberType_ID = 1 BEGIN     
  
            DECLARE @TempTable TABLE(ID INT NOT NULL);  
            DECLARE @TempHierachy_ID AS INT;  
  
            INSERT INTO @TempTable(ID)  
            SELECT ID FROM mdm.tblHierarchy   
            WHERE Entity_ID = @Entity_ID AND IsMandatory = 1;  
  
            WHILE EXISTS(SELECT 1 FROM @TempTable) BEGIN  
                SELECT TOP 1 @TempHierachy_ID = ID FROM @TempTable;  
  
                EXEC mdm.udpHierarchyCreate @User_ID, @Version_ID, @Entity_ID, @TempHierachy_ID, 0, @Member_ID, 1;  
  
                DELETE FROM @TempTable WHERE ID = @TempHierachy_ID;  
            END; --while  
  
        END	ELSE IF @MemberType_ID = 2 BEGIN --Parent  
  
            EXEC mdm.udpHierarchyCreate @User_ID, @Version_ID, @Entity_ID, @Hierarchy_ID, 0, @Member_ID, 2;  
  
        END; --if  
  
        --Log the transaction  
        IF @LogFlag = 1 BEGIN  
            EXEC mdm.udpTransactionSave @User_ID, @Version_ID, 1, NULL, @Hierarchy_ID, @Entity_ID, @Member_ID, @MemberType_ID, NULL, NULL, NULL;  
        END; --if  
  
        --Add a message to the Securi  
        SELECT @ReturnID = @Member_ID;  
  
        --Check to see if member security is in play  
        SET @UseMemberSecurity=mdm.udfUseMemberSecurity(@User_ID,@Version_ID,1,NULL,0,@Entity_ID,@MemberType_ID,NULL)  
          
        --Add a record to the MS table for the user which created the member so it will be visible to the creator  
        IF @MemberType_ID IN (1,2) AND @UseMemberSecurity <> 0  
        BEGIN  
            --Get the role for the user			  
            SELECT @SecurityRoleID=Role_ID FROM mdm.tblSecurityAccessControl where Principal_ID=@User_ID AND PrincipalType_ID=1;  
              
            -- Role ID can be null for a user when user permissions are inherited only from a group. The permission for the member added   
            -- should be set to update for the user. This requires that the sercurity role be added for the user.   
            -- Correct security permissions are applied when the member security update batch process is run by the sql broker.  
            If(	@SecurityRoleID IS NULL)  
            BEGIN  
              
                DECLARE @Principal_Name Nvarchar (100)   
                SELECT @Principal_Name = UserName From mdm.tblUser where ID = @User_ID;  
                  
                INSERT INTO mdm.tblSecurityRole ([Name], EnterUserID, LastChgUserID) VALUES   
                        (N'Role for ' +  + N'UserAccount' + @Principal_Name, 1, 1);  
                SET @SecurityRoleID = SCOPE_IDENTITY() ;  
            
                INSERT INTO mdm.tblSecurityAccessControl (PrincipalType_ID, Principal_ID, Role_ID, Description, EnterUserID, LastChgUserID)     
                VALUES (1, @User_ID, @SecurityRoleID, @Principal_Name + N'UserAccount ', 1, 1);   
              
            END  
              
            SET @SQL = N'  
                INSERT INTO mdm.' + quotename(@SecurityTableName) + N'  
                (  
                    Version_ID,   
                    SecurityRole_ID,  
                    MemberType_ID,  
                    EN_ID,  
                    HP_ID,  
                    Privilege_ID  
                )   
                VALUES   
                (  
                     @Version_ID  
                    ,@SecurityRoleID   
                    ,@MemberType_ID   
                    ,CASE @MemberType_ID WHEN 1 THEN @ReturnID ELSE NULL END  
                    ,CASE @MemberType_ID WHEN 2 THEN @ReturnID ELSE NULL END  
                    ,2 --Update				  
                );';  
            EXEC sp_executesql @SQL, N'@Version_ID INT, @SecurityRoleID INT, @MemberType_ID TINYINT, @ReturnID INT', @Version_ID, @SecurityRoleID, @MemberType_ID, @ReturnID;  
        END  
          
        --Put a msg onto the SB queue to process member security  
        EXEC mdm.udpSecurityMemberQueueSave   
            @Role_ID    = NULL,-- update member count cache for all users  
            @Version_ID = @Version_ID,  
            @Entity_ID  = @Entity_ID;  
      
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
  
        --On error, return NULL results  
        SELECT @ReturnID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
