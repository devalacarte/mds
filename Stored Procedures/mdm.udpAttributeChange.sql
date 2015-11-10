SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Description:  
This SProc takes an existing attribute and changes its name and/or its data type. If a datatype is changed, a new attribute is created and all  
previous attribute values are copied into it  
Example:  
declare @p16 bit  
set @p16=0  
declare @p17 bit  
set @p17=0  
exec mdm.udpAttributeChange  
@Attribute_MUID='D0D9A3BD-239F-4F18-9A71-FD40832459F1',  
@AttributeNewName=N'May15',  
@AttributeType_ID=1,   
@DisplayWidth=100,@DomainEntity_MUID='00000000-0000-0000-0000-000000000000',@DomainEntity_Name=default,  
@DataType_ID=1, --1 text, 2 number, 3 datetime , 6 link  
@DataTypeInformation=5,  
@InputMask_Name=N'None',@ChangeTrackingGroup=0,  
@Return_SubscriptionViewExists=@p17 output, @User_ID=1  
  
This takes the attribute with MUID : D0D9A3BD-239F-4F18-9A71-FD40832459F1  
and changes its type  
*/  
CREATE PROCEDURE [mdm].[udpAttributeChange]  
(  
    @User_ID						INT,  
    @Attribute_MUID					UNIQUEIDENTIFIER,  
    @AttributeNewName				NVARCHAR(50),  
    @AttributeType_ID				INT,  
    @DisplayWidth					INT,   
    @DomainEntity_MUID				UNIQUEIDENTIFIER = NULL,  
    @DomainEntity_Name				NVARCHAR(50) = NULL,  
    @DataType_ID					TINYINT = NULL,  
    @DataTypeInformation			INT = NULL,  
    @InputMask_Name					NVARCHAR(250) = NULL,  
    @ChangeTrackingGroup			INT = 0,  
    @Return_DeprecatedAttributeName NVARCHAR(50) = NULL OUTPUT,  
    @Return_NewAttribute_MUID       UNIQUEIDENTIFIER = NULL OUTPUT,  
    @Return_NewAttribute_ID         INT = NULL OUTPUT,  
    @Return_SubscriptionViewExists  BIT = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    -- Constants  
    -- AttributeDataType constants  
    DECLARE  
        @DataTypeText           TINYINT = 1,  
        @DataTypeNumber         TINYINT = 2,  
        @DataTypeDateTime       TINYINT = 3,  
        @DataTypeLink           TINYINT = 6,  
  
        -- AttributeType constants  
        @AttributeTypeFreeform  TINYINT = 1,  
        @AttributeTypeDomain    TINYINT = 2,  
        @AttributeTypeSystem    TINYINT = 3,  
        @AttributeTypeFile      TINYINT = 4  
  
  
    -- Get current attribute type information  
   DECLARE   
       -- IDs of input parameters (i.e. convert attribute MUID to ID)  
        @Attribute_ID               INT,  
        @Model_ID                   INT,  
        @Model_MUID                 UNIQUEIDENTIFIER,  
        @Entity_ID                  INT,  
        @Entity_MUID                UNIQUEIDENTIFIER,  
        @MemberType_ID              INT,  
        @DomainEntity_ID            INT,  
        @InputMask_ID               INT,  
        -- IDs/Names of the current values stored for the given attribute  
        @InputMask_ID_Current       INT ,	  
        @InputMask_Name_Current     NVARCHAR(250),  
        @DomainEntity_ID_Current    INT,  
        @DomainEntity_MUID_Current  UNIQUEIDENTIFIER ,  
        @AttributeType_ID_Current   TINYINT,  
        @AttributeName_Current   NVARCHAR(50),  
        @DataType_ID_Current        TINYINT,  
        @DataTypeInformation_Current    INT ,  
        @DisplayWidth_Current       INT ,  
        @LastVersion                INT,  
        @IsSystem                   BIT,  
        @MembersWithErrors          XML = NULL, -- If any errors occurred, will hold the codes of the members that failed  
        @OriginalSortOrder          INT,  
        -- Booleans to figure out what kind of change we encountered  
        @HasTypeChange              BIT,  
        @HasNameChange              BIT,  
        @TranCommitted			    INT = 0; -- 0: Not committed, 1: Committed.  
  
  
    -- Get the currently stored values for the original attribute given in the parameter  
    SELECT   
        @Attribute_ID = ID,  
        @AttributeName_Current = Name,  
        @AttributeType_ID_Current = AttributeType_ID,  
        @Entity_ID = Entity_ID,  
        @MemberType_ID = MemberType_ID,  
        @DataType_ID_Current = DataType_ID,  
        @DataTypeInformation_Current = DataTypeInformation,  
        @InputMask_ID_Current = InputMask_ID,  
        @DomainEntity_ID_Current = DomainEntity_ID,  
        @DisplayWidth_Current = DisplayWidth,  
        @OriginalSortOrder = SortOrder,  
        @IsSystem = IsSystem  
    FROM  
        mdm.tblAttribute WHERE MUID = @Attribute_MUID  
  
    -- Get the latest version of the entity, as we want to make sure we are updating the latest version and not any previous one  
    SELECT @DomainEntity_MUID_Current = MUID FROM mdm.tblEntity WHERE ID=@DomainEntity_ID_Current  
  
    -- Using the given Attribute MUID, we can lookup Entity and Model information - this will be used when we call the AttributeSave SProcs  
    -- but are NOT used directly in this code  
    SELECT @Entity_MUID = MUID, @Model_ID = Model_ID FROM mdm.tblEntity WHERE ID=@Entity_ID  
    SELECT @Model_MUID = MUID FROM mdm.tblModel WHERE ID=@Model_ID  
  
    -- Get the name of the current input mask (i.e. mm/dd/yyyy)  
    SELECT @InputMask_Name_Current = ListOption FROM mdm.tblList WHERE ListCode=CAST(N'lstInputMask' AS NVARCHAR(50)) AND OptionID=@InputMask_ID_Current AND Group_ID=@DataType_ID_Current  
  
    -- If supplied, find the Domain Entity *ID* from the given Domain entity MUID OR the Domain entity NAME (we already know the model/entity IDs)  
    SELECT @DomainEntity_ID = ID FROM mdm.tblEntity WHERE (MUID = @DomainEntity_MUID) OR (Model_ID = @Model_ID AND Name = @DomainEntity_Name);  
  
    DECLARE @GetVersionSql NVARCHAR(MAX)  
    SET @GetVersionSql = N'  
                        SELECT @LastVersion = MAX(m.Version_ID)  
                        FROM mdm.viw_SYSTEM_' + CONVERT(NVARCHAR, @Model_ID)  + N'_' + CONVERT(NVARCHAR, @Entity_ID) + N'_CHILDATTRIBUTES AS m'  
    EXEC sp_executesql @GetVersionSql, N'@LastVersion INT OUTPUT ', @LastVersion OUTPUT;    
  
    -- Validate input  
    -- A valid attribute is required  
    IF @Attribute_ID IS NULL   
    BEGIN  
        RAISERROR('MDSERR200016|The attribute cannot be saved. The attribute ID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    -- We don't support System attributes  
    IF @IsSystem = 1  
    BEGIN  
        RAISERROR('MDSERR100041|A system attribute cannot be updated.', 16, 1);  
        RETURN;  
    END;  
           
  
    -- Verify and lookup the InputMask_ID (from the InputMask_Name)  
    IF (@InputMask_Name IS NULL)  
        BEGIN  
            -- If input mask wasn't given, that is OK, continue with the ID as NULL  
            SET @InputMask_ID = NULL  
        END  
    ELSE  
        BEGIN  
            -- If the input mask was given, make sure it exists  
            SET @InputMask_ID = ISNULL((SELECT OptionID FROM mdm.tblList WHERE ListCode = CAST(N'lstInputMask' AS NVARCHAR(50)) AND ListOption = @InputMask_Name), -1);  
  
            IF (@InputMask_ID < 0)  
            BEGIN  
                RAISERROR('MDSERR200085|The attribute cannot be saved. The input mask is not valid.', 16, 1);  
                RETURN;  
            END  
        END  
  
    --  
    -- Now that was have all the information on the current state of the attribute and the intended state,  
    -- check the type and/or the name have changed  
    SELECT @HasTypeChange =  
    CASE  
        WHEN  
        (  
        @AttributeType_ID_Current != @AttributeType_ID OR  
        @DataType_ID_Current != @DataType_ID OR  
        @DataTypeInformation_Current != @DataTypeInformation OR  
        @InputMask_ID_Current != @InputMask_ID OR  
        @DomainEntity_ID_Current != @DomainEntity_ID  
        )  
        THEN 1  
        ELSE 0  
    END  
  
    SELECT @HasNameChange =  
    CASE  
        WHEN (@AttributeName_Current != @AttributeNewName)  
        THEN 1  
        ELSE 0  
    END  
  
    -- Check the new attribute name, to make sure it isn't duplicate  
    IF @HasNameChange = 1  
    BEGIN  
        IF EXISTS (SELECT * FROM mdm.tblAttribute WHERE Name=@AttributeNewName AND Entity_ID=@Entity_ID AND MemberType_ID=@MemberType_ID)   
        BEGIN  
            DECLARE @ErrorMsg NVARCHAR(250)  
            SET @ErrorMsg = CAST(N'MDSERR110003|The name already exists. Type a different name.' AS NVARCHAR(250)) -- 110003  
            RAISERROR(@ErrorMsg, 16, 1);  
            RETURN;  
        END  
    END  
  
    --  
    -- Start the process of attribute updates          
    --  
  
    IF @HasNameChange = 0 AND @HasTypeChange = 0  
    BEGIN  
        -- Nothing has changed, leave  
        RETURN;  
    END;  
  
    DECLARE @TemporaryNewName NVARCHAR(50)  
  
    IF @HasTypeChange = 0  
    BEGIN  
        SET @TemporaryNewName = @AttributeNewName  
        SET @Return_DeprecatedAttributeName = @AttributeName_Current  
    END  
    ELSE -- There is also a change in the type  
    BEGIN  
        DECLARE @RenamingCounter INT = 0  
        SET @TemporaryNewName = @AttributeName_Current + N'_old'  
      
        WHILE (EXISTS(SELECT 1 FROM mdm.tblAttribute WHERE Name=@TemporaryNewName))  
        BEGIN  
            SET @RenamingCounter += 1  
            SET @TemporaryNewName = @AttributeName_Current + N'_old' + CAST(@RenamingCounter AS NVARCHAR(MAX))  
        END  
        SET @Return_DeprecatedAttributeName = @TemporaryNewName  
    END  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
        -- Change the name of the attribute, whether because it only had a name change  
        -- or because it is the first phase of an attribute type change  
  
        DECLARE @OldAttributeID INT  
        EXECUTE  [mdm].[udpAttributeSaveByMUID]   
                        @User_ID = @User_ID  
                        ,@Model_MUID = @Model_MUID  
                        ,@Entity_MUID = @Entity_MUID  
                        ,@Entity_Name = NULL  
                        ,@MemberType_ID = @MemberType_ID  
                        ,@Attribute_MUID = @Attribute_MUID  
                        ,@Name = @TemporaryNewName  
                        ,@AttributeType_ID = @AttributeType_ID_Current  
                        ,@DisplayWidth = @DisplayWidth_Current  
                        ,@DomainEntity_MUID = @DomainEntity_MUID_Current  
                        ,@DataType_ID = @DataType_ID_Current  
                        ,@DataTypeInformation = @DataTypeInformation_Current  
                        ,@InputMask_Name = @InputMask_Name_Current  
                        ,@ChangeTrackingGroup = @ChangeTrackingGroup  
						,@SortOrder = @OriginalSortOrder  
                        ,@Return_SubscriptionViewExists = @Return_SubscriptionViewExists OUTPUT  
                        ,@Return_ID = @OldAttributeID OUTPUT  
  
  
  
        IF @HasTypeChange = 1  
        BEGIN  
            -- Create the new attribute using the original attribute name, but with the new type definition  
            EXECUTE  [mdm].[udpAttributeSaveByMUID]   
                           @User_ID = @User_ID  
                          ,@Model_MUID = @Model_MUID  
                          ,@Entity_MUID = @Entity_MUID  
                          ,@Entity_Name = NULL  
                          ,@MemberType_ID = @MemberType_ID  
                          ,@Attribute_MUID = NULL  
                          ,@Name = @AttributeNewName  
                          ,@AttributeType_ID = @AttributeType_ID  
                          ,@DisplayWidth = @DisplayWidth  
                          ,@DomainEntity_MUID = @DomainEntity_MUID  
                          ,@DomainEntity_Name = @DomainEntity_Name  
                          ,@DataType_ID = @DataType_ID  
                          ,@DataTypeInformation = @DataTypeInformation  
                          ,@InputMask_Name = @InputMask_Name  
                          ,@ChangeTrackingGroup = @ChangeTrackingGroup  
                          ,@SortOrder = @OriginalSortOrder  
                          ,@Return_ID = @Return_NewAttribute_ID OUTPUT  
                          ,@Return_MUID = @Return_NewAttribute_MUID OUTPUT;  
          
            DECLARE @SQL NVARCHAR(MAX)  
            SET @SQL = N'  
                DECLARE @MemberAttributes            mdm.MemberAttributes  
  
                INSERT @MemberAttributes (MemberCode, AttributeName, AttributeValue)  
                SELECT  
                    Code																				AS MemberCode,   
                    '''+@AttributeNewName+N'''															AS AttributeName,'  
              
            -- We treat a previously date time attribute differently - as we don't want to take it as is to the new one,  
            -- we first convert it to string using the input mask  
            IF ((@DataType_ID_Current = @DataTypeDateTime) AND (@AttributeType_ID_Current = @AttributeTypeFreeform))  
            BEGIN  
                -- Convert date to string using the input mask  
                SET @SQL +=   
                    N'mdq.DateToString(' + QUOTENAME(@Return_DeprecatedAttributeName) + N', ''' +  @InputMask_Name_Current + N''')'  
            END  
            ELSE  
            BEGIN  
                -- Just trim whitespace  
                SET @SQL +=  
                    N'LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),' + QUOTENAME(@Return_DeprecatedAttributeName) + N')))'  
            END  
  
            SET @SQL +=  N'	AS AttributeValue  
                FROM mdm.viw_SYSTEM_' + CONVERT(NVARCHAR, @Model_ID)  + N'_' + CONVERT(NVARCHAR, @Entity_ID) + N'_CHILDATTRIBUTES AS m  
                WHERE  
                    m.Version_ID = @LastVersion AND  
                    ' + QUOTENAME(@Return_DeprecatedAttributeName) + N' IS NOT NULL  
  
                EXEC mdm.udpEntityMembersUpdate   
                    @User_ID = @User_ID, @Version_ID = @LastVersion, @Entity_ID = @Entity_ID, @MemberType_ID = @MemberType_ID,   
                    @MemberAttributes = @MemberAttributes, @LogFlag = 1, @DoInheritanceRuleCheck = 0, @IgnorePriorValues = 0,  
                    @ShouldReturnMembersWithErrorsAsXml = 1,  
                    @Return_MembersWithErrors=@MembersWithErrors OUTPUT;      
            '  
            -- Copy the old attribute values to the new attribute. This is a best effort insertion. NULLs will be placed where it fails.  
            DECLARE @MemberAttributes            mdm.MemberAttributes  
            EXEC sp_executesql @SQL, N'@User_ID INT, @LastVersion INT, @Entity_ID INT, @MemberType_ID INT, @MembersWithErrors XML OUTPUT ', @User_ID, @LastVersion, @Entity_ID, @MemberType_ID, @MembersWithErrors OUTPUT;  
  
            -- Get all the IDs of the attribute groups the old attribute belonged to  
            DECLARE @AttributeGroups AS TABLE (  
                     RowNumber INT IDENTITY(1,1) NOT NULL,  
                     AttributeGroup_ID INT NOT NULL  
                     );  
  
            INSERT INTO @AttributeGroups(AttributeGroup_ID) SELECT AttributeGroup_ID FROM mdm.tblAttributeGroupDetail WHERE Attribute_ID=@OldAttributeID  
  
            IF EXISTS(SELECT 1 FROM @AttributeGroups)  
            BEGIN  
                DECLARE   
                    @Counter INT,  
                    @MaxCounter INT,  
                    @AttributeGroup_ID INT  
          
                SELECT   
                    @Counter=1,  
                    @MaxCounter = MAX(RowNumber)  
                FROM @AttributeGroups  
                
                --Loop through each attribute group this attribute belongs to, and associate the new attribute to it.  
                WHILE @Counter <= @MaxCounter  
                BEGIN  
                    SELECT   
                        @AttributeGroup_ID = AttributeGroup_ID  
                    FROM @AttributeGroups WHERE [RowNumber] = @Counter ;  
  
                    exec mdm.udpAttributeGroupDetailSave @User_ID=@User_ID,  @AttributeGroup_ID=@AttributeGroup_ID, @ID=@Return_NewAttribute_ID, @Type_ID=1 -- Type_ID=1 is attribute change  
  
                    SET @Counter += 1  
                END  
  
            END  
  
            -- Decide if we should delete or not the old attribute  
            DECLARE @OldAttributeHasDependency AS INT;  
            -- 7 is "attribute"  
            EXEC mdm.udpObjectDeleteCheckByMUID @Attribute_MUID,7,@OldAttributeHasDependency OUTPUT;  
            -- If there are no errors and no dependencies on this old attribute, delete is  
            IF ((@OldAttributeHasDependency = 0) AND (@MembersWithErrors IS NULL))  
            BEGIN  
                EXEC mdm.udpAttributeDeleteByMUID @Attribute_MUID  
            END  
  
  
            IF @MembersWithErrors IS NOT NULL  
            BEGIN  
                -- Return to user all the member codes that had an error converting.  
                SELECT  
                    node.value('.', 'NVARCHAR(MAX)') AS MembersWithError  
                FROM   
                    @MembersWithErrors.nodes('//MemberCodes/MemberCode') T(node)  
            END  
  
        END;  
  
        --Commit only if we are not nested  
        IF @TranCounter = 0   
        BEGIN  
            COMMIT TRANSACTION;  
            SET @TranCommitted = 1;  
        END; -- IF  
  
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
  
        IF @TranCommitted = 0 -- Don't rollback when the transaction has been committed.  
        BEGIN  
            IF @TranCounter = 0 ROLLBACK TRANSACTION;    
            ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;    
        END; -- IF  
  
        --Throw the error again so the calling procedure can use it  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
          
        RETURN;  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
