SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Description: Bulk updates entity member attribute values.  Input member attribute values are supplied in the form of a  
             Entity-Attribute-Value (EAV) table.  Through the use of the UNPIVOT and PIVOT commands this sproc is able   
             to update the entity member table in one UPDATE statment.  
  
The following are assumed validated prior to calling and are not validated here:  
    * User  
    * Version  
    * Entity  
    * Member Type  
  
    --Parameters  
    DECLARE  
        @User_ID                    INT = 1,  
        @Version_ID                    INT = 20,  
        @Entity_ID                    INT = 31,  
        @MemberType_ID                INT = 1,  
        @MemberAttributes            mdm.MemberAttributes,  
          
    --Sample parameter values  
    --No DBAs  
    INSERT INTO @MemberAttributes (MemberCode, AttributeName, AttributeValue)  
    VALUES  
         (N'A', N'ModelName', N'ABC')  
        ,(N'A', N'StandardCost', N'236.79')  
        ,(N'B', N'ModelName', N'ABC')  
        ,(N'A', N'StandardCost', N'143.65')  
    ;  
  
    With DBAs  
    INSERT INTO @MemberAttributes (MemberCode, AttributeName, AttributeValue)  
    VALUES  
         (N'A', N'ModelName', N'DEF')  
        ,(N'A', N'Color', N'Black')  
        ,(N'A', N'SubCategory', N'14')  
        ,(N'A', N'StandardCost', N'136.79')  
  
        ,(N'B', N'ModelName', N'DEF')  
        ,(N'B', N'Color', N'Black')  
        ,(N'B', N'SubCategory', N'14')  
        ,(N'A', N'StandardCost', N'343.65')  
    ;  
  
    Get all existing products.  Attributes: SubCategory, Color, StandardCost, ModelName  
    WITH cte AS (                  
        SELECT  
            Code,   
            CONVERT(NVARCHAR(MAX),SubCategory) AS SubCategory,  
            CONVERT(NVARCHAR(MAX),Color) AS Color,  
            CONVERT(NVARCHAR(MAX),StandardCost) AS StandardCost,  
            CONVERT(NVARCHAR(MAX),ModelName) AS ModelName      
        FROM mdm.viw_SYSTEM_7_31_CHILDATTRIBUTES AS m  
        WHERE m.Version_ID = @Version_ID  
    )  
    INSERT INTO @MemberAttributes (MemberCode, AttributeName, AttributeValue)  
    SELECT Code, priorPivot.AttributeName, priorPivot.AttributeValue  
    FROM  (  
        select Code, U.AttributeName, U.AttributeValue  
        FROM cte    
        UNPIVOT  
        (AttributeValue FOR AttributeName IN (SubCategory, Color, StandardCost, ModelName))    AS U  
        ) priorPivot;  
  
EXEC mdm.udpEntityMembersUpdate @User_ID, @Version_ID, @Entity_ID, @MemberType_ID, @MemberAttributes, 1, 0;  
  
--For new members where we want to ignore prior values  
EXEC mdm.udpEntityMembersUpdate @User_ID, @Version_ID, @Entity_ID, @MemberType_ID, @MemberAttributes, 1, 0, 1;  
  
