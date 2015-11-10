SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    --Create free form attribute  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER, @Type INT;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    SET @Type = 1; --SET NVARCHAR=1, DECIMAL=2, DATETIME=3  
    EXEC mdm.udpAttributeSave 1,NULL,1,1,'Comments 10','Comments 10',200,NULL,@Type,5,NULL,0,@Return_ID OUTPUT,@Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblAttribute WHERE ID = @Return_ID;  
  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER, @Type INT;  
    SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    SET @Type = 1; --SET NVARCHAR=1, DECIMAL=2, DATETIME=3  
    EXEC mdm.udpAttributeSave 1,NULL,46,1,'Name','Name',200,NULL,@Type,5,NULL,0,@Return_ID OUTPUT,@Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblAttribute WHERE ID = @Return_ID;  
  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER, @Type INT;  
    SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    SET @Type = 1; --SET NVARCHAR=1, DECIMAL=2, DATETIME=3  
    EXEC mdm.udpAttributeSave 1,NULL,46,3,'Description','Description',200,NULL,@Type,5,NULL,0,@Return_ID OUTPUT,@Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblAttribute WHERE ID = @Return_ID;  
  
    --Create DBA attribute  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER, @DomainEntity_ID INT;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    SET @DomainEntity_ID = 4;  
    EXEC mdm.udpAttributeSave 1,NULL,8,1,'Attr5','Attr 5',0,@DomainEntity_ID,NULL,NULL,NULL,0,@Return_ID OUTPUT,@Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblAttribute WHERE ID = @Return_ID;  
  
    --Create FILE attribute  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpAttributeSave 1,NULL,8,1,'Attr4','Attr 4',0,-1,NULL,NULL,NULL,0,@Return_ID OUTPUT,@Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblAttribute WHERE ID = @Return_ID;  
  
    --Update name and type of free form attribute  
    DECLARE @Return_ID INT, @Return_MUID UNIQUEIDENTIFIER;  
    --SET @Return_MUID = NEWID(); SELECT @Return_MUID; --Uncomment to test clone operation  
    EXEC mdm.udpAttributeSave 1,1584,8,1,'ABCDE','A B C D E',200,NULL,3,NULL,NULL,0,@Return_ID OUTPUT,@Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
    SELECT * FROM mdm.tblAttribute WHERE ID = @Return_ID;  
