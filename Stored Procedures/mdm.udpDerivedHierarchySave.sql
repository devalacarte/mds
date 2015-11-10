SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
exec mdm.udpDerivedHierarchySave 1,14,1,'DHTest'  
select * from mdm.tblDerivedHierarchy  
*/  
CREATE PROCEDURE [mdm].[udpDerivedHierarchySave]  
(  
   @User_ID		            INT,  
   @ID                      INT,  
   @Model_ID                INT,  
   @Name		            NVARCHAR(50),  
   @AnchorNullRecursions    BIT = 1,  
   @Return_ID	            INT = NULL OUTPUT,  
   @Return_MUID             UniqueIdentifier = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @TempVersion_ID AS INT  
    DECLARE @IsSystemModel AS BIT  
      
    SET @IsSystemModel = 0  
      
    --Test for invalid parameters  
    IF (@Name IS NULL)  
        OR (@ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblDerivedHierarchy WHERE ID = @ID)) --Invalid ID  
        OR (NOT EXISTS(SELECT ID FROM mdm.tblModel WHERE ID = @Model_ID)) --Invalid Model_ID  
        OR (NOT EXISTS(SELECT ID FROM mdm.tblUser WHERE ID = @User_ID)) --Invalid @User_ID  
    BEGIN  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
  
    DECLARE @NameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @Name, @NameHasReservedCharacters OUTPUT;  
    IF @NameHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100051|The derived hierarchy cannot be created because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    BEGIN TRY  
  
        --Get the Latest Version  
        SELECT @TempVersion_ID = (SELECT MAX(ID) FROM mdm.tblModelVersion WHERE Model_ID = @Model_ID)  
  
        IF @ID IS NOT NULL  
           BEGIN  
  
              --Delete views  
              EXEC mdm.udpDeleteViews @Model_ID  
  
              UPDATE mdm.tblDerivedHierarchy   
             
              SET  
                 Name = ISNULL(@Name,Name),  
                 AnchorNullRecursions = @AnchorNullRecursions,  
                 LastChgDTM = GETUTCDATE(),  
                 LastChgUserID = @User_ID,  
                 LastChgVersionID = @TempVersion_ID  
              WHERE  
                 ID = @ID  
  
              SELECT @Return_ID = @ID  
  
              --Populate output parameters  
              SELECT @Return_MUID = MUID FROM mdm.tblDerivedHierarchy WHERE ID = @ID;  
  
              --Re Gen All Views  
              EXEC mdm.udpCreateAllViews  
  
           END  
        ELSE  
           BEGIN  
  
              --Accept an explicit MUID (for clone operations) or generate a new one  
              SET @Return_MUID = ISNULL(@Return_MUID, NEWID());  
  
              INSERT INTO mdm.tblDerivedHierarchy   
                   ([Model_ID]  
                   ,[Name]  
                   ,[AnchorNullRecursions]			         
                   ,[MUID]  
                   ,[EnterDTM]  
                   ,[EnterUserID]  
                   ,[EnterVersionID]  
                   ,[LastChgDTM]  
                   ,[LastChgUserID]  
                   ,[LastChgVersionID])  
                
              SELECT   
                    @Model_ID,  
                    ISNULL(@Name,N''),  
                    @AnchorNullRecursions,  
                    @Return_MUID,  
                    GETUTCDATE(),  
                    @User_ID,  
                    @TempVersion_ID,  
                    GETUTCDATE(),  
                    @User_ID,  
                    @TempVersion_ID     
  
              SELECT @Return_ID = SCOPE_IDENTITY()  
  
              -- Set IsSystemModel that indicates if the Model is a Metadata Model.  
              SELECT @IsSystemModel = IsSystem FROM mdm.tblModel WHERE ID=@Model_ID;  
  
              --Create related metadata member  
              DECLARE @HierarchyMetadataCode NVARCHAR(200) -- We will build out hierarchy metadata codes as modelid_D_hierarchyId to ensure uniqueness  
              SET @HierarchyMetadataCode = CONVERT(NVARCHAR(20), @Model_ID) + N'_D_' + CONVERT(NVARCHAR(20), @Return_ID)  
                
              IF (@IsSystemModel = 0) EXEC mdm.udpUserDefinedMetadataSave N'Hierarchy', @Return_MUID, @Name, @HierarchyMetadataCode, @User_ID  
  
           END  
  
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
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
  
        --On error, return NULL results  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
  
    SET NOCOUNT OFF  
END --proc
GO
