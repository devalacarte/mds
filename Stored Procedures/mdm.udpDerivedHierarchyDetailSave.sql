SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpDerivedHierarchyDetailSave 1,.....  
*/  
CREATE PROCEDURE [mdm].[udpDerivedHierarchyDetailSave]  
(  
    @User_ID				INT,  
    @ID						INT,  
    @DerivedHierarchy_ID	INT,  
    @Foreign_ID				INT,  
    @ForeignType_ID			INT,  
    @Name                   NVARCHAR(50),  
    @DisplayName            NVARCHAR(100),  
    @IsVisible				BIT,  
    @Return_ID	            INT = NULL OUTPUT,  
    @Return_MUID            UniqueIdentifier = NULL OUTPUT  
  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
      
    DECLARE @NextLevelNumber INT,  
            @ForeignParent_ID INT,  
            @TempVersion_ID INT,  
            @Model_ID		INT,  
            @IsValidParam  BIT;  
              
    SET @IsValidParam = 1;  
    --Validate derived hierarchy ID  
    EXECUTE @IsValidParam = mdm.udpIDParameterCheck @DerivedHierarchy_ID, 2, NULL, NULL, 1;  
    IF (@IsValidParam = 0)  
    BEGIN  
        RAISERROR('MDSERR100006|The DerivedHierarchy ID is not valid.', 16, 1);  
        RETURN;    
    END;  
      
    --Validate ForeignType ID  
    IF (@ForeignType_ID IS NULL)  
    BEGIN  
        RAISERROR('MDSERR100008|The ForeignType_ID is required.', 16, 1);  
        RETURN;    
    END;  
      
    --Validate Name  
    IF (LEN(@Name) = 0 OR @Name IS NULL )  
    BEGIN  
        RAISERROR('MDSERR100003|The Name is not valid.', 16, 1);  
        RETURN;    
    END;  
      
     --Validate Display Name  
    IF (LEN(@DisplayName) = 0 OR @DisplayName IS NULL )  
    BEGIN  
        RAISERROR('MDSERR100007|The DisplayName is not valid.', 16, 1);  
        RETURN;    
    END;  
  
    --Reserved characters check  
    DECLARE @NameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @Name, @NameHasReservedCharacters OUTPUT;  
  
    DECLARE @DisplayNameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @DisplayName, @DisplayNameHasReservedCharacters OUTPUT;  
  
    IF @NameHasReservedCharacters = 1 OR @DisplayNameHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100052|The derived hierarchy level cannot be created because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    --Get the Latest Version  
    SELECT @TempVersion_ID = MAX(mv.ID)  
    FROM mdm.tblModelVersion mv   
    INNER JOIN mdm.tblDerivedHierarchy dh  
    ON mv.Model_ID = dh.Model_ID   
        AND dh.ID = @DerivedHierarchy_ID  
      
    --Get the ModelID  
    SELECT @Model_ID=Model_ID FROM mdm.tblModelVersion WHERE ID=@TempVersion_ID;    
  
    DECLARE @IsMemberSecurityApplied BIT = 0   
      
    If (EXISTS (SELECT ID  from mdm.tblSecurityRoleAccessMember where DerivedHierarchy_ID = @DerivedHierarchy_ID))  
    BEGIN    
        SET  @IsMemberSecurityApplied = 1  
    END   
      
        
    BEGIN TRY    
        IF EXISTS(SELECT ID FROM mdm.tblDerivedHierarchyDetail WHERE ID = @ID)    
            BEGIN    
              
                If (@IsMemberSecurityApplied = 1  AND @IsVisible = 0 )    
                BEGIN  
                     RAISERROR('MDSERR200075|The derived hierarchy level cannot be hidden. The derived hierarchy has secured members.', 16, 1);  
                     RETURN  
                END  
                ELSE  
                    BEGIN  
                    UPDATE mdm.tblDerivedHierarchyDetail     
                    SET    
                         Name = ISNULL(@Name, [Name])    
                        ,DisplayName = ISNULL(@DisplayName, [DisplayName])    
                        ,IsVisible = ISNULL(@IsVisible,[IsVisible])    
                        ,LastChgDTM = GETUTCDATE()    
                        ,LastChgUserID = @User_ID    
                        ,LastChgVersionID = @TempVersion_ID    
                    WHERE    
                        ID = @ID    
        
                  SELECT @Return_ID = @ID    
        
                  --Populate output parameters    
                  SELECT @Return_MUID = MUID FROM mdm.tblDerivedHierarchyDetail WHERE ID = @ID;    
                END  
            END    
        ELSE    
            BEGIN    
                --Level Add Check.  We need to make sure the save request is compatible with the current top level of the hierarchy.    
                --The new level can only be added to the top.    
                EXEC mdm.udpDerivedHierarchyLevelAddCheck @DerivedHierarchy_ID, @Foreign_ID, @ForeignType_ID, @NextLevelNumber OUT, @ForeignParent_ID OUT    
                    
                IF @NextLevelNumber = 0    
                BEGIN    
                    RAISERROR('MDSERR200056|The derived hierarchy level cannot be saved. The level being saved is not compatible with the current top level.', 16, 1);  
                END;    
                  
                -- If adding an explicit hierarchy and member security has been applied return error.  
                IF (@IsMemberSecurityApplied = 1 AND @ForeignType_ID = 2)  
                BEGIN  
                    RAISERROR('MDSERR200076|A derived hierarchy level with explicit cap cannot be added. The derived hierarchy has secured members.', 16, 1);  
                    RETURN  
                END  
                  
                -- If adding a recursive level and member security has been applied return error.  
                If(@IsMemberSecurityApplied = 1 AND @ForeignType_ID = 1 AND (Select CASE WHEN Entity_ID=IsNull(DomainEntity_ID,0)   
                 THEN 1 ELSE 0 END from mdm.tblAttribute where ID = @Foreign_ID) = 1)  
                BEGIN  
                    RAISERROR('MDSERR200077|A recursive derived hierarchy level cannot be added. The derived hierarchy has secured members.', 16, 1);  
                    RETURN  
                END  
                  
                --Accept an explicit MUID (for clone operations) or generate a new one    
                SET @Return_MUID = ISNULL(@Return_MUID, NEWID());    
    
                INSERT INTO mdm.tblDerivedHierarchyDetail    
                    ([DerivedHierarchy_ID]    
                    ,[ForeignParent_ID]    
                    ,[Foreign_ID]    
                    ,[ForeignType_ID]    
                    ,[Level_ID]    
                    ,[Name]    
                    ,[MUID]    
                    ,[DisplayName]    
                    ,[IsVisible]    
                    ,[SortOrder]    
                    ,[EnterDTM]    
                    ,[EnterUserID]    
                    ,[EnterVersionID]    
                    ,[LastChgDTM]    
                    ,[LastChgUserID]    
                    ,[LastChgVersionID])    
                    
                SELECT     
                     @DerivedHierarchy_ID    
                    ,@ForeignParent_ID    
                    ,@Foreign_ID    
                    ,@ForeignType_ID    
                    ,@NextLevelNumber    
                    ,@Name    
                    ,@Return_MUID    
                    ,@DisplayName    
                    ,@IsVisible    
                    ,0    
                    ,GETUTCDATE()    
                    ,@User_ID    
                    ,@TempVersion_ID    
                    ,GETUTCDATE()    
                    ,@User_ID    
                    ,@TempVersion_ID	    
    
                SELECT @Return_ID = SCOPE_IDENTITY()    
            END    
                
            --Put a msg onto the SB queue to process member security     
            --for all entities in All versions in the model to be safe - revisit    
            EXEC mdm.udpSecurityMemberProcessRebuildModel @Model_ID = @Model_ID, @ProcessNow=0;	    
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
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
        RETURN;      
    END CATCH;    
    
    SET NOCOUNT OFF    
END --proc
GO
