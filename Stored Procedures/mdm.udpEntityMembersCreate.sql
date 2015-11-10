SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*    
==============================================================================    
 Copyright (c) Microsoft Corporation. All Rights Reserved.    
==============================================================================    
    
Description: Bulk creates entity members.    
    
The following are assumed validated prior to calling and are not validated here:    
    * User    
    * Version    
    * Entity    
    * Member Type    
    * Hierarchy    
    
declare     
    @MemberCodes AS mdm.MemberCodes    
    
insert into @MemberCodes(MemberCode, MemberName) values (N'HL-U509-BL', N'HL-U509-BL'); -- Invalid.  Existing leaf code    
insert into @MemberCodes(MemberCode, MemberName) values (N'BK-M38S-46', N'BK-M38S-46'); -- Invalid.  Existing leaf code    
insert into @MemberCodes(MemberCode, MemberName) values (N'BK-M38Z-50', N'BK-M38S-56'); -- New code    
insert into @MemberCodes(MemberCode, MemberName) values (N'BK-M38Z-51', N'BK-M38S-57'); -- New code    
insert into @MemberCodes(MemberCode, MemberName) values (N'BK-M38Z-55', N'BK-M38S-58'); -- New code    
insert into @MemberCodes(MemberCode, MemberName) values (N'BK-M38Z-55', N'BK-M38S-58'); -- Invalid.  Duplicate code    
insert into @MemberCodes(MemberCode, MemberName) values (N'ROOT', N'ROOT');   -- Invalid.  Reserved word    
    
insert into @MemberCodes(MemberCode, MemberName, HierarchyName) values (N'ZZ3C', N'ZZ 3C', N'Index'); -- New    
insert into @MemberCodes(MemberCode, MemberName, HierarchyName) values (N'ZZ4C', N'ZZ 4C', N'Bundle'); -- New    
EXEC mdm.udpEntityMembersCreate @User_ID=1, @Version_ID = 20, @Entity_ID = 31, @MemberType_ID = 2, @MemberCodes = @MemberCodes, @LogFlag = 1, @ErrorIfExists = 1    
        