*/  
CREATE PROCEDURE [mdm].[udpAttributeSave]  
(  
    @User_ID                INT,  
    @Attribute_ID           INT = NULL,  
    @Entity_ID              INT,   
    @MemberType_ID          INT,  
    @Name                   NVARCHAR(50),   
    @DisplayName            NVARCHAR(50),   
    @DisplayWidth           INT,   
    @DomainEntity_ID        INT,  
    @DataType_ID            TINYINT = NULL,  
    @DataTypeInformation    INT = NULL,  
    @InputMask_ID           INT = NULL,  
    @ChangeTrackingGroup    INT = 0,  
    @SortOrder              INT = NULL,  
    @Return_ID              INT = NULL OUTPUT,  
    @Return_MUID            UNIQUEIDENTIFIER = NULL OUTPUT --Also an input parameter for clone operations  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @TableName              sysname,  
            @Version_ID             INT,  
            @AttributeType_ID       INT,  
            @SQL                    NVARCHAR(MAX),   
            @Model_ID               INT,  
            @CurrentDTM             DATETIME2(3),  
            @TableColumn            sysname,  
            @IsCloneMode            BIT,  
            @ExistingSysAttr_MUID   UNIQUEIDENTIFIER,  
            @CurrentDataType_ID     INT,  
            @CurrentDataTypeInfo    INT,  
            @CurrentSortOrder       INT,  
            @StagingBase            NVARCHAR(60),  
            @StagingTableName       sysname,   
              
            -- MemberType constants  
            @MemberTypeLeaf         TINYINT = 1,  
            @MemberTypeConsolidated TINYINT = 2,  
            @MemberTypeCollection   TINYINT = 3,  
  
            -- AttributeType constants  
            @AttributeTypeFreeform  TINYINT = 1,  
            @AttributeTypeDomain    TINYINT = 2,  
            @AttributeTypeSystem    TINYINT = 3,  
            @AttributeTypeFile      TINYINT = 4,  
  
            -- AttributeDataType constants  
            @DataTypeText           TINYINT = 1,  
            @DataTypeNumber         TINYINT = 2,  
            @DataTypeDateTime       TINYINT = 3,  
            @DataTypeLink           TINYINT = 6,  
               
            @Compress               NVARCHAR(MAX) = N'',  
            @TranCommitted          INT = 0, -- 0: Not committed, 1: Committed.  
            @PreviousAttributeName  NVARCHAR(50);    
  
    --Initialize output parameters and local variables  
    SELECT   
        @Name = NULLIF(LTRIM(RTRIM(@Name)), N''),  
        @DisplayName = NULLIF(LTRIM(RTRIM(@DisplayName)), N''),  
        @Return_ID = NULL,   
        @CurrentDTM = GETUTCDATE(),  
        @IsCloneMode = CASE WHEN @Return_MUID IS NULL THEN 0 ELSE 1 END;  
  
    --Test for invalid parameters:  
    --Invalid @ChangeTrackingGroup  
    IF @ChangeTrackingGroup NOT BETWEEN 0 AND 31  
    BEGIN   
        RAISERROR('MDSERR100108|Change Tracking Group must be an integer between 0 and 31.', 16, 1);  
        RETURN;  
    END --IF  
               
    --Invalid @MemberType_ID  
    IF @MemberType_ID NOT IN (@MemberTypeLeaf, @MemberTypeConsolidated, @MemberTypeCollection) --Invalid MemberType  
    BEGIN  
        RAISERROR('MDSERR200015|The attribute cannot be saved. The member type is not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    --Invalid @MemberType_ID for THIS entity  
    IF @MemberType_ID IN (@MemberTypeConsolidated, @MemberTypeCollection)   
    BEGIN  
        IF EXISTS(SELECT 1 FROM mdm.tblEntity WHERE ID = @Entity_ID AND IsFlat = 1)--Invalid MemberType  
        BEGIN  
            RAISERROR('MDSERR200072|The attribute cannot be saved. The member type is not valid for this entity.', 16, 1);  
            RETURN;  
        END;  
    END; --if  
  
    --Invalid @DataType_ID  
    IF @DataType_ID NOT IN (@DataTypeText, @DataTypeNumber, @DataTypeDateTime, @DataTypeLink) --Invalid @DataType_ID  
    BEGIN  
        RAISERROR('MDSERR200073|The attribute cannot be saved. The data type is not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    --Invalid @DisplayWidth  
    IF @DisplayWidth NOT BETWEEN 0 AND 500 --Invalid @DisplayWidth  
    BEGIN  
        RAISERROR('MDSERR200067|The attribute cannot be saved. The display width is not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    --Invalid @DomainEntity_ID (or not in same Model)  
    IF @DomainEntity_ID IS NOT NULL   
        AND @DomainEntity_ID NOT IN (-1, 0)   
        AND NOT EXISTS(SELECT 1 FROM mdm.tblEntity e INNER JOIN mdm.tblEntity d ON e.Model_ID = d.Model_ID AND e.ID = @Entity_ID AND d.ID = @DomainEntity_ID)  
    BEGIN  
        RAISERROR('MDSERR200068|The attribute cannot be saved. The DomainEntity ID is not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    IF NOT EXISTS(SELECT ID FROM mdm.tblUser WHERE ID = @User_ID) --Invalid @User_ID  
    BEGIN  
        RAISERROR('MDSERR100009|The User ID is not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    -- Validate @Name  
    IF ISNULL(@Name, '') = ''  
    BEGIN  
        RAISERROR('MDSERR100003|The Name is not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    --Reserved characters check  
    DECLARE @NameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @Name, @NameHasReservedCharacters OUTPUT;  
  
    DECLARE @DisplayNameHasReservedCharacters BIT;  
    EXEC mdm.udpMetadataItemReservedCharactersCheck @DisplayName, @DisplayNameHasReservedCharacters OUTPUT;  
  
    IF @NameHasReservedCharacters = 1 OR @DisplayNameHasReservedCharacters = 1  
    BEGIN  
        RAISERROR('MDSERR100047|The attribute cannot be created because it contains characters that are not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    -- Validate @Entity_ID  
    DECLARE @IsValidParam BIT;  
    SET @IsValidParam = 1;  
    EXECUTE @IsValidParam = mdm.udpIDParameterCheck @Entity_ID, 5, NULL, NULL, 1;  
    IF (@IsValidParam = 0)  
    BEGIN  
        RAISERROR('MDSERR200014|The attribute cannot be saved. The entity ID is not valid.', 16, 1);  
        RETURN;  
    END; --if  
      
    --Invalid @Attribute_ID (or not in same Entity)  
    IF @Attribute_ID IS NOT NULL AND NOT EXISTS(  
                SELECT a.ID FROM mdm.tblModel m   
                INNER JOIN mdm.tblEntity e ON (m.ID = e.Model_ID)   
                INNER JOIN mdm.tblAttribute a ON (e.ID = a.Entity_ID)  
                WHERE e.ID = @Entity_ID --Invalid @Entity_ID  
                AND a.ID = @Attribute_ID) --Invalid @Attribute_ID  
    BEGIN  
        RAISERROR('MDSERR200016|The attribute cannot be saved. The attribute ID is not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    IF EXISTS (SELECT * FROM mdm.tblAttribute WHERE Entity_ID = @Entity_ID AND MemberType_ID = @MemberType_ID AND [Name] = @Name)  
    BEGIN  
            -- Special handling for system attributes, those created when an entity is created or an entity's explicit hierarchy is created for the first time.  
            -- Determine if this is a system attribute by setting the @Attribute_ID, which will be used to update the attribute later.  
            SELECT @Attribute_ID = ID  
            FROM mdm.tblAttribute  
            WHERE Entity_ID = @Entity_ID  
            AND   MemberType_ID = @MemberType_ID  
            AND   [Name] = @Name  
            AND   IsSystem = 1  
  
            IF @Attribute_ID IS NULL  
                -- The name already exists but it is NOT a system attribute so return appropriate error.  
                BEGIN  
                    RAISERROR('MDSERR100003|The Name is not valid.', 16, 1);  
                    RETURN;  
                END  
    END; --if  
  
          
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        --Get the @Model_ID and latest Model version  
        SELECT @Model_ID = E.Model_ID, @Version_ID = MAX(MV.ID)   
        FROM mdm.tblEntity E   
        INNER JOIN mdm.tblModelVersion MV ON (E.Model_ID = MV.Model_ID)  
        WHERE E.ID = @Entity_ID  
        GROUP BY E.Model_ID;  
  
        --Get the appropriate table name  
        SELECT @TableName = CASE @MemberType_ID  
                WHEN @MemberTypeLeaf THEN EntityTable   
                WHEN @MemberTypeConsolidated THEN HierarchyParentTable   
                WHEN @MemberTypeCollection THEN CollectionTable  
            END --case  
        FROM   
            mdm.tblEntity   
        WHERE   
            ID = @Entity_ID;  
                  
        --Get the Staging Table Name and Staging Base.   
        SELECT @StagingTableName = Entity_StagingTableName, @StagingBase = Entity_StagingBase FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES WHERE Entity_ID = @Entity_ID AND Attribute_MemberType_ID = @MemberType_ID;  
                  
        --Figure out the Attribute Type  
        SET @AttributeType_ID = CASE ISNULL(@DomainEntity_ID, 0)  
            WHEN -1 THEN @AttributeTypeFile   
            WHEN 0 THEN @AttributeTypeFreeform   
            ELSE @AttributeTypeDomain   
        END; --case  
          
        IF (@SortOrder IS NULL OR @SortOrder = 0)  
            BEGIN  
                SELECT @SortOrder = MAX(a.SortOrder) + 1  
                FROM mdm.tblAttribute AS a  
                INNER JOIN mdm.tblEntity AS e ON (a.Entity_ID = e.ID)  
                WHERE a.Entity_ID = @Entity_ID AND a.MemberType_ID = @MemberType_ID  
                GROUP BY e.IsSystem  
  
                -- If we still couldn't find  a sort order, default to 1  
                IF (@SortOrder IS NULL)  
                BEGIN  
                    SET @SortOrder = 1  
                END  
            END  
  
        --Update/Insert Attribute details  
        IF @Attribute_ID IS NOT NULL BEGIN --Update Attribute  
          
            IF EXISTS(SELECT 1 FROM mdm.tblAttribute WHERE ID = @Attribute_ID AND IsSystem = 1) BEGIN --System Attribute  
                  
                --The only change we allow on system attributes is the DisplayWidth and MUID (clone scenario).  
                UPDATE mdm.tblAttribute SET  
                    MUID = ISNULL(@Return_MUID, MUID),  
                    DisplayWidth = ISNULL(@DisplayWidth, DisplayWidth),  
                    LastChgDTM = @CurrentDTM,  
                    LastChgUserID = @User_ID,  
                    LastChgVersionID = @Version_ID,  
                    ChangeTrackingGroup  = @ChangeTrackingGroup  
                WHERE  
                    ID = @Attribute_ID;  
                      
                SELECT @Name = [Name] FROM mdm.tblAttribute WHERE ID = @Attribute_ID;  
                  
            END ELSE BEGIN --Non-system Attribute  
  
                SELECT  
                    @TableColumn = TableColumn,  
                    @CurrentDataType_ID = DataType_ID,  
                    @CurrentDataTypeInfo = DataTypeInformation,  
                    @PreviousAttributeName = [Name],  
                    @CurrentSortOrder = SortOrder  
                FROM   
                    mdm.tblAttribute   
                WHERE   
                    ID = @Attribute_ID;  
  
                IF @CurrentSortOrder > @SortOrder BEGIN  
                    -- If sort order has changed by moving "down", make sure to increment the other attributes' sort order  
                    UPDATE mdm.tblAttribute SET  
                        SortOrder += 1  
                    WHERE  
                        SortOrder >= @SortOrder AND  
                        SortOrder < @CurrentSortOrder AND  
                        -- Only take into accounts attributes on the same entity of the same member type  
                        tblAttribute.Entity_ID = @Entity_ID AND  
                        tblAttribute.MemberType_ID = @MemberType_ID  
  
                END  
  
                IF @CurrentSortOrder < @SortOrder BEGIN  
                    -- If sort order has changed by moving "up", make sure to decrement the other attributes' sort order  
                    UPDATE mdm.tblAttribute SET  
                        SortOrder -= 1  
                    WHERE   
                        SortOrder <= @SortOrder AND   
                        SortOrder > @CurrentSortOrder AND  
                        -- Only take into accounts attributes on the same entity of the same member type  
                        tblAttribute.Entity_ID = @Entity_ID AND   
                        tblAttribute.MemberType_ID = @MemberType_ID  
                END  
  
                --Update details in the Attribute table  
                UPDATE mdm.tblAttribute SET  
                    [Name] = ISNULL(@Name, [Name]),  
                    DisplayName = ISNULL(@DisplayName, DisplayName),  
                    DisplayWidth = @DisplayWidth,   
                    InputMask_ID = ISNULL(@InputMask_ID, InputMask_ID),  
                    SortOrder = @SortOrder,  
                    LastChgDTM = @CurrentDTM,  
                    LastChgUserID = @User_ID,  
                    LastChgVersionID = @Version_ID,  
                    ChangeTrackingGroup = @ChangeTrackingGroup  
                WHERE  
                    ID = @Attribute_ID;  
                      
                --Update column name of the staging table when @StagingTableName is specified.  
                IF @Name IS NOT NULL AND @PreviousAttributeName <> @Name AND COALESCE(@StagingTableName, N'') <> N'' BEGIN  
                    SET @SQL = N'EXEC sp_rename N''stg.' + quotename(@StagingTableName) + N'.' + @PreviousAttributeName + N''', N''' + @Name + N''', ''COLUMN'';';  
                    --Execute the dynamic SQL  
                    EXEC sp_executesql @SQL;  
                END; --IF  
            END; --if  
     
            --Populate output parameters  
            SELECT @Return_MUID = MUID FROM mdm.tblAttribute WHERE ID = @Attribute_ID;  
            
        END ELSE BEGIN --New Attribute  
  
            --Coalesce defaults for specific parameters  
            SELECT  
                --Accept an explicit MUID (for clone operations) or generate a new one  
                @Return_MUID = ISNULL(@Return_MUID, NEWID()),   
                @DataType_ID = ISNULL(@DataType_ID, @DataTypeText),   
                @DataTypeInformation = ISNULL(@DataTypeInformation, 0),   
                @InputMask_ID = ISNULL(@InputMask_ID, 1);  
  
            -- Always use Link data type for file attributes.  
            IF (@AttributeType_ID = @AttributeTypeFile) BEGIN  
                SET @DataType_ID = @DataTypeLink;  
            END;  
  
            --Insert details into Attribute table  
            INSERT INTO mdm.tblAttribute  
            (  
                Entity_ID,   
                SortOrder,   
                DomainEntity_ID,  
                AttributeType_ID,   
                MemberType_ID,  
                IsSystem,  
                IsReadOnly,  
                [Name],  
                DisplayName,  
                TableColumn,  
                DisplayWidth,  
                DataType_ID,  
                DataTypeInformation,  
                InputMask_ID,  
                MUID,  
                EnterUserID,  
                EnterVersionID,  
                LastChgUserID,  
                LastChgVersionID,  
                ChangeTrackingGroup  
            )   
            SELECT  
                @Entity_ID,   
                @SortOrder,  
                CASE   
                    WHEN @DomainEntity_ID > 0 THEN @DomainEntity_ID  
                    ELSE NULL --Distinguish between FILE and F/F using AttributeType_ID  
                END, --case  
                @AttributeType_ID,   
                @MemberType_ID,  
                0, --IsSystem = False   
                0, --IsReadOnly = False  
                @Name,  
                @DisplayName,   
                NEWID(), --Temporary value since this is a required column  
                @DisplayWidth,   
                @DataType_ID,  
                @DataTypeInformation,  
                @InputMask_ID,  
                @Return_MUID,  
                @User_ID,  
                @Version_ID,  
                @User_ID,  
                @Version_ID,  
                @ChangeTrackingGroup     
  
            --Save the identity value  
            SET @Attribute_ID = SCOPE_IDENTITY();  
  
            --Generate the physical column name and replace the default generated value.   
            --Note that a random value would work fine, but a reproducible value makes debugging simpler.  
            --Note that @Attribute_ID required to maintain uniqueness. For example user creates attribute 'Color'   
            --which instantiates as column [A]. They rename 'Color' to 'Size' but the column stays as [A].   
            --They then create a new attribute called 'Color' which - if @Attribute_ID was not used to uniqify   
            --the generated name it would try to instantiate the column as [A] again --> Error.  
            SET @TableColumn = N'uda_' + CONVERT(NVARCHAR(30), @Entity_ID) + N'_' + CONVERT(NVARCHAR(30), @Attribute_ID);  
            UPDATE mdm.tblAttribute SET TableColumn = @TableColumn WHERE ID = @Attribute_ID;  
  
            --Add the column to the Entity table.  
            SET @SQL = N'ALTER TABLE mdm.' + quotename(@TableName) + N' ADD ' + quotename(@TableColumn) + N' ';  
            IF @AttributeType_ID = @AttributeTypeFreeform BEGIN   
                IF @DataType_ID = @DataTypeText OR @DataType_ID = @DataTypeLink BEGIN   
                    IF @DataTypeInformation < 1 SET @DataTypeInformation = 1;  
                    ELSE IF @DataTypeInformation > 4000 SET @DataTypeInformation = 4000; --Arbitrary limit  
                    SET @SQL = @SQL + N'NVARCHAR(' + CONVERT(NVARCHAR(30), @DataTypeInformation) + N') NULL;';  
                END ELSE IF @DataType_ID = @DataTypeNumber BEGIN   
                    IF @DataTypeInformation < 0 SET @DataTypeInformation = 0; --DECIMAL(38, 0) is minimum precision allowed by SQL  
                    ELSE IF @DataTypeInformation > 38 SET @DataTypeInformation = 38; --DECIMAL(38, 38) is maximum precision allowed by SQL  
                    SET @SQL = @SQL + N'DECIMAL(38, ' + CONVERT(NVARCHAR(2), @DataTypeInformation) + N') NULL;';  
                END ELSE IF @DataType_ID = @DataTypeDateTime BEGIN  
                    SET @SQL = @SQL + N'DATETIME2(3) NULL;';  
                END; --if  
            END ELSE BEGIN --DBA/FILE  
                SET @SQL = @SQL + N'INTEGER NULL;';  
            END --if  
  
            --Execute the dynamic SQL  
            EXEC sp_executesql @SQL;  
  
            --Create the FK & FK index for DBA & FIL attributes.  
            IF @AttributeType_ID = @AttributeTypeDomain BEGIN   
  
                --Foreign key constraint definition  
                SELECT @SQL = N'  
                    ALTER TABLE mdm.' + quotename(@TableName) + N' ADD CONSTRAINT  
                        ' + quotename(N'fk_' + @TableName + N'_' + EntityTable + N'_Version_ID_' + @TableColumn) + N'  
                        FOREIGN KEY (Version_ID, ' + quotename(@TableColumn) + N')   
                        REFERENCES mdm.' + quotename(EntityTable) + N'(Version_ID, ID);'  
                FROM mdm.tblEntity WHERE ID = @DomainEntity_ID;  
  
                --Foreign key index definition  
                SET @SQL = @SQL + N'  
                    CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @TableName + N'_Version_ID_' + @TableColumn) + N'   
                        ON mdm.' + quotename(@TableName) + N'(Version_ID, ' + quotename(@TableColumn) + N')  
                        ' + @Compress + N';';  
  
                EXEC sp_executesql @SQL;  
  
            END ELSE IF @AttributeType_ID = @AttributeTypeFile BEGIN   
  
                --Foreign key constraint definition  
                SET @SQL = N'  
                    ALTER TABLE mdm.' + quotename(@TableName) + N' ADD CONSTRAINT  
                        ' + quotename(N'fk_' + @TableName + N'_tblFile_' + @TableColumn) + N'  
                        FOREIGN KEY (' + quotename(@TableColumn) + N')   
                        REFERENCES mdm.tblFile(ID);';  
  
                --Foreign key index definition  
                SET @SQL = @SQL + N'  
                    CREATE NONCLUSTERED INDEX ' + quotename(N'ix_' + @TableName + N'_' + @TableColumn ) + N'   
                        ON mdm.' + quotename(@TableName) + N'(' + quotename(@TableColumn) + N')  
                        ' + @Compress + N';';  
  
                EXEC sp_executesql @SQL;  
  
            END; --if  
              
            --Add the column to the Staging table.  
            IF LEN(COALESCE(@StagingTableName, N'')) > 0   
            BEGIN  
                SET @SQL = N'ALTER TABLE stg.' + quotename(@StagingTableName) + N' ADD ' + quotename(@Name) + N' ';    
                IF @AttributeType_ID = @AttributeTypeFreeform BEGIN     
                    IF @DataType_ID = @DataTypeText OR @DataType_ID = @DataTypeLink BEGIN     
                        IF @DataTypeInformation < 1 SET @DataTypeInformation = 1;    
                        ELSE IF @DataTypeInformation > 4000 SET @DataTypeInformation = 4000; --Arbitrary limit    
                        SET @SQL = @SQL + N'NVARCHAR(' + CONVERT(NVARCHAR(30), @DataTypeInformation) + N') NULL;';    
                    END ELSE IF @DataType_ID = @DataTypeNumber BEGIN     
                        IF @DataTypeInformation < 0 SET @DataTypeInformation = 0; --DECIMAL(38, 0) is minimum precision allowed by SQL    
                        ELSE IF @DataTypeInformation > 38 SET @DataTypeInformation = 38; --DECIMAL(38, 38) is maximum precision allowed by SQL    
                        SET @SQL = @SQL + N'DECIMAL(38, ' + CONVERT(NVARCHAR(2), @DataTypeInformation) + N') NULL;';    
                    END ELSE IF @DataType_ID = @DataTypeDateTime BEGIN     
                        SET @SQL = @SQL + N'DATETIME2(3) NULL;';    
                    END; --if    
                END ELSE BEGIN --DBA/FILE    
                    SET @SQL = @SQL + N'NVARCHAR(250) NULL;';   
                END --if    
        
                --Execute the dynamic SQL    
                EXEC sp_executesql @SQL;  
                  
            END; --IF  
               
            --Populate output parameters  
            SELECT @CurrentDataType_ID = @DataType_ID;  
  
            ----Create related metadata member  
            DECLARE @AttributeMetadataCode NVARCHAR(100) -- We will build out attribute metadata codes as modelid_entityid_attributeid to ensure uniqueness  
            DECLARE @IsSystemEntity BIT  
              
            SELECT @IsSystemEntity = IsSystem FROM mdm.tblEntity WHERE ID = @Entity_ID  
            SET @AttributeMetadataCode = CONVERT(NVARCHAR(20), @Model_ID) + N'_' + CONVERT(NVARCHAR(20), @Entity_ID) + N'_' + CONVERT(NVARCHAR(20), @Attribute_ID) + N'_' + CONVERT(NVARCHAR(1), @MemberType_ID)  
              
            IF (@IsSystemEntity = 0) EXEC mdm.udpUserDefinedMetadataSave N'Attribute', @Return_MUID, @Name, @AttributeMetadataCode, @User_ID  
  
        END; --if new attribute  
  
        --Recreate the views  
        EXEC mdm.udpCreateViews @Model_ID, @Entity_ID;  
                  
        --Return values  
        SET @Return_ID = @Attribute_ID;  
        SELECT  
            @Attribute_ID AS ID,   
            @Name AS CurrentName, --!Is this the right value to use?  
            @DataType_ID AS CurrentDataTypeID, --!Is this the right value to use?  
            @Model_ID AS ModelID;  
  
        --Commit only if we are not nested  
        IF @TranCounter = 0   
        BEGIN  
            COMMIT TRANSACTION;  
            SET @TranCommitted = 1;  
        END; -- IF  
          
        -- Recreate the staging stored procedure.  
        IF @MemberType_ID = @MemberTypeLeaf  
        BEGIN  
            EXEC mdm.udpEntityStagingCreateLeafStoredProcedure @Entity_ID   
        END -- IF  
        ELSE IF @MemberType_ID = @MemberTypeConsolidated BEGIN  
            EXEC mdm.udpEntityStagingCreateConsolidatedStoredProcedure @Entity_ID  
        END -- IF  
          
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
  
        IF @TranCommitted = 0 -- Don't rollback when the transaction has been committed.  
        BEGIN  
            IF @TranCounter = 0 ROLLBACK TRANSACTION;    
            ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;    
        END; -- IF  
  
        --On error, return NULL results  
        SELECT @Attribute_ID = NULL, @Return_MUID = NULL, @TableColumn = NULL, @Name = NULL, @CurrentDataType_ID = NULL, @CurrentDataTypeInfo = NULL, @Model_ID = NULL;  
          
        --Throw the error again so the calling procedure can use it  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
          
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