*/  
CREATE PROCEDURE [mdm].[udpEntityMembersUpdate]  
(  
    @User_ID                    INT,  
    @Version_ID                 INT,  
    @Entity_ID                  INT,  
    @MemberType_ID              INT,  
    @MemberAttributes           mdm.MemberAttributes READONLY,  
    @LogFlag                    INT = NULL, --1 = Log anything else = NotLog  
    @DoInheritanceRuleCheck     BIT = NULL,  
    --This flag instructs udpEntityMembersUpdate to not try and retrieve prior values for the attributes  
    --being updated. We turn this on when calling this SPROC during an update because we know there will  
    --be no prior values to retrieve  
    @IgnorePriorValues          BIT = 0,  
    @ShouldReturnMembersWithErrorsAsXml  BIT = 0, -- Default to not return the xml  
    @Return_MembersWithErrors   XML = NULL OUTPUT      
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
         @TableName                         sysname  
        ,@ViewName                          sysname  
        ,@ParentChildDerivedView            sysname  
        ,@TableColumn                       sysname  
        ,@SQL                               NVARCHAR(MAX) = N''  
        ,@ValidationStatus                  INT  
        ,@Model_ID                          INT  
        ,@EntityTable                       sysname  
        ,@HierarchyParentTable              sysname  
        ,@CollectionTable                   sysname  
        ,@SecurityTable                     sysname  
        ,@IsFlat                            BIT  
        ,@HasDba                            BIT  
        ,@HasFile                           BIT  
        ,@RecursiveHierarchy_ID             INT = 0  
        ,@RecursiveHierarchyAttribute_ID    INT = 0  
        ,@RecursiveHierarchyMaxLevel        INT = 0  
        ,@DependentEntityTable              sysname  
        ,@DependentAttributeName            sysname  
        ,@DependentAttributeColumnName      sysname  
        ,@ErrorCode                         INT  
        ,@ErrorObjectType                   INT  
        ,@Counter                           INT = 1  
        ,@MaxCounter                        INT  
  
        --Member Types  
        ,@MemberType_Leaf               INT = 1  
        ,@MemberType_Consolidated       INT = 2  
        ,@MemberType_Collection         INT = 3  
  
        --Attribute Types  
        ,@AttributeType_FreeForm        INT = 1    
        ,@AttributeType_DBA             INT = 2    
        ,@AttributeType_File            INT = 4    
          
        --Attribute DataTypes  
        ,@AttributeDataType_Text        INT = 1    
        ,@AttributeDataType_Number      INT = 2    
        ,@AttributeDataType_DateTime    INT = 3    
        ,@AttributeDataType_Link        INT = 6    
          
        --Table column SQL snippets  
        ,@TableColumns                  NVARCHAR(MAX) = N''  
        ,@TableColumnsDba               NVARCHAR(MAX) = N''  
        ,@TableColumnsFile              NVARCHAR(MAX) = N''  
        ,@TableColumnsPivotDefn         NVARCHAR(MAX) = N''  
        ,@TableColumnsUnPivotDefn       NVARCHAR(MAX) = N''  
        ,@TableColumnsUnPivotDbaDefn    NVARCHAR(MAX) = N''  
        ,@TableColumnsUnPivotFileDefn   NVARCHAR(MAX) = N''  
        ,@TableColumnsUpdateDefn        NVARCHAR(MAX) = N''  
        ,@TableColumnsUpdateDbaIdsDefn  NVARCHAR(MAX) = N''  
          
        --Validation Statuses  
        ,@ValidationStatus_AwaitingRevalidation                 INT = 4  
        ,@ValidationStatus_AwaitingDependentMemberRevalidation  INT = 5  
  
        --Error ObjectTypes  
        ,@ObjectType_MemberCode         INT = 12  
        ,@ObjectType_MemberAttribute    INT = 22  
  
        --Error Codes  
        ,@ErrorCode_ReservedWord                                INT = 110006  
        ,@ErrorCode_AttributeValueLengthGreaterThanMaximum      INT = 110017  
        ,@ErrorCode_NoPermissionForThisOperationOnThisObject    INT = 120003  
        ,@ErrorCode_DuplicateInputMemberCodes                   INT = 210001  
        ,@ErrorCode_InvalidMemberCode                           INT = 300002  
        ,@ErrorCode_MemberCodeExists                            INT = 300003  
        ,@ErrorCode_InvalidAttribute                            INT = 300010  
        ,@ErrorCode_ReadOnlyAttribute                           INT = 300014  
        ,@ErrorCode_MemberCausesCircularReference               INT = 300020  
        ,@ErrorCode_DeactivatedMemberCodeExists                 INT = 300034    
        ,@ErrorCode_InvalidFlatEntityForMemberCreate            INT = 310021  
        ,@ErrorCode_InvalidBlankMemberCode                      INT = 310022  
        ,@ErrorCode_InvalidAttributeValueForDataType            INT = 310033  
        ,@ErrorCode_InvalidAttributeValueForMember              INT = 310042  
  
        --Security Levels  
        ,@SecurityLevel                     TINYINT  
        ,@DbaSecurityLevel                  TINYINT  
        ,@SecLvl_NoAccess                   TINYINT = 0  
        ,@SecLvl_ObjectSecurity             TINYINT = 1  
        ,@SecLvl_MemberSecurity             TINYINT = 2  
        ,@SecLvl_ObjectAndMemberSecurity    TINYINT = 3  
  
        --Permission  
        ,@Permission_None       INT = 0  
        ,@Permission_Deny       INT = 1  
        ,@Permission_Update     INT = 2  
        ,@Permission_ReadOnly   INT = 3  
        ,@Permission_Inferred   INT = 99  
  
        ,@MemberIds                        mdm.MemberId  
  
        --Special value that input attribute NULL values get mapped to.  
        ,@SysNull_Text          NVARCHAR(50) = N'#SysNull#-' + CONVERT(NVARCHAR(50),NEWID()) --Adding a GUID to guarantee uniqueness.  
        ,@SysNull_Number        INT = -2147483648 --Lower bound of INT  
        ,@SysNull_DateTime      DATETIME2(3) = GETUTCDATE() --Get current date and time  
  
        --Values to track recursive derived hierarchy circular reference issues  
        ,@CircularReferenceErrors INT = 0  
  
        --Store the current time for use in this SPROC  
        ,@CurrentTime           DATETIME2(3) = GETUTCDATE()  
  
        --Transaction type for entity member update  
        ,@TransactionType_Update INT = 3  
  
        --Is the entity code gen enabled  
        ,@CodeGenEnabled BIT = 0  
  
    ;  
    DECLARE @MemberPermissions AS TABLE (ID INT, MemberType_ID INT, Privilege_ID INT);  
    DECLARE @SysNullDataTypeMap AS TABLE (AtributeType_ID INT, DataType_ID INT, SysNullName NVARCHAR(20), SysNullValue NVARCHAR(60));  
  
    ----------------------------------------------------------------------------------------  
    --Temporary tables  
    --  These must be temp tables vs. table variables because we need to reference them  
    --  in dynamic SQL.  
    ----------------------------------------------------------------------------------------  
    --Working set and the final results to be returned.  
    CREATE TABLE #MemberAttributeWorkingSet  
        (  
          Row_ID                INT IDENTITY(1,1) NOT NULL  
         ,Member_ID             INT NULL  
         ,MemberCode            NVARCHAR(250) COLLATE DATABASE_DEFAULT NULL  
         ,MemberName            NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
         ,Attribute_ID          INT NULL  
         ,AttributeName         NVARCHAR(50) COLLATE DATABASE_DEFAULT NULL  
         ,AttributeValue        NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
         ,AttributeValueMapped  NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
         ,PriorValue            NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL      
         ,PriorValueMapped      NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL      
         ,PriorFileId           NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL   
         ,IsChanged             BIT NULL  
         ,ChangeTrackingMask    INT NULL  
         ,ErrorCode             INT NULL  
         ,ErrorObjectType       INT NULL  
         ,TransactionAnnotation NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
        );  
        CREATE NONCLUSTERED INDEX #ix_MemberAttributeWorkingSet_Member_ID ON #MemberAttributeWorkingSet(Member_ID);  
        CREATE NONCLUSTERED INDEX #ix_MemberAttributeWorkingSet_MemberCode ON #MemberAttributeWorkingSet(MemberCode);    
        CREATE NONCLUSTERED INDEX #ix_MemberAttributeWorkingSet_AttributeName ON #MemberAttributeWorkingSet(AttributeName);    
  
    --Store attribute definitions for attributes being updated.  
    CREATE TABLE #AttributeDefinition   
        (  
          Row_ID                        INT IDENTITY(1,1) NOT NULL  
         ,AttributeName                 NVARCHAR(50) COLLATE DATABASE_DEFAULT NULL  
         ,Attribute_ID                  INT NULL  
         ,Attribute_MUID                UNIQUEIDENTIFIER NULL  
         ,AttributeType_ID              TINYINT NULL  
         ,DataType_ID                   TINYINT NULL  
         ,DataTypeInformation           INT NULL  
         ,Dba_Entity_ID                 INT NULL  
         ,Dba_Entity_Table_Name         sysname COLLATE DATABASE_DEFAULT NULL  
         ,ChangeTrackingGroup_ID        INT NULL  
         ,TableColumn                   sysname COLLATE DATABASE_DEFAULT NULL  
         ,TableColumnPivotDefn          NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
         ,TableColumnUnPivotDefn        NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
         ,TableColumnUnPivotDbaDefn     NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
         ,TableColumnUnPivotFileDefn    NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
         ,TableColumnUpdateDefn         NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
         ,TableColumnUpdateDbaIdsDefn   NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
        );  
        CREATE UNIQUE CLUSTERED INDEX #ix_AttributeDefinition_Attribute_ID ON #AttributeDefinition(Attribute_ID);    
        CREATE UNIQUE NONCLUSTERED INDEX #ix_AttributeDefinition_AttributeName ON #AttributeDefinition(AttributeName);    
  
    ----------------------------------------------------------------------------------------  
    -- Insert attribute values into working set.  
    -- Trim codes, attribute names, etc.  
    ----------------------------------------------------------------------------------------  
    INSERT INTO #MemberAttributeWorkingSet  
        (MemberCode, AttributeName, AttributeValue, AttributeValueMapped, ErrorCode, ErrorObjectType, TransactionAnnotation)  
    SELECT  
         NULLIF(LTRIM(RTRIM(MemberCode)), N'')  
        ,NULLIF(LTRIM(RTRIM(AttributeName)), N'')  
        ,LTRIM(RTRIM(AttributeValue))  
        ,LTRIM(RTRIM(AttributeValue))  
        ,ErrorCode --We can get passed records that have already been processed and have an error code and object type.  
        ,ErrorObjectType  
        ,NULLIF(LTRIM(RTRIM(TransactionAnnotation)), N'')  
    FROM @MemberAttributes  
  
     ----------------------------------------------------------------------------------------  
    --Get Entity information.  
    ----------------------------------------------------------------------------------------  
  
    SELECT  
         @EntityTable = Quotename(EntityTable)  
        ,@HierarchyParentTable = Quotename(HierarchyParentTable)  
        ,@CollectionTable = Quotename(CollectionTable)  
        ,@SecurityTable = Quotename(SecurityTable)  
        ,@IsFlat = IsFlat  
        ,@Model_ID = Model_ID  
    FROM       
        mdm.tblEntity WHERE ID = @Entity_ID;  
  
    SELECT @ViewName = mdm.udfViewNameGetByID(@Entity_ID, @MemberType_ID, 0);  
  
    ----------------------------------------------------------------------------------------  
    --Check to see if the entity has a hierarchy  
    ----------------------------------------------------------------------------------------  
  
    IF @IsFlat = 1 BEGIN  
        --Entity has no hierarchies  
        IF @MemberType_ID <> @MemberType_Leaf BEGIN  
            UPDATE #MemberAttributeWorkingSet    
                SET ErrorCode = @ErrorCode_InvalidFlatEntityForMemberCreate,  
                    ErrorObjectType = @ObjectType_MemberCode  
            WHERE ErrorCode IS NULL;  
        END  
    END   
  
    --Figure out whether code generation is enabled  
    EXEC @CodeGenEnabled = mdm.udpIsCodeGenEnabled @Entity_ID;  
  
    IF @MemberType_ID =  @MemberType_Leaf  
        BEGIN  
            SELECT @TableName = @EntityTable;              
        END  
    ELSE IF @MemberType_ID =  @MemberType_Consolidated  
        BEGIN  
            SELECT @TableName = @HierarchyParentTable;  
        END  
    ELSE IF @MemberType_ID =  @MemberType_Collection  
        BEGIN  
            SELECT @TableName = @CollectionTable;  
        END  
  
    ----------------------------------------------------------------------------------------  
    --Load SysNull Datatype mappings.  Have to have separate INSERT statements because  
    --SysNullValue contains different datatypes.  
    ----------------------------------------------------------------------------------------  
    INSERT INTO @SysNullDataTypeMap (AtributeType_ID, DataType_ID, SysNullName, SysNullValue) VALUES (@AttributeType_FreeForm, @AttributeDataType_Text, N'@SysNull_Text', @SysNull_Text)  
    INSERT INTO @SysNullDataTypeMap (AtributeType_ID, DataType_ID, SysNullName, SysNullValue) VALUES (@AttributeType_FreeForm, @AttributeDataType_Number, N'@SysNull_Number', @SysNull_Number)  
    INSERT INTO @SysNullDataTypeMap (AtributeType_ID, DataType_ID, SysNullName, SysNullValue) VALUES (@AttributeType_FreeForm, @AttributeDataType_DateTime, N'@SysNull_DateTime', @SysNull_DateTime)  
    INSERT INTO @SysNullDataTypeMap (AtributeType_ID, DataType_ID, SysNullName, SysNullValue) VALUES (@AttributeType_FreeForm, @AttributeDataType_Link, N'@SysNull_Text', @SysNull_Text)  
    INSERT INTO @SysNullDataTypeMap (AtributeType_ID, DataType_ID, SysNullName, SysNullValue) VALUES (@AttributeType_DBA, @AttributeDataType_Text,N'@SysNull_Number' ,@SysNull_Number)  
    INSERT INTO @SysNullDataTypeMap (AtributeType_ID, DataType_ID, SysNullName, SysNullValue) VALUES (@AttributeType_File, @AttributeDataType_Link, N'@SysNull_Number', @SysNull_Number)  
  
    ----------------------------------------------------------------------------------------  
    --Get attribute definitions  
    ----------------------------------------------------------------------------------------  
  
    ;WITH cteUniqueAttributeNames AS  
    (  
        SELECT DISTINCT AttributeName FROM #MemberAttributeWorkingSet  
    )  
    INSERT INTO #AttributeDefinition   
    (  
        Attribute_ID, Attribute_MUID, AttributeName, AttributeType_ID, DataType_ID, DataTypeInformation, Dba_Entity_ID, Dba_Entity_Table_Name, ChangeTrackingGroup_ID,  
        TableColumn, TableColumnPivotDefn, TableColumnUnPivotDefn, TableColumnUnPivotDbaDefn, TableColumnUpdateDbaIdsDefn, TableColumnUpdateDefn, TableColumnUnPivotFileDefn  
    )  
    SELECT DISTINCT  
         att.Attribute_ID  
        ,att.Attribute_MUID  
        ,att.Attribute_Name  
        ,att.Attribute_Type_ID  
        ,att.Attribute_DataType_ID  
        ,att.Attribute_DataType_Information  
        ,att.Attribute_DBAEntity_ID  
        ,dbaEnt.EntityTable   
        ,att.Attribute_ChangeTrackingGroup  
        ,att.Attribute_Column  
        ,N'MAX(' + Quotename(att.Attribute_Name) + N') AS ' + att.Attribute_Column -- TableColumnPivotDefn  
        ,N'CONVERT(NVARCHAR(MAX),' + Quotename(att.Attribute_Name) + N') AS ' + Quotename(att.Attribute_Name) -- TableColumnUnPivotDefn  
        ,CASE  
            WHEN att.Attribute_Type_ID = @AttributeType_DBA   
            THEN N'CONVERT(NVARCHAR(MAX),' + Quotename(att.Attribute_Name + N'.ID') + N') AS ' + Quotename(att.Attribute_Name)  
            ELSE N''   
         END -- TableColumnUnPivotDbaDefn  
        ,CASE  
            WHEN att.Attribute_Type_ID = @AttributeType_DBA  
            THEN N'SELECT ID, Code, ' + CONVERT(NVARCHAR(20), att.Attribute_ID) + N' AS Attribute_ID FROM mdm.' + att.Attribute_DBAEntity_EntityTable + N' WHERE Version_ID = @Version_ID AND Status_ID = 1'   
            ELSE N''   
         END -- TableColumnUpdateDbaIdsDefn  
        ,CASE  
            WHEN att.Attribute_Name = N'Code'   
            THEN N'm.' + att.Attribute_Column + N'=COALESCE(updates.' + att.Attribute_Column + N',m.' + att.Attribute_Column + N')'  
  
            --Special handling for Owner_ID on collection members because in tblAttribute this  
            --attribute is registered as text. However, the column itself is an int. If we don't   
            --add this handling, the ELSE logic will try and put SysNull_Text as the relevant null value. We  
            --don't care about null values because the user can't possibly supply a null value (there will always  
            --be at least one user on the application)  
            WHEN att.Attribute_Name = N'Owner_ID' AND @MemberType_ID = 3  
            THEN N'm.' + att.Attribute_Column + N'=COALESCE(updates.' + att.Attribute_Column + N',m.' + att.Attribute_Column + N')'   
  
            ELSE   
                N'm.' + att.Attribute_Column + N'=NULLIF(COALESCE(updates.' + att.Attribute_Column + N', m.' + att.Attribute_Column + '),' + m.SysNullName + N')'  
         END -- TableColumnUpdateDefn  
         ,CASE  
            WHEN att.Attribute_Type_ID = @AttributeType_File  
            THEN N'CONVERT(NVARCHAR(MAX),' + Quotename(att.Attribute_Name + N'.ID') + N') AS ' + Quotename(att.Attribute_Name)  
            ELSE N''   
          END -- TableColumnUnPivotFileDefn  
    FROM  
        cteUniqueAttributeNames AS ws  
    INNER JOIN mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES att  
        ON att.Attribute_Name = ws.AttributeName  
        AND att.Entity_ID = @Entity_ID  
        AND att.Attribute_MemberType_ID = @MemberType_ID  
    INNER JOIN @SysNullDataTypeMap m  
        ON m.AtributeType_ID = att.Attribute_Type_ID  
        AND m.DataType_ID = att.Attribute_DataType_ID  
    LEFT JOIN mdm.tblEntity dbaEnt  
        ON dbaEnt.ID = att.Attribute_DBAEntity_ID;  
  
    ----------------------------------------------------------------------------------------  
    --Update working set with Attribute_IDs   
    --Also update any DBA attribute values that were sent in as empty strings to NULL  
    ----------------------------------------------------------------------------------------  
  
    UPDATE ws SET       
           ws.Attribute_ID = att.Attribute_ID,  
           ws.AttributeValue =       CASE WHEN att.AttributeType_ID = @AttributeType_DBA THEN NULLIF(ws.AttributeValue, N'') ELSE ws.AttributeValue END,  
           ws.AttributeValueMapped = CASE WHEN att.AttributeType_ID = @AttributeType_DBA THEN NULLIF(ws.AttributeValue, N'') ELSE ws.AttributeValueMapped END  
    FROM #MemberAttributeWorkingSet AS ws    
    INNER JOIN #AttributeDefinition AS att   
        ON  ws.AttributeName = att.AttributeName;  
  
    --If any Attribute_IDs are null then the attribute name is invalid.  
    UPDATE ws SET       
           ErrorCode = @ErrorCode_InvalidAttribute,  
           ErrorObjectType = @ObjectType_MemberAttribute  
    FROM #MemberAttributeWorkingSet AS ws    
    WHERE ws.Attribute_ID IS NULL  
    AND ErrorCode IS NULL;  
  
    ----------------------------------------------------------------------------------------  
    --Get Member IDs  
    ----------------------------------------------------------------------------------------  
    SET @SQL = N'  
        UPDATE ws  
        SET Member_ID = m.ID, MemberName = m.Name  
        FROM mdm.' + @TableName + N' AS m  
        INNER JOIN #MemberAttributeWorkingSet AS ws  
            ON m.Version_ID = @Version_ID AND m.Code = ws.MemberCode  
        WHERE COALESCE(m.Status_ID,0) = 1;'; --WHERE includes only active members (e.g. does not include soft deleted members)  
    --PRINT(@SQL);  
    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;  
  
    -- Invalid member code check  
    UPDATE #MemberAttributeWorkingSet    
        SET ErrorCode = @ErrorCode_InvalidMemberCode,  
            ErrorObjectType = @ObjectType_MemberAttribute  
    WHERE Member_ID IS NULL  
  
    ----------------------------------------------------------------------------------------  
    --Check security  
    ----------------------------------------------------------------------------------------  
    --Check Object Permissions.  Mark any attributes the user doesn't have permission to.  
    EXEC mdm.udpSecurityLevelGet @User_ID, @Entity_ID, @SecurityLevel OUTPUT;  
  
    IF @SecurityLevel = @SecLvl_NoAccess BEGIN  
        UPDATE #MemberAttributeWorkingSet  
        SET ErrorCode = @ErrorCode_NoPermissionForThisOperationOnThisObject,  
            ErrorObjectType = @ObjectType_MemberCode;  
    END;  
  
    IF @SecurityLevel IN (@SecLvl_ObjectSecurity, @SecLvl_ObjectAndMemberSecurity) BEGIN  
      
        UPDATE ws  
        SET    
            ErrorCode =   
                CASE COALESCE(attsec.Privilege_ID, 0)  
                    WHEN @Permission_Update THEN ws.ErrorCode -- no change  
                    WHEN @Permission_ReadOnly THEN @ErrorCode_ReadOnlyAttribute  
                    WHEN @Permission_Inferred THEN @ErrorCode_ReadOnlyAttribute  
                    WHEN @Permission_Deny THEN @ErrorCode_InvalidAttribute  
                    WHEN @Permission_None THEN @ErrorCode_InvalidAttribute  
                END  
            ,ErrorObjectType =   
                CASE COALESCE(attsec.Privilege_ID, 0)  
                    WHEN @Permission_Update THEN ws.ErrorObjectType -- no change  
                    ELSE @ObjectType_MemberAttribute  
                END  
        FROM #MemberAttributeWorkingSet AS ws  
        LEFT OUTER JOIN mdm.udfAttributeList(@User_ID, @Entity_ID, @MemberType_ID, NULL, NULL) AS attsec   
            ON ws.Attribute_ID = attsec.ID  
    END  
      
    --Check Member Permissions.  Mark any members the user doesn't have permission to.  
    IF @SecurityLevel IN (@SecLvl_MemberSecurity, @SecLvl_ObjectAndMemberSecurity) BEGIN  
        INSERT INTO @MemberIds (ID, MemberType_ID)  
        SELECT  
            DISTINCT  
             ws.Member_ID  
            ,@MemberType_ID   
        FROM #MemberAttributeWorkingSet ws  
        WHERE Member_ID IS NOT NULL   
        AND ErrorCode IS NULL;  
  
        INSERT INTO @MemberPermissions  
        EXEC mdm.udpSecurityMembersResolverGet @User_ID, @Version_ID, @Entity_ID, @MemberIds  
  
        UPDATE ws  
        SET ErrorCode = @ErrorCode_NoPermissionForThisOperationOnThisObject,  
            ErrorObjectType = @ObjectType_MemberCode  
        FROM #MemberAttributeWorkingSet ws  
         
        INNER JOIN @MemberPermissions prm  
            ON ws.Member_ID = prm.ID  
            AND prm.Privilege_ID <> @Permission_Update;  
    END  
  
    --Exit now if we have no members to update because user doesn't have necessary security or  
    --user doesn't have necessary permission to any attribute or all attributes are invalid.  
    IF ((SELECT COUNT(*) FROM #MemberAttributeWorkingSet WHERE ErrorCode IS NULL) = 0) OR  
       ((SELECT COUNT(*) FROM #MemberAttributeWorkingSet WHERE Attribute_ID IS NOT NULL) = 0) OR  
       ((SELECT COUNT(*) FROM #MemberAttributeWorkingSet WHERE Member_ID IS NOT NULL) = 0)  
    BEGIN  
        SELECT DISTINCT   
             ws.Member_ID  
            ,ws.MemberCode  
            ,ws.MemberName  
            ,ad.Attribute_MUID  
            ,ws.AttributeName  
            ,ws.ErrorCode  
            ,ws.ErrorObjectType  
        FROM #MemberAttributeWorkingSet ws  
        LEFT OUTER JOIN #AttributeDefinition ad  
            ON ws.Attribute_ID = ad.Attribute_ID  
        WHERE ErrorCode IS NOT NULL  
        RETURN(0);  
    END  
  
    IF EXISTS(SELECT 1 FROM #AttributeDefinition WHERE Dba_Entity_ID > 0)  
        SELECT @HasDba = 1  
    ELSE  
        SELECT @HasDba = 0; -- Can skip DBA processing  
          
    IF EXISTS(SELECT 1 FROM #AttributeDefinition WHERE AttributeType_ID = @AttributeType_File)  
        SELECT @HasFile = 1  
    ELSE  
        SELECT @HasFile = 0 -- No file attributes to update  
          
    ----------------------------------------------------------------------------------------  
    --Set column name strings.  
    ----------------------------------------------------------------------------------------  
    SELECT @TableColumns += ',' + Quotename(AttributeName) FROM #AttributeDefinition ORDER BY Attribute_ID;  
    SELECT @TableColumns = RIGHT(@TableColumns, LEN(@TableColumns)-1) -- remove leading comma;  
    SELECT @TableColumnsPivotDefn +=  N',' + TableColumnPivotDefn FROM #AttributeDefinition ORDER BY Attribute_ID;  
    SELECT @TableColumnsUnPivotDefn +=  N',' + TableColumnUnPivotDefn FROM #AttributeDefinition ORDER BY Attribute_ID;  
    SELECT @TableColumnsUpdateDefn +=  N',' + TableColumnUpdateDefn FROM #AttributeDefinition ORDER BY Attribute_ID;  
    If @HasDba = 1 BEGIN  
        SELECT @TableColumnsDba += ',' + Quotename(AttributeName) FROM #AttributeDefinition WHERE Dba_Entity_ID > 0 ORDER BY Attribute_ID;  
        SELECT @TableColumnsDba = RIGHT(@TableColumnsDba, LEN(@TableColumnsDba)-1) -- remove leading comma;  
        SELECT @TableColumnsUpdateDbaIdsDefn += N' UNION ' + TableColumnUpdateDbaIdsDefn FROM #AttributeDefinition WHERE Dba_Entity_ID > 0 ORDER BY Attribute_ID;  
        SELECT @TableColumnsUpdateDbaIdsDefn = RIGHT(@TableColumnsUpdateDbaIdsDefn, LEN(@TableColumnsUpdateDbaIdsDefn)-7) -- remove leading comma;  
        SELECT @TableColumnsUnPivotDbaDefn +=  N',' + TableColumnUnPivotDbaDefn FROM #AttributeDefinition WHERE Dba_Entity_ID > 0 ORDER BY Attribute_ID;  
    END  
    IF @HasFile = 1 BEGIN  
        SELECT @TableColumnsFile += N',' + Quotename(AttributeName) FROM #AttributeDefinition WHERE AttributeType_ID = @AttributeType_File ORDER BY Attribute_ID;  
        SELECT @TableColumnsFile = RIGHT(@TableColumnsFile, LEN(@TableColumnsFile)-1) -- remove leading comma;  
        SELECT @TableColumnsUnPivotFileDefn +=  N',' + TableColumnUnPivotFileDefn FROM #AttributeDefinition WHERE AttributeType_ID = @AttributeType_File ORDER BY Attribute_ID;  
    END  
  
    --Debug  
    --SELECT @TableColumns AS TableColumns;  
    --SELECT @TableColumnsPivotDefn AS TableColumnsPivotDefn;  
    --SELECT @TableColumnsUnPivotDefn AS TableColumnsUnPivotDefn;   
    --SELECT @TableColumnsUnPivotDbaDefn AS TableColumnsUnPivotDbaDefn;   
    --SELECT @TableColumnsUpdateDefn AS TableColumnsUpdateDefn;  
    --SELECT @TableColumnsUpdateDbaIdsDefn AS TableColumnUpdateDbaIdsDefn;  
    --SELECT * FROM #AttributeDefinition;  
    --SELECT * FROM #MemberAttributeWorkingSet;  
      
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
        BEGIN TRY  
        ----------------------------------------------------------------------------------------  
        -- Validate working set.  
        ----------------------------------------------------------------------------------------  
        --Flag FreeForm and Link attributes where the value length doesn't exceeds the maximum length allowed.  
        UPDATE ws SET       
               ErrorCode = @ErrorCode_AttributeValueLengthGreaterThanMaximum,  
               ErrorObjectType = @ObjectType_MemberAttribute  
        FROM #MemberAttributeWorkingSet AS ws    
        INNER JOIN #AttributeDefinition AS att   
            ON  ws.Attribute_ID = att.Attribute_ID  
            AND att.AttributeType_ID = @AttributeType_FreeForm  
            AND att.DataType_ID IN (@AttributeDataType_Text, @AttributeDataType_Link)   
            AND LEN(ws.AttributeValue) > att.DataTypeInformation  
            AND ErrorCode IS NULL;  
  
        --Flag attributes with incorrect numeric types        
        UPDATE ws SET       
               ErrorCode = CASE mdq.IsNumber(ws.AttributeValue) WHEN 0 THEN   
                @ErrorCode_InvalidAttributeValueForDataType ELSE -- 'Error - The AttributeValue must be a number.'  
                @ErrorCode_InvalidAttributeValueForMember END,  -- 'Error - The AttributeValue is too long.'  
               ErrorObjectType = @ObjectType_MemberAttribute  
        FROM #MemberAttributeWorkingSet AS ws    
        INNER JOIN #AttributeDefinition AS att   
            ON  ws.Attribute_ID = att.Attribute_ID  
            AND att.AttributeType_ID = @AttributeType_FreeForm  
            AND att.DataType_ID = @AttributeDataType_Number   
            AND ws.AttributeValue IS NOT NULL  
            AND CASE -- using a CASE statement here ensures Boolean short-circuiting. If the value isn't numeric then trying to convert it to float will crash  
                WHEN mdq.IsNumber(ws.AttributeValue) <> 1 THEN 1  
                WHEN mdq.IsNumber(STR(CONVERT(FLOAT, ws.AttributeValue), 38, att.DataTypeInformation)) <> 1 THEN 1  
                ELSE 0 END = 1  
            AND ErrorCode IS NULL;  
  
        -- Numeric data types in scientific notation format cannot be directly converted to type   
        -- DECIMAL, so convert them to fixed-point notation.  
        UPDATE ws SET       
            AttributeValueMapped =   
            -- the CASE condition is redundant with part of the JOIN clause, but it is necessary because even when false the query will still  
            -- sometimes evaluate the right-hand side of this assignment, which can cause a "failure to convert NVARCHAR to float" error.  
                CASE COALESCE(ws.ErrorCode, N'')  
                    WHEN N'' THEN STR(CONVERT(FLOAT, ws.AttributeValue), 38, att.DataTypeInformation)   
                    ELSE  ws.AttributeValue  
                END    
        FROM #MemberAttributeWorkingSet AS ws    
        INNER JOIN #AttributeDefinition AS att   
            ON  ws.Attribute_ID = att.Attribute_ID  
            AND (att.DataType_ID = @AttributeDataType_Number)   
            AND CHARINDEX(N'E', UPPER(ws.AttributeValue)) > 0     -- CHARINDEX uses 1-based indexing        
            AND AttributeValue IS NOT NULL  
            AND ErrorCode IS NULL;  
  
  
          
        --Flag attributes with incorrect date type    
        --@DataType_ID = 3 BEGIN --DATETIME    
        UPDATE ws   
            SET ErrorCode = @ErrorCode_InvalidAttributeValueForDataType,  
               ErrorObjectType = @ObjectType_MemberAttribute  
        FROM #MemberAttributeWorkingSet AS ws    
        INNER JOIN #AttributeDefinition AS att  
        ON att.Attribute_ID = ws.Attribute_ID   
        AND att.DataType_ID = @AttributeDataType_DateTime  
        AND LEN(COALESCE(ws.AttributeValue, N'')) > 0   
        AND mdq.IsDateTime2(ws.AttributeValue) = 0  
        AND ws.ErrorCode IS NULL;   
  
        --Flag attributes with incorrect links    
        --@DataType_ID = AttributeDataType_Link BEGIN --Link    
        UPDATE ws   
            SET ErrorCode = @ErrorCode_InvalidAttributeValueForDataType,  
               ErrorObjectType = @ObjectType_MemberAttribute  
        FROM #MemberAttributeWorkingSet AS ws    
        INNER JOIN #AttributeDefinition AS att  
        ON att.Attribute_ID = ws.Attribute_ID   
        AND att.DataType_ID = @AttributeDataType_Link  
        AND att.AttributeType_ID = @AttributeType_FreeForm  
        AND LEN(COALESCE(ws.AttributeValue, N'')) > 0   
        AND mdq.IsLink(ws.AttributeValue) = 0  
        AND ws.ErrorCode IS NULL;   
  
        --Get Dba Ids  
        IF @HasDba = 1 BEGIN  
          
            DECLARE @DbaTempTable TABLE (  
                 RowNumber INT IDENTITY (1, 1) PRIMARY KEY CLUSTERED NOT NULL   
                ,Dba_Entity_ID INT NOT NULL  
            );  
  
            SET @SQL = N'  
                UPDATE ws  
                SET ws.AttributeValueMapped = dba.ID  
                FROM #MemberAttributeWorkingSet ws  
                INNER JOIN #AttributeDefinition AS att  
                    ON ws.Attribute_ID = att.Attribute_ID  
                    AND att.Dba_Entity_ID > 0   
                LEFT OUTER JOIN (' + @TableColumnsUpdateDbaIdsDefn + N') dba  
                ON ws.AttributeValue = dba.Code   
                AND ws.Attribute_ID = dba.Attribute_ID  
                AND ws.ErrorCode IS NULL;  
            ';              
            EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;  
  
            --Flag any invalid Dba values  
            UPDATE ws  
            SET ws.ErrorCode = @ErrorCode_InvalidAttributeValueForMember,  
                ws.ErrorObjectType = @ObjectType_MemberAttribute  
            FROM #MemberAttributeWorkingSet ws  
            WHERE ws.AttributeValue IS NOT NULL  
            AND ws.AttributeValueMapped IS NULL  
            AND ws.ErrorCode IS NULL;  
  
        --Check DBA Member Permissions.  Mark any members the user doesn't have permission to.  
          
            IF @SecurityLevel IN (@SecLvl_MemberSecurity, @SecLvl_ObjectAndMemberSecurity) BEGIN  
                --Get the distinct list of Dba Entities.  
                INSERT INTO @DbaTempTable  
                    SELECT DISTINCT att.Dba_Entity_ID  
                FROM #MemberAttributeWorkingSet ws  
                INNER JOIN #AttributeDefinition att  
                    ON att.Attribute_ID = ws.Attribute_ID  
                    AND att.Dba_Entity_ID > 0  
                WHERE Member_ID IS NOT NULL   
                AND ErrorCode IS NULL;  
                  
                DECLARE @DbaEntityID INT;  
                SELECT  
                     @Counter = 1  
                    ,@MaxCounter = MAX(RowNumber)   
                FROM @DbaTempTable;  
                      
                DELETE FROM @MemberPermissions;  
                  
                --Loop through each Dba Entity checking the user's permissions to the Dba members.  
                WHILE @Counter <= @MaxCounter  
                BEGIN  
                    SELECT @DbaEntityID = Dba_Entity_ID FROM @DbaTempTable WHERE [RowNumber] = @Counter ;  
  
                    --Check DBA Member Permissions.  Mark any members the user doesn't have permission to.  
                    EXEC mdm.udpSecurityLevelGet @User_ID, @DbaEntityID, @DbaSecurityLevel OUTPUT;  
                    IF @DbaSecurityLevel IN (@SecLvl_MemberSecurity, @SecLvl_ObjectAndMemberSecurity) BEGIN  
  
                        DELETE FROM @MemberIds;  
  
                        INSERT INTO @MemberIds (ID, MemberType_ID)  
                        SELECT  
                             ws.AttributeValueMapped --Contains the Dba Member ID.  
                            ,@MemberType_ID   
                        FROM #MemberAttributeWorkingSet ws  
                        INNER JOIN #AttributeDefinition att  
                            ON att.Attribute_ID = ws.Attribute_ID  
                            AND att.Dba_Entity_ID = @DbaEntityID  
                        WHERE Member_ID IS NOT NULL   
                        AND ErrorCode IS NULL;  
  
                        --Get member permissions  
                        INSERT INTO @MemberPermissions  
                        EXEC mdm.udpSecurityMembersResolverGet @User_ID, @Version_ID, @DbaEntityID, @MemberIds  
  
                        --Mark any member attribute values that don't have permissions  
                        UPDATE ws  
                        SET ErrorCode = @ErrorCode_NoPermissionForThisOperationOnThisObject,  
                            ErrorObjectType = @ObjectType_MemberCode  
                        FROM #MemberAttributeWorkingSet ws  
                        INNER JOIN #AttributeDefinition att  
                            ON att.Dba_Entity_ID = @DbaEntityID  
                            AND att.Attribute_ID = ws.Attribute_ID  
                        INNER JOIN @MemberPermissions prm  
                            ON ws.AttributeValueMapped = CONVERT(NVARCHAR, prm.ID) -- Convert to NVARCHAR avoids potential errors from the AttributeValueMapped column being implicitly converted to INT  
                            AND prm.Privilege_ID NOT IN (@Permission_Update, @Permission_ReadOnly, @Permission_Inferred);  
                    END;  
                                              
                    SET @Counter += 1;  
                END    ;  
            END;                  
        END;  
          
        --Check for any attribute value changes for the Code attribute.  Requires special handling.  
        IF EXISTS(SELECT 1 FROM #MemberAttributeWorkingSet WHERE AttributeName = N'Code') BEGIN  
              
            --Check for empty Codes  
            UPDATE #MemberAttributeWorkingSet  
             SET ErrorCode = @ErrorCode_InvalidBlankMemberCode,  
                    ErrorObjectType = @ObjectType_MemberAttribute  
            WHERE AttributeName = N'Code'  
            AND (AttributeValue IS NULL OR AttributeValue = N'');  
  
            --Check for reserved words in the MemberCode.      
            UPDATE #MemberAttributeWorkingSet  
            SET    ErrorCode = @ErrorCode_ReservedWord,  
                ErrorObjectType = @ObjectType_MemberAttribute   
            WHERE AttributeName = N'Code'  
            AND mdm.udfItemReservedWordCheck(12, AttributeValue) = 1   
            AND ErrorCode IS NULL;  
              
            WITH rawWithCount AS  
            (  
                SELECT  
                    ROW_NUMBER() OVER (PARTITION BY AttributeValue ORDER BY Row_ID) AS RN,  
                    Row_ID  
                FROM #MemberAttributeWorkingSet ws  
                WHERE ws.AttributeName = N'Code'  
            ),  
            duplicateCodeValues AS  
            (  
                SELECT Row_ID FROM rawWithCount WHERE RN > 1  
            )  
            UPDATE ws SET  
               ErrorCode = @ErrorCode_MemberCodeExists,  
               ErrorObjectType = @ObjectType_MemberAttribute   
            FROM #MemberAttributeWorkingSet AS ws  
            INNER JOIN duplicateCodeValues AS dup  
                ON ws.Row_ID = dup.Row_ID;  
  
            --Check for existing MemberCodes.  
            SELECT   
                 @ErrorCode = @ErrorCode_MemberCodeExists  
                ,@ErrorObjectType = @ObjectType_MemberAttribute;  
              
            IF @IsFlat = 1 BEGIN  
                SET @SQL = N'  
                    UPDATE ws  
                    SET    ErrorCode = CASE m.Status_ID WHEN 1 /*Active*/ THEN @ErrorCode_MemberCodeExists ELSE @ErrorCode_DeactivatedMemberCodeExists END,  
                        ErrorObjectType = @ErrorObjectType  
                    FROM #MemberAttributeWorkingSet AS ws  
                    INNER JOIN  mdm.' + @EntityTable + N' AS m  
                    ON      ws.AttributeValue = m.Code  
                        AND ws.AttributeName = N''Code''  
                        AND m.Version_ID = @Version_ID  
                        AND ws.ErrorCode IS NULL;  
                ';  
                EXEC sp_executesql @SQL, N'@Version_ID INT,@ErrorCode_MemberCodeExists INT, @ErrorCode_DeactivatedMemberCodeExists INT, @ErrorObjectType INT',   
                @Version_ID, @ErrorCode_MemberCodeExists, @ErrorCode_DeactivatedMemberCodeExists, @ErrorObjectType;  
            END  
            ELSE BEGIN  
                SET @SQL = N'  
                    UPDATE ws  
                    SET    ErrorCode = CASE existingCodes.Status_ID WHEN 1 /*Active*/ THEN @ErrorCode_MemberCodeExists ELSE @ErrorCode_DeactivatedMemberCodeExists END,   
                        ErrorObjectType = @ErrorObjectType  
                    FROM #MemberAttributeWorkingSet AS ws  
                    INNER JOIN (  
                        SELECT Code, Status_ID FROM mdm.' + @EntityTable + N' WHERE Version_ID = @Version_ID  
                        UNION  
                        SELECT Code, Status_ID FROM mdm.' + @HierarchyParentTable + N' WHERE Version_ID = @Version_ID  
                        UNION  
                        SELECT Code, Status_ID FROM mdm.' + @CollectionTable + N'  WHERE Version_ID = @Version_ID  
                    ) AS existingCodes  
                    ON      ws.AttributeValue = existingCodes.Code  
                        AND ws.AttributeName = N''Code''  
                        AND ws.ErrorCode IS NULL;  
                ';  
                EXEC sp_executesql @SQL, N'@Version_ID INT, @ErrorCode_MemberCodeExists INT, @ErrorCode_DeactivatedMemberCodeExists INT, @ErrorObjectType INT',   
                @Version_ID, @ErrorCode_MemberCodeExists, @ErrorCode_DeactivatedMemberCodeExists, @ErrorObjectType;  
            END  
  
            --Update any existing validation issues associated with this member  
            --to ensure they reference the new member code.  
            UPDATE mdm.tblValidationLog  
            SET MemberCode = AttributeValue  
            FROM #MemberAttributeWorkingSet AS ws  
            INNER JOIN mdm.tblValidationLog AS v  
                ON v.Member_ID = ws.Member_ID  
                AND ws.Member_ID IS NOT NULL  
                AND ws.AttributeName = N'Code'  
                AND v.MemberType_ID = @MemberType_ID  
                AND v.Version_ID = @Version_ID  
                AND ws.ErrorCode IS NULL;  
  
            --If the entity is code gen enabled we will need to process updated code values  
            IF @CodeGenEnabled = 1  
                BEGIN  
                    --Gather up the valid user provided codes  
                    DECLARE @CodesToProcess mdm.MemberCodes;  
  
                    INSERT @CodesToProcess (MemberCode)   
                    SELECT AttributeValue  
                    FROM #MemberAttributeWorkingSet  
                    WHERE ErrorCode IS NULL AND AttributeName = N'Code';  
  
                    --Process the user-provided codes to update the code gen info table with the largest one  
                    EXEC mdm.udpProcessCodes @Entity_ID, @CodesToProcess;  
                END  
  
        END; --Code special handling  
  
        --Map any NULL attribute values to the special value.  
        UPDATE ws  
        SET AttributeValueMapped = m.SysNullValue  
        FROM #MemberAttributeWorkingSet AS ws    
        INNER JOIN #AttributeDefinition AS att   
            ON  ws.Attribute_ID = att.Attribute_ID  
            AND ws.AttributeValue IS NULL  
        INNER JOIN @SysNullDataTypeMap m  
            ON att.AttributeType_ID = m.AtributeType_ID  
            AND att.DataType_ID = m.DataType_ID  
  
        ----------------------------------------------------------------------------------------  
        --Get current attribute values prior to update  
        ----------------------------------------------------------------------------------------  
        IF @IgnorePriorValues = 0  
        BEGIN  
            SELECT @SQL = N'  
            WITH cte AS (                  
                SELECT  
                    ID ' +  
                    @TableColumnsUnPivotDefn +  
            N'    FROM mdm.' + @ViewName + N' AS m  
                WHERE m.Version_ID = @Version_ID  
                AND m.ID IN (SELECT DISTINCT ws.Member_ID FROM #MemberAttributeWorkingSet AS ws WHERE ws.ErrorCode IS NULL)  
            )  
            UPDATE ws  
            SET PriorValue = priorPivot.AttributeValue,  
                PriorValueMapped = priorPivot.AttributeValue  
            FROM #MemberAttributeWorkingSet AS ws  
            INNER JOIN (  
                select ID, U.AttributeName, U.AttributeValue  
                FROM cte    
                UNPIVOT  
                (AttributeValue FOR AttributeName IN (' + @TableColumns + N'))    AS U  
                ) priorPivot  
            ON ws.Member_ID = priorPivot.ID  
            AND ws.AttributeName = priorPivot.AttributeName;  
            ';  
          
            --Get prior Dba Ids  
            IF @HasDba = 1 BEGIN  
                SELECT @SQL += N'  
                    WITH cte AS (                  
                        SELECT  
                            ID ' +  
                            @TableColumnsUnPivotDbaDefn +   
                    '    FROM mdm.' + @ViewName + N' AS e  
                        WHERE e.Version_ID = @Version_ID  
                        AND e.ID IN (SELECT DISTINCT ws.Member_ID FROM #MemberAttributeWorkingSet AS ws WHERE ws.ErrorCode IS NULL)  
                    )  
                    UPDATE ws  
                    SET PriorValueMapped = priorPivot.AttributeValue  
                    FROM #MemberAttributeWorkingSet AS ws  
                    INNER JOIN #AttributeDefinition AS ad  
                        ON ws.Attribute_ID = ad.Attribute_ID  
                    INNER JOIN (  
                        select ID, U.AttributeName, U.AttributeValue  
                        FROM cte    
                        UNPIVOT  
                        (AttributeValue FOR AttributeName IN (' + @TableColumnsDba + N')) AS U  
                        ) priorPivot  
                    ON ws.Member_ID = priorPivot.ID  
                    AND ws.AttributeName = priorPivot.AttributeName;  
            ';  
            END;  
  
            --Get prior File Ids  
            IF @HasFile = 1 BEGIN  
                SELECT @SQL += N'  
                    WITH cte AS (                  
                        SELECT  
                            ID ' +  
                            @TableColumnsUnPivotFileDefn +   
                    '    FROM mdm.' + @ViewName + N' AS e  
                        WHERE e.Version_ID = @Version_ID  
                        AND e.ID IN (SELECT DISTINCT ws.Member_ID FROM #MemberAttributeWorkingSet AS ws WHERE ws.ErrorCode IS NULL)  
                    )  
                    UPDATE ws  
                    SET PriorFileId = priorPivot.AttributeValue  
                    FROM #MemberAttributeWorkingSet AS ws  
                    INNER JOIN #AttributeDefinition AS ad  
                        ON ws.Attribute_ID = ad.Attribute_ID  
                    INNER JOIN (  
                        select ID, U.AttributeName, U.AttributeValue  
                        FROM cte    
                        UNPIVOT  
                        (AttributeValue FOR AttributeName IN (' + @TableColumnsFile + N')) AS U  
                        ) priorPivot  
                    ON ws.Member_ID = priorPivot.ID  
                    AND ws.AttributeName = priorPivot.AttributeName;  
            ';  
            END;  
  
            --PRINT(@SQL);  
            EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;  
        END  
  
        UPDATE ws  
        SET          
            IsChanged = CASE WHEN   
                    @IgnorePriorValues = 0 -- If prior values were not looked up, then assume the value has changed.  
                AND COALESCE(NULLIF(AttributeValue, PriorValue),  NULLIF(PriorValue, AttributeValue)) IS NULL THEN 0 ELSE 1 END,    
            ChangeTrackingMask =   
                CASE WHEN COALESCE( NULLIF(AttributeValue, PriorValue),  NULLIF(PriorValue, AttributeValue)) IS NULL THEN 0   
                ELSE COALESCE(ws.ChangeTrackingMask, 0) | COALESCE(POWER(2,ad.ChangeTrackingGroup_ID - 1), 0)   
            END      
        FROM #MemberAttributeWorkingSet AS ws  
        INNER JOIN #AttributeDefinition AS ad  
            ON ws.Attribute_ID = ad.Attribute_ID;  
  
        ----------------------------------------------------------------------------------------  
        --Pivot and update entity member table  
        ----------------------------------------------------------------------------------------  
        -- ctePivot  
        -- Given this input:  
        --  MemberID        AttributeName    AttributeValueMapped  
        --  --------        -------------   --------------------  
        --  1000            Attribute1        ABC  
        --    1000            Attribute2        1111  
        --    1000            Attribute3        Foo  
  
        --  Pivots to this:  
        --  MemberID        Attribute1      Attribute2      Attribute3  
        --  --------        ----------      ----------      ----------  
        --    1000            ABC                NULL            NULL  
        --    1000            NULL            1111            NULL  
        --    1000            NULL            NULL            Foo  
  
  
        -- ctePivotRowMerge  
        -- Merge the multiple member records INTo one record  
        --  MemberID        Attribute1      Attribute2      Attribute3  
        --  --------        ----------      ----------      ----------  
        --    1000            ABC                1111            Foo  
  
        SELECT @SQL = N'  
        WITH ctePivot AS (      
            SELECT Member_ID, ChangeTrackingMask, ' + @TableColumns + N' FROM #MemberAttributeWorkingSet   
            PIVOT  
            (  
                MAX(AttributeValueMapped)  
                FOR AttributeName IN (' + @TableColumns + N')  
            ) AS P  
            WHERE (ErrorCode IS NULL AND IsChanged = 1)  
        ),  
        ctePivotRowMerge AS (  
            SELECT   
                 Member_ID  
                 ,SUM(DISTINCT ChangeTrackingMask) ChangeTrackingMask ' +  
                 @TableColumnsPivotDefn +  
        N'    FROM ctePivot  
            GROUP BY Member_ID  
        ) '  
  
        SELECT @SQL += N'UPDATE m   
            SET  
                 ValidationStatus_ID    = @ValidationStatus  
                ,LastChgDTM             = @CurrentTime  
                ,LastChgUserID          = @User_ID  
                ,LastChgVersionID       = @Version_ID'  
              --Update the ChangeTrackingMask only for Leaf and Consolidated   
              --member types (collections do not support this functionality)  
              + CASE WHEN @MemberType_ID IN (1,2) THEN N'  
                ,m.ChangeTrackingMask = COALESCE(m.ChangeTrackingMask, 0) | updates.ChangeTrackingMask ' ELSE N'' END  
  
               + @TableColumnsUpdateDefn +  
         N' FROM mdm.' + @TableName + N' AS m  
           INNER JOIN ctePivotRowMerge updates  
                ON m.ID = updates.Member_ID  
              AND m.Version_ID = @Version_ID; '  
  
        --SELECT(@SQL);  
        SET @ValidationStatus = @ValidationStatus_AwaitingRevalidation;  
          
        EXEC sp_executesql @SQL, N'@Version_ID INT, @ValidationStatus INT, @CurrentTime DATETIME2(3), @User_ID INT, @SysNull_Text NVARCHAR(50), @SysNull_Number INT, @SysNull_DateTime DATETIME2(3)',   
            @Version_ID, @ValidationStatus, @CurrentTime, @User_ID, @SysNull_Text, @SysNull_Number, @SysNull_DateTime;  
  
    ----------------------------------------------------------------------------------------  
    --Add transactions for attribute values that changed.  
    ----------------------------------------------------------------------------------------  
  
     INSERT INTO mdm.tblTransaction   
    (  
        Version_ID,  
        TransactionType_ID,  
        OriginalTransaction_ID,  
        Entity_ID,  
        Attribute_ID,  
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
        @Version_ID AS Version_ID  
        ,@TransactionType_Update AS TransactionType_ID  -- Attribute value change   
        ,0 AS OriginalTransaction_ID  
        ,@Entity_ID AS Entity_ID  
        ,ws.Attribute_ID  
        ,ws.Member_ID  
        ,@MemberType_ID AS MemberType_ID  
        ,ws.MemberCode  
        ,ws.PriorValueMapped  
        ,ws.PriorValue  
        ,ws.AttributeValueMapped  
        ,ws.AttributeValue  
        ,@CurrentTime  
        ,@User_ID  
        ,@CurrentTime  
        ,@User_ID   
    FROM #MemberAttributeWorkingSet AS ws  
    WHERE ws.ErrorCode IS NULL  
    AND ws.IsChanged = 1;  
  
    ----------------------------------------------------------------------------------------  
    --Add any annotation comments that came in with the update  
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
        Transactions.ID  
        ,ws.TransactionAnnotation  
        ,Transactions.EnterUserID  
        ,Transactions.EnterDTM  
        ,Transactions.LastChgDTM  
        ,Transactions.LastChgUserID  
    FROM #MemberAttributeWorkingSet AS ws  
    LEFT JOIN mdm.tblTransaction AS Transactions  
        ON ws.Attribute_ID = Transactions.Attribute_ID  
        AND ws.Member_ID = Transactions.Member_ID  
    WHERE Transactions.Version_ID = @Version_ID  
        AND Transactions.Entity_ID = @Entity_ID  
        AND Transactions.MemberType_ID = @MemberType_ID  
        AND Transactions.EnterUserID = @User_ID  
        AND Transactions.EnterDTM = @CurrentTime  
        AND Transactions.TransactionType_ID = @TransactionType_Update  
        AND ws.TransactionAnnotation IS NOT NULL  
  
    ----------------------------------------------------------------------------------------  
    --Check for Inheritance Business Rules and update dependent members validation status.  
    ----------------------------------------------------------------------------------------  
        IF @DoInheritanceRuleCheck = 1 BEGIN  
            DECLARE @BRInherit AS TABLE (  
                 RowNumber INT IDENTITY(1,1) NOT NULL  
                ,DependentAttributeColumnName sysname NOT NULL  
                ,DependentEntityTable sysname NULL  
                ,DependentAttributeName sysname NULL  
            );  
  
            --DBA Inheritance  
            INSERT INTO @BRInherit (DependentEntityTable, DependentAttributeColumnName)  
            SELECT DISTINCT  
                 depEnt.EntityTable  
                ,i.ChildAttributeColumnName  
            FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY i  
            INNER JOIN #MemberAttributeWorkingSet ws  
                ON ws.AttributeName = i.ParentAttributeName  
                AND i.ParentEntityID = @Entity_ID  
            INNER JOIN mdm.tblEntity AS depEnt  
                ON i.ChildEntityID = depEnt.ID;  
  
            IF EXISTS(SELECT 1 FROM @BRInherit) BEGIN  
                SELECT  
                     @ValidationStatus = @ValidationStatus_AwaitingDependentMemberRevalidation  
                    ,@Counter = 1  
                    ,@MaxCounter = MAX(RowNumber)   
                FROM @BRInherit;  
                  
                --Loop through each Dba Entity updating the dependent members' validation status.  
                WHILE @Counter <= @MaxCounter  
                BEGIN  
                    SELECT   
                         @DependentEntityTable = DependentEntityTable  
                        ,@DependentAttributeColumnName = DependentAttributeColumnName  
                     FROM @BRInherit WHERE [RowNumber] = @Counter ;  
  
                    --Update immediate dependent member table's validation status.  
                    SELECT @SQL = N'  
                        UPDATE   dep  
                        SET dep.ValidationStatus_ID = @ValidationStatus  
                        FROM  mdm.' + @DependentEntityTable + N' AS dep  
                        INNER JOIN #MemberAttributeWorkingSet AS ws  
                            ON dep.' + @DependentAttributeColumnName + N' = ws.Member_ID  
                            AND dep.Version_ID = @Version_ID  
                            AND dep.ValidationStatus_ID <> @ValidationStatus  
                            AND ws.ErrorCode IS NULL  
                            AND ws.IsChanged = 1;  
                        ';  
  
                    --PRINT @SQL;  
                    EXEC sp_executesql @SQL, N'@Version_ID INT, @ValidationStatus INT', @Version_ID, @ValidationStatus;  
                      
                    SET @Counter += 1;  
  
                END; -- WHILE  
            END -- IF @DependentEntityTable  
  
            --Hierarchy Inheritance.    
            --  Only need to do this if a hierarchy parent attribute is being updated.  
            IF @MemberType_ID = @MemberType_Consolidated BEGIN  
                DELETE FROM @BRInherit;  
                  
                INSERT INTO @BRInherit (DependentAttributeColumnName, DependentAttributeName)  
                SELECT DISTINCT  
                     i.AttributeColumnName  
                    ,i.AttributeName  
                FROM mdm.viw_SYSTEM_BUSINESSRULES_HIERARCHY_CHANGEVALUE_INHERITANCE i  
                INNER JOIN #MemberAttributeWorkingSet ws  
                    ON ws.AttributeName = i.AttributeName  
                    AND  i.EntityID = @Entity_ID  
                    AND ws.ErrorCode IS NULL  
                    AND ws.IsChanged = 1;  
                  
                IF EXISTS(SELECT 1 FROM @BRInherit) BEGIN  
                    SELECT  
                         @Counter = 1  
                        ,@MaxCounter = MAX(RowNumber)   
                    FROM @BRInherit;  
                      
                    --Loop through each dependent attribute updating hierarchy members' validation status.  
                    WHILE @Counter <= @MaxCounter  
                    BEGIN  
                        SELECT   
                             @DependentAttributeName = DependentAttributeName  
                         FROM @BRInherit WHERE [RowNumber] = @Counter ;  
                      
                        DECLARE @parentIdList mdm.IdList;  
  
                        INSERT INTO @parentIdList (ID)   
                        SELECT Member_ID  
                        FROM #MemberAttributeWorkingSet ws  
                        WHERE ws.AttributeName = @DependentAttributeName  
                        AND ws.ErrorCode IS NULL  
                        AND ws.IsChanged = 1  
  
                        EXEC mdm.udpHierarchyMembersValidationStatusUpdate  
                             @Entity_ID = @Entity_ID  
                            ,@Version_ID = @Version_ID  
                            ,@Hierarchy_ID = NULL  
                            ,@ParentIdList = @parentIdList  
                            ,@ValidationStatus_ID = @ValidationStatus_AwaitingDependentMemberRevalidation  
                            ,@MaxLevel = 0  
                            ,@IncludeParent = 0;  
  
                        SET @Counter += 1;  
  
                    END; -- WHILE  
                END;  -- IF EXISTS  
            END; -- IF @MemberType_ID = Consolidated  
        END --IF @DoInheritanceRuleCheck  
              
        ----------------------------------------------------------------------------------------  
        -- File Type attribute  
        -- Remove old record from mdm.tblFile for updates since the new record is being inserted  
        -- in Business Logic Save.  
        ----------------------------------------------------------------------------------------  
        IF @HasFile = 1 BEGIN  
            DELETE f  
            FROM mdm.tblFile AS f  
            INNER JOIN #MemberAttributeWorkingSet ws  
                ON ws.PriorFileId = f.ID  
                AND ws.ErrorCode IS NULL  
                AND ws.IsChanged = 1  
            INNER JOIN #AttributeDefinition ad  
                ON ad.AttributeType_ID = @AttributeType_File  
                AND ad.Attribute_ID = ws.Attribute_ID;  
        END  
  
        ----------------------------------------------------------------------------------------  
        --Member Recursive Derived Hierarchy Circular Check  
        ----------------------------------------------------------------------------------------  
        --An example of a recursive derived hierarchy is an Employee --> Manager relationship, where Manager is a DBA based on the  
        --Employee entity.  There may be multiple derived hierarchies that contain the recursive relationship in them however anyone   
        --of them will do.  Only the recursive portion of the hierarchy needs to be checked.  That portion of the hierarchy is   
        --obtained by filtering the PARENTCHILD_DERIVED view by the @Entity_ID parameter.  
        --    
        --We call the [udpCircularReferenceMemberCodesGet] SPROC to figure out whether the member codes being updated are  
        --part of a circular reference after the update. If that is the case, this transaction will eventually be rolled back. The  
        --reason we can't do this before the transaction is processed is because there is no way to reliably predict whether the  
        --updates the user is putting through will result in a circular reference. Also note that at this time we only do  
        --this check for the member codes being updated, NOT the whole hierarchy. While we could do that, the operation would be  
        --too expensive to perform on every update.  
          
        --Determine if a recursive derived hierarchy is in play.  There may be multiple but just grab the first one.  
  
        SELECT TOP 1  
             @RecursiveHierarchy_ID  = d.DerivedHierarchy_ID  
            ,@RecursiveHierarchyAttribute_ID = att.Attribute_ID  
        FROM mdm.tblDerivedHierarchyDetail d  
        INNER JOIN #AttributeDefinition att  
            ON att.Dba_Entity_ID = @Entity_ID  
            AND att.Attribute_ID = d.Foreign_ID  
            AND d.ForeignParent_ID = att.Dba_Entity_ID  
  
        IF @RecursiveHierarchy_ID > 0 BEGIN  
            --There is a recursive derived hierarchy in play therefore we need to check the DBA values for circular references.  
              
            --Lookup the derived hierarchy view.  
            SET @ParentChildDerivedView = N'viw_SYSTEM_' + CAST(@Model_ID AS NVARCHAR(30)) + N'_' + CAST(@RecursiveHierarchy_ID AS NVARCHAR(30)) + N'_PARENTCHILD_DERIVED';    
              
            DECLARE @CircularReferenceCodeList TABLE  
            (            
                MemberCode            NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
            );  
              
            --Call [udpCircularReferenceMemberCodesGet] and get the number of circular reference errors and the member codes  
            --that participate in the circular reference  
            INSERT INTO @CircularReferenceCodeList EXEC    @CircularReferenceErrors = [mdm].[udpCircularReferenceMemberCodesGet]   
                                                        @RecursiveDerivedView = @ParentChildDerivedView,  
                                                        @MemberAttributes = @MemberAttributes;  
                      
            --If we found circular references, go ahead and update the error code on the relevant member code/attribute rows  
            IF @CircularReferenceErrors > 0  
                UPDATE WS  
                    SET ErrorCode = @ErrorCode_MemberCausesCircularReference,  
                        ErrorObjectType = @ObjectType_MemberAttribute  
                    FROM #MemberAttributeWorkingSet WS  
                    JOIN @CircularReferenceCodeList ErrorCodeList ON ErrorCodeList.MemberCode = WS.MemberCode  
                    WHERE WS.Attribute_ID = @RecursiveHierarchyAttribute_ID  
        END;  
  
        -- Determine if member security needs to be updated. This is true if a DBA has been updated and that DBA's domain entity is a  
        -- part of a derived hierarchy that has a member security permission.  
        DECLARE @NeedToUpdateMemberSecurity BIT= 0;  
        WITH changedDbaEntityId AS -- The domain entities of the domain-based attributes that have been updated.  
        (  
            SELECT DISTINCT  
                ad.Dba_Entity_ID AS Entity_ID  
            FROM #MemberAttributeWorkingSet maws  
            INNER JOIN #AttributeDefinition ad  
                ON   
                    maws.Attribute_ID = ad.Attribute_ID AND  
                    maws.ErrorCode IS NULL AND  
                    maws.IsChanged = 1 AND  
                    ad.AttributeType_ID = @AttributeType_DBA  
        ),  
        securedLevels AS -- The derived hierarchies that have member security, with their topmost level to which a member security assignment applies.  
        (  
            SELECT   
                sram.DerivedHierarchy_ID,  
                MIN(CASE sram.Member_ID WHEN 0 THEN -1 ELSE lvl.LevelNumber END) AS LevelNumber -- If Member_ID is zero, then the permission applies to the ROOT (level -1) of the  hierarchy  
            FROM mdm.tblSecurityRoleAccessMember sram  
            LEFT JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS lvl  
            ON   
                sram.DerivedHierarchy_ID = lvl.Hierarchy_ID AND -- Explicit hierarchy member permissions are ignored since this sproc won't change EH parent-child relationships.  
                sram.Version_ID = @Version_ID AND  
                lvl.Object_ID = 3 /*Entity*/ AND   
                lvl.Foreign_ID = sram.Entity_ID  
            GROUP BY sram.DerivedHierarchy_ID  
        ),  
        securedEntityId AS -- The domain entities to which security applies  
        (  
            SELECT DISTINCT      
                lvl.Foreign_ID AS Entity_ID  
            FROM mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS lvl  
            INNER JOIN securedLevels sec  
                ON   
                    lvl.Hierarchy_ID = sec.DerivedHierarchy_ID AND  
                    lvl.Object_ID = 3 /*Entity*/ AND  
                    lvl.LevelNumber > sec.LevelNumber -- Only domain entities underneath a member security assignment require the MS table to be recalculated  
        ),  
        updateNeeded AS  
        (  
            SELECT  
                TOP 1  
                1 UpdateNeeded  
            FROM changedDbaEntityId dba   
            INNER JOIN securedEntityId ent   
                ON dba.Entity_ID = ent.Entity_ID  
        )  
        SELECT   
            @NeedToUpdateMemberSecurity = UpdateNeeded  
        FROM updateNeeded  
          
        IF (@NeedToUpdateMemberSecurity = 1)  
        BEGIN  
            --Put a msg onto the SB queue to process member security  
            EXEC mdm.udpSecurityMemberQueueSave   
                @Role_ID    = NULL,-- update member count cache for all users  
                @Version_ID = @Version_ID,   
                @Entity_ID  = @Entity_ID;  
        END;  
  
        --Update MemberCode for any member attribute change errors that are associated with a successful member code change  
        --because we need to return the updated member code to the consumer.  
        WITH cteCodeChgs AS   
        (  
            SELECT Member_ID, AttributeValue  
            FROM #MemberAttributeWorkingSet  
            WHERE AttributeName = N'Code'  
              AND ErrorCode IS NULL  
        )  
        UPDATE ws        
            SET ws.MemberCode = cde.AttributeValue  
        FROM #MemberAttributeWorkingSet AS ws    
        INNER JOIN cteCodeChgs AS cde  
            ON ws.Member_ID = cde.Member_ID  
            AND ws.ErrorCode IS NOT NULL;  
          
        IF (@ShouldReturnMembersWithErrorsAsXml = 1)  
        BEGIN  
            -- Return as XML the list of all members (codes) with errors  
            SELECT @Return_MembersWithErrors = CONVERT(XML, (  
            SELECT MemberCode FROM  
                (  
                    SELECT DISTINCT  
                        ws.MemberCode AS MemberCode  
                    FROM #MemberAttributeWorkingSet ws  
                    WHERE ErrorCode IS NOT NULL  
                ) AS DistinctErrors  
                FOR XML PATH('MemberCodes')  
                )  
            )  
        END  
  
        --Return any errors                                                  
        SELECT DISTINCT   
             ws.Member_ID  
            ,ws.MemberCode  
            ,ws.MemberName  
            ,ad.Attribute_MUID  
            ,ws.AttributeName  
            ,ws.ErrorCode  
            ,ws.ErrorObjectType  
        FROM #MemberAttributeWorkingSet ws  
        LEFT OUTER JOIN #AttributeDefinition ad  
            ON ws.Attribute_ID = ad.Attribute_ID  
        WHERE ErrorCode IS NOT NULL;  
  
        --If there have been circular reference errors, run the rollback logic  
        IF @CircularReferenceErrors > 0  
            BEGIN  
                IF @TranCounter = 0 ROLLBACK TRANSACTION;  
                ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
            END  
        ELSE IF @TranCounter = 0 COMMIT TRANSACTION; --Commit only if we are not nested  
  
        RETURN(0);  
  
    END TRY  
    --Compensate as necessary  
    BEGIN CATCH  
  
        -- Get error info  
        DECLARE  
            @ErrorMessage NVARCHAR(4000),  
            @ErrorSeverity INT,  
            @ErrorState INT,  
            @ErrorNumber INT;  
        EXEC mdm.udpGetErrorInfo  
            @ErrorMessage = @ErrorMessage OUTPUT,  
            @ErrorSeverity = @ErrorSeverity OUTPUT,  
            @ErrorState = @ErrorState OUTPUT,  
            @ErrorNumber = @ErrorNumber OUTPUT;  
  
        IF @TranCounter = 0 ROLLBACK TRANSACTION;  
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);          
      
        RETURN(@ErrorNumber);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