*/    
CREATE PROCEDURE [mdm].[udpEntityMembersCreate]    
(    
    @User_ID                INT,    
    @Version_ID             INT,    
    @Entity_ID              INT,    
    @MemberType_ID          TINYINT,    
    @MemberCodes            mdm.MemberCodes READONLY,    
    @LogFlag                BIT = NULL, --1 indicates log the transaction    
    @ErrorIfExists          BIT = 1, --1 indicates return error if member code already exists        
    @ReturnCreatedMembers   BIT = 0,    
    @ReturnErrors           BIT = 1,-- 1 indicates that a row will be returned for each error. 0 indicates that if an error is found it will be raised.    
    @ErrorIfNoPermission    BIT = 1 -- 1 indicates return an error if the user does not have update permission on the member's entity. It is useful to disable this for internal     
                                    -- sproc calls that create members of the Metadata model. For example, when a user with Sys Admin functional permission creates a model, a     
                                    -- new member row will be added to tbl_1_1_EN (the "Models" entity of the "Metadata" model), but the user shouldn't be required to have     
                                    -- explicit update permission on the "Models" metadata entity.    
)    
WITH EXECUTE AS 'mds_schema_user'    
AS BEGIN    
    SET NOCOUNT ON;    
            
    DECLARE     
         @SQL                   NVARCHAR(MAX)    
        ,@TableName             sysname    
        ,@EntityTable           sysname    
        ,@HierarchyParentTable  sysname    
        ,@CollectionTable       sysname    
        ,@SecurityTable         sysname    
        ,@IsFlat                BIT    
        ,@Member_ID             INT    
        ,@SecurityRoleID        INT    
        ,@ErrorCode             INT    
        ,@ErrorObjectType       INT    
    
        --Code and Name attribute metadata    
        ,@CodeAttributeName     NVARCHAR(MAX)    
        ,@CodeAttributeMUID     UNIQUEIDENTIFIER    
        ,@CodeAttributeLength   INT    
        ,@NameAttributeName     NVARCHAR(MAX)    
        ,@NameAttributeMUID     UNIQUEIDENTIFIER    
        ,@NameAttributeLength   INT    
    
        --Security Levels    
        ,@SecurityLevel                     TINYINT    
        ,@SecLvl_NoAccess                   TINYINT = 0    
        ,@SecLvl_ObjectSecurity             TINYINT = 1    
        ,@SecLvl_MemberSecurity             TINYINT = 2    
        ,@SecLvl_ObjectAndMemberSecurity    TINYINT = 3    
    
        --Error ObjectTypes    
        ,@ObjectType_Hierarchy          INT = 6    
        ,@ObjectType_MemberCode         INT = 12    
        ,@ObjectType_MemberId           INT = 19    
        ,@ObjectType_MemberAttribute    INT = 22    
    
        --Error Codes    
        ,@ErrorCode_ReservedWord                                INT = 110006    
        ,@ErrorCode_IdAlreadyExists                             INT = 110008    
        ,@ErrorCode_AttributeValueLengthGreaterThanMaximum      INT = 110017    
        ,@ErrorCode_NoPermissionForThisOperation                INT = 120002    
        ,@ErrorCode_NoPermissionForThisOperationOnThisObject    INT = 120003    
        ,@ErrorCode_DuplicateInputMemberCodes                   INT = 210001    
        ,@ErrorCode_MemberCodeExists                            INT = 300003    
        ,@ErrorCode_InvalidExplicitHierarchy                    INT = 300009    
        ,@ErrorCode_ConsolidatedMemberCreateHierarchyRequired   INT = 300017    
        ,@ErrorCode_DeactivatedMemberCodeExists                 INT = 300034      
        ,@ErrorCode_InvalidFlatEntityForMemberCreate            INT = 310021    
        ,@ErrorCode_InvalidBlankMemberCode                      INT = 310022    
    
        --Member Types    
        ,@MemberType_Leaf           INT = 1    
        ,@MemberType_Consolidated   INT = 2    
        ,@MemberType_Collection     INT = 3    
    
        --Permission    
        ,@MbrTypePermission         INT    
        ,@Permission_None           INT = 0    
        ,@Permission_Deny           INT = 1    
        ,@Permission_Update         INT = 2    
        ,@Permission_ReadOnly       INT = 3    
        ,@Permission_Inferred       INT = 99    
    
        --Store the current time for use in this SPROC    
        ,@CurrentTime               DATETIME2(3) = GETUTCDATE()    
    
        --Transaction type for entity member update    
        ,@TransactionType_Create    INT = 1    
        ,@TransactionType_ParentSet INT = 4    
    
        --A flag indicating whether or not to generate code for this entity    
        ,@CodeGenEnabled            BIT = 0    
      
        --Character constants  
        ,@Tab                    NCHAR(1) = CHAR(9)  
        ,@NewLine                NCHAR(1) = CHAR(10)  
        ,@CarriageReturn         NCHAR(1) = CHAR(13)  
    ;    
  
    --Final results to be returned.    
    CREATE TABLE #MemberCodeWorkingSet    
        (    
          Row_ID                INT IDENTITY(1,1) NOT NULL    
         ,MemberCode            NVARCHAR(MAX) COLLATE DATABASE_DEFAULT    
         ,MemberName            NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL    
         ,Hierarchy_ID          INT NULL    
         ,HierarchyName         NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL    
         ,NewMemberID           INT    
         ,Attribute_MUID        UniqueIdentifier    
         ,AttributeName         NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL    
         ,ErrorCode             INT NULL    
         ,ErrorObjectType       INT NULL    
         ,TransactionAnnotation NVARCHAR(MAX) NULL    
         ,MUID                  UNIQUEIDENTIFIER NULL    
        );    
    
    --IDs of new members created.    
    CREATE TABLE #NewMembers     
        (    
            ID    INT,    
            MemberCode          NVARCHAR(250) COLLATE DATABASE_DEFAULT    
        );    
    
    --Get Entity information.    
    SELECT    
        @EntityTable = Quotename(EntityTable),    
        @HierarchyParentTable = Quotename(HierarchyParentTable),    
        @CollectionTable = Quotename(CollectionTable),    
        @SecurityTable = Quotename(SecurityTable),    
        @IsFlat = IsFlat    
    FROM         
        mdm.tblEntity WHERE ID = @Entity_ID;    
    
    --Figure out whether code generation is enabled    
    EXEC @CodeGenEnabled = mdm.udpIsCodeGenEnabled @Entity_ID;    
    
    IF @MemberType_ID =  @MemberType_Leaf BEGIN    
        SELECT @TableName = @EntityTable;            
    END    
    ELSE IF @MemberType_ID =  @MemberType_Consolidated BEGIN    
        SELECT @TableName = @HierarchyParentTable;    
    END    
    ELSE IF @MemberType_ID =  @MemberType_Collection BEGIN    
        SELECT @TableName = @CollectionTable;    
    END    
  
    ----------------------------------------------------------------------------------------    
    --Seed results with input values.    
    --Clean values    
    ----------------------------------------------------------------------------------------    
    INSERT INTO #MemberCodeWorkingSet (MemberCode, MemberName, HierarchyName, TransactionAnnotation, MUID)    
    SELECT     
         NULLIF(LTRIM(RTRIM(MemberCode)), N'')    
        ,MemberName    
        ,HierarchyName    
        ,NULLIF(LTRIM(RTRIM(TransactionAnnotation)), N'')    
        ,MUID    
    FROM @MemberCodes;    
    
    ----------------------------------------------------------------------------------------    
    --Check to see if the entity has a hierarchy    
    ----------------------------------------------------------------------------------------    
    IF @IsFlat = 1 BEGIN    
        --Entity has no hierarchies    
        IF @MemberType_ID <> @MemberType_Leaf BEGIN    
            UPDATE #MemberCodeWorkingSet      
                SET ErrorCode = @ErrorCode_InvalidFlatEntityForMemberCreate,    
                    ErrorObjectType = @ObjectType_MemberCode    
            WHERE ErrorCode IS NULL;    
        END    
    END     
  
    ----------------------------------------------------------------------------------------    
    --Get Code and Name attribute metadata.        
    ----------------------------------------------------------------------------------------    
    SELECT    
         @CodeAttributeName = Name    
        ,@CodeAttributeMUID = MUID    
        ,@CodeAttributeLength = DataTypeInformation    
    FROM mdm.tblAttribute AS att     
    WHERE Entity_ID = @Entity_ID     
    AND MemberType_ID = @MemberType_ID     
    AND IsCode = 1;    
        
    SELECT     
         @NameAttributeName = Name    
        ,@NameAttributeMUID = MUID    
        ,@NameAttributeLength = DataTypeInformation    
    FROM mdm.tblAttribute AS att     
    WHERE Entity_ID = @Entity_ID     
    AND MemberType_ID = @MemberType_ID     
    AND IsName = 1;    
        
    ----------------------------------------------------------------------------------------    
    --Check for missing member codes    
    --Only do this check for entities where code gen is not enabled or the member type is not leaf    
    ----------------------------------------------------------------------------------------    
    IF @MemberType_ID <> @MemberType_Leaf OR @CodeGenEnabled = 0    
        BEGIN    
            UPDATE #MemberCodeWorkingSet      
                SET ErrorCode = @ErrorCode_InvalidBlankMemberCode,    
                    ErrorObjectType = @ObjectType_MemberAttribute,    
                    AttributeName = @CodeAttributeName,    
                    Attribute_MUID = @CodeAttributeMUID    
            WHERE MemberCode IS NULL;    
        END    
    
    ----------------------------------------------------------------------------------------    
    --Check member type security    
    ----------------------------------------------------------------------------------------    
    --Check security level before going any further.    
    EXEC mdm.udpSecurityLevelGet @User_ID, @Entity_ID, @SecurityLevel OUTPUT;    
    
    IF @ErrorIfNoPermission = 1 AND @SecurityLevel = @SecLvl_NoAccess BEGIN    
        UPDATE #MemberCodeWorkingSet    
        SET ErrorCode = @ErrorCode_NoPermissionForThisOperationOnThisObject,    
            ErrorObjectType = @ObjectType_MemberCode;    
    END;    
    ELSE BEGIN    
        IF @ErrorIfNoPermission = 1 AND @SecurityLevel IN (@SecLvl_ObjectSecurity, @SecLvl_ObjectAndMemberSecurity) BEGIN    
            SELECT @MbrTypePermission = Privilege_ID  FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE     
            WHERE [User_ID] = @User_ID    
            AND Entity_ID = @Entity_ID    
            AND ID = @MemberType_ID;    
            
            --Get hierarchies based on user's permissions    
            UPDATE ws    
                SET ws.Hierarchy_ID = h.ID    
            FROM #MemberCodeWorkingSet ws    
            INNER JOIN mdm.tblHierarchy h    
                ON h.Name = ws.HierarchyName    
            INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY sec    
                ON h.ID = sec.ID    
                AND sec.User_ID = @User_ID    
            WHERE h.Entity_ID = @Entity_ID;    
    
            IF @MbrTypePermission <> @Permission_Update BEGIN    
                UPDATE #MemberCodeWorkingSet    
                SET ErrorCode = @ErrorCode_NoPermissionForThisOperation,    
                    ErrorObjectType = @ObjectType_MemberCode    
                WHERE ErrorCode IS NULL;    
            END;    
    
        END ELSE BEGIN            
            --No object security so get hierarchy IDs straight from table.            
            UPDATE ws    
                SET ws.Hierarchy_ID = h.ID    
            FROM #MemberCodeWorkingSet ws    
            INNER JOIN mdm.tblHierarchy h    
                ON h.Name = ws.HierarchyName    
            WHERE h.Entity_ID = @Entity_ID;    
        END    
    END    
  
    ----------------------------------------------------------------------------------------    
    --Check for reserved words in the MemberCode.        
    ----------------------------------------------------------------------------------------   
    DECLARE @ReservedWords TABLE   
    (  
        Code NVARCHAR(250) PRIMARY KEY  
    );  
    INSERT INTO @ReservedWords (Code)  
    VALUES (N'ROOT'),     
           (N'MDMUNUSED'),     
           (N'MDMMemberStatus');  
   
    UPDATE ws   
    SET ErrorCode = @ErrorCode_ReservedWord,    
        ErrorObjectType = @ObjectType_MemberAttribute,    
        AttributeName = @CodeAttributeName,    
        Attribute_MUID = @CodeAttributeMUID   
    FROM #MemberCodeWorkingSet ws   
    INNER JOIN @ReservedWords rw  
        ON LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(ws.MemberCode, @Tab,N''), @CarriageReturn, N'') , @NewLine, N''))) = rw.Code;  
        
    --Flag code and name attributes where the value length exceeds the maximum length allowed.    
    UPDATE ws SET         
           ErrorCode = @ErrorCode_AttributeValueLengthGreaterThanMaximum,    
           ErrorObjectType = @ObjectType_MemberAttribute,    
           AttributeName = @CodeAttributeName,    
           Attribute_MUID = @CodeAttributeMUID    
    FROM #MemberCodeWorkingSet AS ws      
    WHERE ErrorCode IS NULL    
    AND (LEN(ws.MemberCode) > @CodeAttributeLength);    
        
    UPDATE ws SET         
           ErrorCode = @ErrorCode_AttributeValueLengthGreaterThanMaximum,    
           ErrorObjectType = @ObjectType_MemberAttribute,    
           AttributeName = @NameAttributeName,    
           Attribute_MUID = @NameAttributeMUID    
    FROM #MemberCodeWorkingSet AS ws      
    WHERE ErrorCode IS NULL    
    AND (LEN(ws.MemberName) > @NameAttributeLength);    
    
    --Exclude duplicate member codes across the working set table.  These will not be treated as     
    --errors that get returned but simply marked as errors so they will not be processed below.    
    WITH rawWithCount AS    
    (    
        SELECT    
            ROW_NUMBER() OVER (PARTITION BY MemberCode ORDER BY Row_ID) AS RN,    
            Row_ID    
        FROM #MemberCodeWorkingSet    
        --If code gen is enabled and the member type is Leaf then this test only applies to members that have non-null codes    
        WHERE @CodeGenEnabled = 0 OR @MemberType_ID <> @MemberType_Leaf OR MemberCode IS NOT NULL    
    ),    
    duplicateCodeValues AS    
    (    
        SELECT Row_ID FROM rawWithCount WHERE RN > 1    
    )    
    UPDATE ws SET    
        ErrorCode = @ErrorCode_DuplicateInputMemberCodes,    
        ErrorObjectType = @ObjectType_MemberAttribute,    
        AttributeName = @CodeAttributeName,    
        Attribute_MUID = @CodeAttributeMUID    
    FROM #MemberCodeWorkingSet AS ws    
    INNER JOIN duplicateCodeValues AS dup    
        ON ws.Row_ID = dup.Row_ID    
        AND ErrorCode IS NULL;    
    
    --Duplicate MemberCode, HierarchyName combo is an error.    
    WITH rawWithCount AS    
    (    
        SELECT    
            ROW_NUMBER() OVER (PARTITION BY MemberCode, HierarchyName ORDER BY Row_ID) AS RN,    
            Row_ID    
        FROM #MemberCodeWorkingSet    
        --If code gen is enabled and the member type is Leaf then this test only applies to members that have non-null codes    
        WHERE @CodeGenEnabled = 0 OR @MemberType_ID <> @MemberType_Leaf OR MemberCode IS NOT NULL    
    ),    
    duplicateCodeValues AS    
    (    
        SELECT Row_ID FROM rawWithCount WHERE RN > 1    
    )    
    UPDATE ws    
        SET ErrorCode = @ErrorCode_MemberCodeExists,    
            ErrorObjectType = @ObjectType_MemberAttribute,    
            AttributeName = @CodeAttributeName,    
            Attribute_MUID = @CodeAttributeMUID    
    FROM #MemberCodeWorkingSet AS ws    
    INNER JOIN duplicateCodeValues AS dup    
        ON ws.Row_ID = dup.Row_ID    
        AND ErrorCode = @ErrorCode_DuplicateInputMemberCodes;    
    
    ----------------------------------------------------------------------------------------    
    --Check for existing MUIDs.    
    ----------------------------------------------------------------------------------------    
    SET @SQL = N'    
        UPDATE ws    
        SET     
             ErrorCode = @ErrorCode_IdAlreadyExists    
            ,ErrorObjectType = @ObjectType_MemberId    
        FROM #MemberCodeWorkingSet AS ws    
        INNER JOIN  mdm.' + @TableName + N' AS m    
        ON      ws.MUID IS NOT NULL     
            AND ws.MUID = m.MUID    
            AND ws.ErrorCode IS NULL;    
    ';    
    EXEC sp_executesql @SQL, N'@ErrorCode_IdAlreadyExists INT, @ObjectType_MemberId INT', @ErrorCode_IdAlreadyExists, @ObjectType_MemberId;    
  
    ----------------------------------------------------------------------------------------    
    --Check for existing MemberCodes.    
    ----------------------------------------------------------------------------------------    
    SELECT     
         @ErrorCode = @ErrorCode_MemberCodeExists    
        ,@ErrorObjectType = @ObjectType_MemberAttribute;    
    
    IF @IsFlat = 1 BEGIN    
        SET @SQL = N'    
            UPDATE ws    
            SET    ErrorCode = CASE m.Status_ID WHEN 1 /*Active*/ THEN @ErrorCode_MemberCodeExists ELSE @ErrorCode_DeactivatedMemberCodeExists END,    
                ErrorObjectType = @ErrorObjectType,    
                AttributeName = @CodeAttributeName,    
                Attribute_MUID = @CodeAttributeMUID    
            FROM #MemberCodeWorkingSet AS ws    
            INNER JOIN  mdm.' + @EntityTable + N' AS m    
            ON ws.MemberCode = m.Code    
            AND m.Version_ID = @Version_ID    
            AND ws.ErrorCode IS NULL;    
        ';    
        EXEC sp_executesql @SQL, N'@Version_ID INT, @ErrorCode_MemberCodeExists INT, @ErrorCode_DeactivatedMemberCodeExists INT, @ErrorObjectType INT, @CodeAttributeName NVARCHAR(MAX), @CodeAttributeMUID UniqueIdentifier',     
            @Version_ID, @ErrorCode_MemberCodeExists, @ErrorCode_DeactivatedMemberCodeExists, @ErrorObjectType, @CodeAttributeName, @CodeAttributeMUID;    
    END    
    ELSE BEGIN    
        SET @SQL = N'    
            UPDATE ws    
            SET    ErrorCode = CASE existingCodes.Status_ID WHEN 1 /*Active*/ THEN @ErrorCode_MemberCodeExists ELSE @ErrorCode_DeactivatedMemberCodeExists END,      
                ErrorObjectType = @ErrorObjectType,    
                AttributeName = @CodeAttributeName,    
                Attribute_MUID = @CodeAttributeMUID    
            FROM #MemberCodeWorkingSet AS ws    
            INNER JOIN (    
                SELECT Code, Status_ID FROM mdm.' + @EntityTable + N' WHERE Version_ID = @Version_ID     
                UNION    
                SELECT Code, Status_ID FROM mdm.' + @HierarchyParentTable + N' WHERE Version_ID = @Version_ID     
                UNION    
                SELECT Code, Status_ID FROM mdm.' + @CollectionTable + N'  WHERE Version_ID = @Version_ID     
            ) AS existingCodes    
            ON ws.MemberCode = existingCodes.Code    
            AND ws.ErrorCode IS NULL;    
        ';    
        EXEC sp_executesql @SQL, N'@Version_ID INT, @ErrorCode_MemberCodeExists INT, @ErrorCode_DeactivatedMemberCodeExists INT, @ErrorObjectType INT, @CodeAttributeName NVARCHAR(MAX), @CodeAttributeMUID UniqueIdentifier',     
            @Version_ID, @ErrorCode_MemberCodeExists, @ErrorCode_DeactivatedMemberCodeExists, @ErrorObjectType, @CodeAttributeName, @CodeAttributeMUID;    
    END    
  
    ----------------------------------------------------------------------------------------    
    --Update and validate the hierarchy Ids    
    ----------------------------------------------------------------------------------------    
    -- Flag any invalid hierarchy names for any that were specified.    
    UPDATE #MemberCodeWorkingSet      
        SET ErrorCode = @ErrorCode_InvalidExplicitHierarchy,    
            ErrorObjectType = @ObjectType_Hierarchy    
    WHERE HierarchyName IS NOT NULL     
    AND Hierarchy_ID IS NULL    
    AND ErrorCode IS NULL;    
    
    ----------------------------------------------------------------------------------------    
    --Consolidated members should be set to a hierarchy names.    
    ----------------------------------------------------------------------------------------    
    IF @MemberType_ID = @MemberType_Consolidated BEGIN    
        UPDATE #MemberCodeWorkingSet      
            SET ErrorCode = @ErrorCode_ConsolidatedMemberCreateHierarchyRequired,    
                ErrorObjectType = @ObjectType_MemberCode    
        WHERE HierarchyName IS NULL    
        AND ErrorCode IS NULL;    
    END;    
        
    
    ----------------------------------------------------------------------------------------    
    --Start transaction, being careful to check if we are nested    
    ----------------------------------------------------------------------------------------    
    DECLARE @TranCounter INT;     
    SET @TranCounter = @@TRANCOUNT;    
    IF @TranCounter > 0 SAVE TRANSACTION TX;    
    ELSE BEGIN TRANSACTION;    
    
    BEGIN TRY    
            
        --If the entity is code gen enabled    
        IF @CodeGenEnabled = 1    
            BEGIN    
                --Gather up the valid user provided codes    
                DECLARE @CodesToProcess mdm.MemberCodes;    
    
                INSERT @CodesToProcess (MemberCode)     
                SELECT MemberCode    
                FROM #MemberCodeWorkingSet    
                WHERE MemberCode IS NOT NULL AND ErrorCode IS NULL;    
    
                --Process the user-provided codes to update the code gen info table with the largest one    
                EXEC mdm.udpProcessCodes @Entity_ID, @CodesToProcess;    
    
                IF @MemberType_ID = @MemberType_Leaf    
                    BEGIN    
                        DECLARE @NumberOfCodeToGenerate INT = (SELECT COUNT(*) FROM #MemberCodeWorkingSet WHERE MemberCode IS NULL AND ErrorCode IS NULL);    
    
                        IF @NumberOfCodeToGenerate > 0    
                            BEGIN    
                                DECLARE @AllocatedRangeStart BIGINT, @AllocatedRangeEnd BIGINT;    
                                EXEC mdm.udpGenerateCodeRange   @Entity_ID = @Entity_ID,     
                                                                @NumberOfCodesToGenerate = @NumberOfCodeToGenerate,     
                                                                @CodeRangeStart = @AllocatedRangeStart OUTPUT,    
                                                                @CodeRangeEnd = @AllocatedRangeEnd OUTPUT;    
    
                                DECLARE @AllocatedCodeCounter BIGINT = @AllocatedRangeStart - 1;    
    
                                --Generate any codes the user did not provide    
                                UPDATE #MemberCodeWorkingSet    
                                SET @AllocatedCodeCounter = @AllocatedCodeCounter + 1,    
                                    MemberCode = CONVERT(NVARCHAR(MAX), @AllocatedCodeCounter)    
                                WHERE MemberCode IS NULL;    
                            END    
                    END    
            END    
    
        ----------------------------------------------------------------------------------------    
        --Insert into the appropriate entity table    
        ----------------------------------------------------------------------------------------    
        SET @SQL = N'    
            INSERT INTO mdm.' + @TableName + N'    
            (    
                Version_ID,     
                Status_ID,    
                Name,     
                Code,' +     
                CASE @MemberType_ID WHEN @MemberType_Consolidated THEN N'Hierarchy_ID,' WHEN @MemberType_Collection THEN N'[Owner_ID],' ELSE N'' END + N'    
                EnterDTM,                              
                EnterUserID,                           
                EnterVersionID,     
                LastChgDTM,     
                LastChgUserID,     
                LastChgVersionID,    
                MUID    
            )    
            OUTPUT inserted.ID, inserted.Code INTO #NewMembers    
            SELECT     
                 @Version_ID    
                ,1     
                ,ws.MemberName    
                ,ws.MemberCode' +     
                CASE @MemberType_ID WHEN @MemberType_Consolidated THEN N',ws.Hierarchy_ID' WHEN @MemberType_Collection THEN N',@User_ID' ELSE N'' END + N'    
                ,GETUTCDATE()    
                ,@User_ID    
                ,@Version_ID    
                ,GETUTCDATE()    
                ,@User_ID    
                ,@Version_ID    
                ,COALESCE(MUID, NEWID())    
            FROM #MemberCodeWorkingSet ws    
            WHERE ws.ErrorCode IS NULL    
            ;';    
                
        --PRINT(@SQL);    
        EXEC sp_executesql @SQL,     
            N'@User_ID INT, @Version_ID INT', @User_ID, @Version_ID;    
    
        ----------------------------------------------------------------------------------------    
        --Update working set with new member Ids    
        ----------------------------------------------------------------------------------------    
        UPDATE ws     
            SET NewMemberID = n.ID    
        FROM #MemberCodeWorkingSet ws INNER JOIN    
             #NewMembers n     
             ON  ws.MemberCode = n.MemberCode    
             AND ws.ErrorCode IS NULL;    
  
        ----------------------------------------------------------------------------------------    
        --Add new members to hierarchies    
        ----------------------------------------------------------------------------------------    
        DECLARE @HierarchyMembers mdm.HierarchyMembers;    
        IF @IsFlat = 0 BEGIN    
            --Create the hierarchy relationship(s) and set the parent to 0 (Root).     
            IF @MemberType_ID = @MemberType_Leaf BEGIN       
                --Children are assigned to all hierarchies.    
                INSERT INTO @HierarchyMembers (Hierarchy_ID, Child_ID, ChildMemberType_ID, Parent_ID)    
                SELECT    
                     h.ID    
                    ,ws.NewMemberID    
                    ,@MemberType_ID    
                    ,0    
                FROM #MemberCodeWorkingSet ws CROSS JOIN mdm.tblHierarchy h    
                WHERE h.Entity_ID = @Entity_ID AND h.IsMandatory = 1 AND ws.NewMemberID IS NOT NULL;    
    
            END    ELSE IF @MemberType_ID = @MemberType_Consolidated BEGIN --Parent    
                INSERT INTO @HierarchyMembers (Hierarchy_ID, Child_ID, ChildMemberType_ID, Parent_ID)    
                SELECT DISTINCT    
                     ws.Hierarchy_ID    
                    ,ws.NewMemberID    
                    ,@MemberType_ID    
                    ,0    
                FROM #MemberCodeWorkingSet ws WHERE ws.NewMemberID IS NOT NULL;    
    
            END; --if    
    
            EXEC mdm.udpHierarchyMembersCreate @User_ID, @Version_ID, @Entity_ID, @HierarchyMembers;    
        END    
    
  
        ----------------------------------------------------------------------------------------    
        --Log the transaction    
        ----------------------------------------------------------------------------------------    
        IF @LogFlag = 1     
          BEGIN    
                --Log member add transactions    
                INSERT INTO mdm.tblTransaction     
                (    
                    Version_ID,    
                    TransactionType_ID,    
                    OriginalTransaction_ID,    
                    Hierarchy_ID,    
                    Entity_ID,    
                    Member_ID,    
                    MemberType_ID,    
                    MemberCode,    
                    OldValue,    
                    OldCode,    
                    NewValue,    
                    NewCode,    
                    EnterDTM,    
                    EnterUserID,    
                    LastChgDTM,    
                    LastChgUserID    
                )    
                SELECT     
                    @Version_ID,     
                    @TransactionType_Create, --TransactionType_ID    
                    0, --OriginalTransaction_ID    
                    NULLIF(ws.Hierarchy_ID, 0),     
                    @Entity_ID,     
                    ws.NewMemberID,     
                    @MemberType_ID,     
                    ws.MemberCode,    
                    N'', --OldValue    
                    N'', --OldCode    
                    N'', --NewValue    
                    N'', --NewCode    
                    @CurrentTime,     
                    @User_ID,     
                    @CurrentTime,     
                    @User_ID    
                FROM #MemberCodeWorkingSet AS ws    
                WHERE ws.NewMemberID IS NOT NULL;    
    
                --If a leaf (that has a hierarchy) or a consolidation then log the relationship save transaction    
                IF @IsFlat = 0     
                    BEGIN    
                        INSERT INTO mdm.tblTransaction     
                        (    
                            Version_ID,    
                            TransactionType_ID,    
                            OriginalTransaction_ID,    
                            Hierarchy_ID,    
                            Entity_ID,    
                            Member_ID,    
                            MemberType_ID,    
                            MemberCode,    
                            OldValue,    
                            OldCode,    
                            NewValue,    
                            NewCode,    
                            EnterDTM,    
                            EnterUserID,    
                            LastChgDTM,    
                            LastChgUserID    
                        )     
                        SELECT     
                            @Version_ID,     
                            @TransactionType_ParentSet,     
                            0,     
                            hr.Hierarchy_ID,     
                            @Entity_ID,     
                            hr.Child_ID,     
                            @MemberType_ID,    
                            ws.MemberCode,     
                            0,     
                            N'ROOT',     
                            0,     
                            N'ROOT',     
                            @CurrentTime,     
                            @User_ID,     
                            @CurrentTime,     
                            @User_ID    
                        FROM #MemberCodeWorkingSet AS ws    
                        INNER JOIN @HierarchyMembers hr    
                            ON ws.NewMemberID = hr.Child_ID    
                            AND ws.NewMemberID IS NOT NULL;    
                    END --if    
    
                    ----------------------------------------------------------------------------------------    
                    --Add any annotation comments that came in with the create    
                    --Add annotation comments to both the create and set parent transactions    
                    ----------------------------------------------------------------------------------------    
                    INSERT INTO mdm.tblTransactionAnnotation    
                    (    
                        Transaction_ID,    
                        Comment,    
                        EnterUserID,    
                        EnterDTM,    
                        LastChgDTM,    
                        LastChgUserID    
                    )    
                    SELECT    
                        Transactions.ID,    
                        ws.TransactionAnnotation,    
                        Transactions.EnterUserID,    
                        Transactions.EnterDTM,    
                        Transactions.LastChgDTM,    
                        Transactions.LastChgUserID    
                    FROM #MemberCodeWorkingSet AS ws    
                    LEFT JOIN mdm.tblTransaction AS Transactions    
                        ON ws.MemberCode = Transactions.MemberCode    
                        AND ws.NewMemberID = Transactions.Member_ID    
                    WHERE Transactions.Version_ID = @Version_ID    
                        AND Transactions.Entity_ID = @Entity_ID    
                        AND Transactions.MemberType_ID = @MemberType_ID    
                        AND Transactions.EnterUserID = @User_ID    
                        AND Transactions.EnterDTM = @CurrentTime    
                        AND Transactions.TransactionType_ID IN (@TransactionType_Create, @TransactionType_ParentSet)    
                        AND ws.TransactionAnnotation IS NOT NULL    
            END; --if    
  
        ----------------------------------------------------------------------------------------    
        --If member security is in play then add the appropriate member security records.    
        ----------------------------------------------------------------------------------------    
        IF @SecurityLevel IN (@SecLvl_MemberSecurity, @SecLvl_ObjectAndMemberSecurity) BEGIN    
            --Add a record to the MS table for the user which created the member so it will be visible to the creator    
            IF @MemberType_ID IN (@MemberType_Leaf, @MemberType_Consolidated)    
            BEGIN    
                --Get the role for the user                
                SELECT @SecurityRoleID = Role_ID FROM mdm.tblSecurityAccessControl where Principal_ID=@User_ID AND PrincipalType_ID=1;    
                    
                -- Role ID can be null for a user when user permissions are inherited only from a group. The permission for the member added     
                -- should be set to update for the user. This requires that the sercurity role be added for the user.     
                -- Correct security permissions are applied when the member security update batch process is run by the Service Broker.    
                If(    @SecurityRoleID IS NULL)    
                BEGIN    
                    
                    DECLARE @Principal_Name NVARCHAR (100)     
                    SELECT @Principal_Name = UserName FROM mdm.tblUser WHERE ID = @User_ID;    
                        
                    INSERT INTO mdm.tblSecurityRole ([Name], EnterUserID, LastChgUserID) VALUES     
                            (N'Role for ' +  + N'UserAccount' + @Principal_Name, 1, 1);    
                    SET @SecurityRoleID = SCOPE_IDENTITY() ;    
                  
                      INSERT INTO mdm.tblSecurityAccessControl (PrincipalType_ID, Principal_ID, Role_ID, Description, EnterUserID, LastChgUserID)       
                    VALUES (1, @User_ID, @SecurityRoleID, @Principal_Name + N'UserAccount ', 1, 1);     
                    
                END    
                    
                SET @SQL = N'    
                    INSERT INTO mdm.' + @SecurityTable + N'    
                    (    
                        Version_ID,     
                        SecurityRole_ID,    
                        MemberType_ID,    
                        EN_ID,    
                        HP_ID,    
                        Privilege_ID    
                    )     
                    SELECT     
                         @Version_ID    
                        ,@SecurityRoleID     
                        ,@MemberType_ID     
                        ,CASE @MemberType_ID WHEN 1 THEN ws.NewMemberID ELSE NULL END -- EN_ID    
                        ,CASE @MemberType_ID WHEN 2 THEN ws.NewMemberID ELSE NULL END -- HP_ID    
                        ,2 --Update    
                    FROM #MemberCodeWorkingSet AS ws    
                    WHERE ws.NewMemberID IS NOT NULL    
                    ;';    
                EXEC sp_executesql @SQL, N'@Version_ID INT, @SecurityRoleID INT, @MemberType_ID TINYINT', @Version_ID, @SecurityRoleID, @MemberType_ID;    
            END    
                
            --Put a msg onto the SB queue to process member security    
            EXEC mdm.udpSecurityMemberQueueSave     
                @Role_ID    = NULL,-- update member count cache for all users    
                @Version_ID = @Version_ID,     
                @Entity_ID  = @Entity_ID;    
        END;    
    
        --In a Merge situation we do not care that the code exists so we clear out any of those errors.  During a Merge operation we set @ErrorIfExists = 0.    
        IF COALESCE(@ErrorIfExists, 0) = 0 BEGIN    
            UPDATE #MemberCodeWorkingSet    
            SET ErrorCode = NULL,    
                ErrorObjectType = NULL    
            WHERE ErrorCode = @ErrorCode_MemberCodeExists;    
        END    
    
        --Clear out any duplicate input member code errors because those are not real errors that need to be returned to the consumer.                                    
        UPDATE #MemberCodeWorkingSet    
        SET ErrorCode = NULL,    
            ErrorObjectType = NULL    
        WHERE ErrorCode = @ErrorCode_DuplicateInputMemberCodes;    
    
        IF @ReturnErrors = 1 OR @ReturnCreatedMembers = 1    
        BEGIN    
            --If ReturnCreatedMembers is turned on, return the create items    
            --along with those in error. If ReturnCreatedMembers is turned    
            --off, only return items that have errors                                     
            SELECT     
                 MemberCode    
                ,MemberName    
                ,NewMemberID    
                ,MUID    
                ,HierarchyName    
                ,Attribute_MUID    
                ,AttributeName    
                ,ErrorCode    
                ,ErrorObjectType    
            FROM #MemberCodeWorkingSet    
            WHERE   @ReturnCreatedMembers = 1     
                OR (@ReturnErrors = 1 AND ErrorCode IS NOT NULL)    
        END;    
        IF @ReturnErrors = 0    
        BEGIN    
            -- Raise an error for the first error in the working set    
            DECLARE @FirstErrorCode INT = NULL;    
            SELECT TOP 1     
                @FirstErrorCode = ErrorCode     
            FROM #MemberCodeWorkingSet     
            WHERE ErrorCode IS NOT NULL;    
    
            IF @FirstErrorCode IS NOT NULL    
            BEGIN    
                DECLARE @Message NVARCHAR(50) = N'MDSERR' + CONVERT(NVARCHAR, @FirstErrorCode);    
                RAISERROR(@Message, 16, 1);    
            END;    
        END;    
    
        --The add was successful    
        --Invalidate the cached member count for this entity    
        UPDATE mdm.tblUserMemberCount    
            SET    
                LastCount=-1,    
                LastChgDTM=GETUTCDATE()    
            WHERE    
                Version_ID=@Version_ID AND    
                Entity_ID=@Entity_ID AND    
                MemberType_ID=@MemberType_ID    
    
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
        --SELECT @ErrorMessage += N'Line: ' + CONVERT(NVARCHAR(20), @ErrorLine);    
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);            
        RETURN(1);    
    
    END CATCH;    
    
    SET NOCOUNT OFF;    
END; --proc
GO
