SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Creates a new user-defined metadata member that is linked to a master  
data object by its MUID  
  
EXEC mdm.udpUserDefinedMetadataSave @ObjectType='Model',   
                                    @Object_ID='420d36b0-4efc-4870-9433-76a9dec73aaf',   
                                    @MemberName='Product Model Metadata',  
                                    @MemberCode='Product Model Metadata',  
                                    User_ID = 10  
  
*/  
CREATE PROCEDURE [mdm].[udpUserDefinedMetadataSave]  
(  
    @ObjectType     NVARCHAR(50),		-- the MDM object type (model, entity, attribute, etc)  
    @Object_ID      UNIQUEIDENTIFIER,	-- the MUID for the object that is associated with the metadata  
    @MemberName     NVARCHAR(250),		-- member name  
    @MemberCode     NVARCHAR(250),		-- member code  
    @User_ID        INT,				-- user  
    @ReturnID       INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
  
    SET NOCOUNT ON;  
      
    --Declare local variables  
    DECLARE @MetadataObjectId   INT,  
            @MemberId			INT,  
            @return_value		INT;  
  
    --Initialize output parameters and local variables  
    SELECT @MetadataObjectId = 0,  
           @MemberId = 0,  
           @return_value = 0  
      
    --Test for invalid parameters  
    --Ensure that object type, source MUID, and member code and name are supplied  
    IF (@ObjectType IS NULL) OR (@Object_ID IS NULL) OR (@MemberCode IS NULL) OR (@MemberName IS NULL)  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if */  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION MetadataMemberSave;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        -- Get the metadata object id from tblList  
        SELECT @MetadataObjectId = OptionID FROM mdm.tblList WHERE ListCode= CAST(N'lstMetadataDefinitions' AS NVARCHAR(50)) AND ListOption= CAST(@ObjectType AS NVARCHAR(250))  
  
        -- Raise error if we didn't get back a nonzero object key  
        IF (@MetadataObjectId = 0)  
            BEGIN   
                RAISERROR('MDSERR500063|Unable to save the user defined metadata. The metadata object ID is not valid.', 16, 1);  
                RETURN(1);  
            END; --if  
  
        -- create the metadata member  
        DECLARE @MemberCodes mdm.MemberCodes;  
        INSERT INTO @MemberCodes (MemberCode, MemberName)  
        SELECT @MemberCode, @MemberName;  
        EXEC mdm.udpEntityMembersCreate  
            @User_ID               = @User_ID,  
            @Version_ID            = 1,  
            @Entity_ID             = @MetadataObjectId,  
            @MemberType_ID         = 1, /*Leaf*/  
            @MemberCodes           = @MemberCodes,  
            @ReturnErrors          = 0, -- raise, rather than return, any error.  
            @ErrorIfNoPermission   = 0; -- Allow the metadata member creation, even when the user lacks explicit permission on the Metadata model's entity.  
  
        --update the member's ObjectId column with the appropriate value  
        EXEC @return_value = [mdm].[udpMemberAttributeSave]  
             @User_ID = @User_ID,  
             @Version_ID = 1,  
             @Entity_ID = @MetadataObjectId,  
             @MemberCode = @MemberCode,  
             @MemberType_ID = 1,  
             @AttributeName = N'ObjectId',  
             @AttributeValue = @Object_ID,  
             @LogFlag = 1,  
             @DoInheritanceRuleCheck = 0  
  
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
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION MetadataMemberSave;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
  
        --On error, return NULL results  
        SELECT @ReturnID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
  
END; --proc
GO
