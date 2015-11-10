SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Procedure  : mdm.udpStagingMemberAttributeSave  
Component  : Import (Staging)  
Description: mdm.udpStagingMemberAttributeSave verifies and loads member attributes into MDS  
             NOTE **: When an unknown exception is encountered during attribute staging,  
             potential offending records are marked as error and the process continues   
             through a single transaction.  To allow for this type of processing, this stored   
             procedure cannot be executed in a context of outer transaction from a calling stored  
             procedure.  
  
Parameters : User name, Model version ID, transaction log indicator (Boolean - defaults to No)  
Return     : Status indicator  
  
Example 1  : EXEC mdm.udpStagingMemberAttributeSave 1, 18  
Example 2  : EXEC mdm.udpStagingMemberAttributeSave 2, 2, 1  
    EXEC mdm.udpStagingMemberAttributeSave 2, 43  
  
*/  
  
CREATE PROCEDURE [mdm].[udpStagingMemberAttributeSave]  
(  
   @User_ID             INT,  
   @Version_ID          INT,  
   @LogFlag             INT = NULL, --1 = Log; any other value = do not log  
   @Batch_ID            INT = NULL,  
   @Result              SMALLINT = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @Model_ID                   INT,  
            @ModelName                  NVARCHAR(50),  
            @SQL                        NVARCHAR(MAX),  
            @EntityID                   INT,  
            @EntityName                 NVARCHAR(100),  
            @EntityTable                sysname,  
            @HierarchyTable             sysname,  
            @CollectionTable            sysname,  
            @AttributeName              sysname,  
            @AttributeColumn            sysname,  
            @AttributeTypeID            INT,  
            @AttributeEntityTable       sysname,  
            @MetaID                     INT,  
            @ParamList                  NVARCHAR(500),  
            @EntityTableName            sysname,  
            @StageID                    BIGINT,  
            @MemberID                   INT,  
            @MemberType_ID              INT,  
            @ReferencingEntityName      NVARCHAR(50),  
            @ChildEntityTable           sysname,  
            @ChildAttributeColumnName   sysname,  
            @HierarchyEntityID          INT,  
            @VersionStatus_ID			INT,  
            @VersionStatus_Committed	INT = 3,  
            @TranCounter                INT,  
            @MemberCode                 NVARCHAR(250),  
            @DBAValue                   NVARCHAR(250),  
              
            -- member type constants  
            @FreeformTypeId             INT = 1,  
            @DomainTypeId               INT = 2,  
            @SystemTypeId               INT = 3,  
              
            -- transaction type constants  
            @StatusChangedId            INT = 2,  
            @AttributeChangedId         INT = 3,    
                
            -- attribute datatype constants    
            @DataType_Decimal           INT = 2,    
            @DataType_Integer           INT = 7,    
            @DataType_DateTime          INT = 3,  
              
            -- staging datastatus constants  
            @StatusDefault				INT = 0,  
            @StatusOK					INT = 1,  
            @StatusError				INT = 2,  
              
            --XACT_STATE() constancts  
            @UncommittableTransaction	INT = -1;     
  
    DECLARE @TableMeta TABLE   
    (  
         ID                     INT IDENTITY (1, 1) NOT NULL  
        ,EntityID               INT  
        ,EntityName             NVARCHAR(250) COLLATE database_default  
        ,EntityTable            sysname COLLATE database_default NULL   
        ,AttributeName          sysname COLLATE database_default NULL  
        ,AttributeColumn        sysname COLLATE database_default NULL  
        ,AttributeTypeID        INT  
        ,AttributeEntityTable   sysname COLLATE database_default NULL  
        ,MemberType_ID          INT  
    );  
  
    SELECT @Model_ID = Model_ID, @VersionStatus_ID = Status_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID;    
    SELECT @ModelName = [Name] FROM mdm.tblModel WHERE ID = @Model_ID;  
  
    IF @User_ID IS NULL RETURN 2;  
    IF @Model_ID IS NULL RETURN 3;  
    IF @ModelName IS NULL RETURN 3;  
  
    --Confirm that the user possesses Model administrator rights before allowing staging to begin  
    IF NOT EXISTS(SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MODEL WHERE [User_ID] = @User_ID AND ID = @Model_ID AND IsAdministrator = 1) BEGIN  
        RAISERROR('MDSERR120002|The user does not have permission to perform this operation.', 16, 1);  
        RETURN(4)  
    END; --if  
  
    --Ensure that Version is not committed  
    IF (@VersionStatus_ID = @VersionStatus_Committed) BEGIN  
        RAISERROR('MDSERR310040|Data cannot be loaded into a committed version.', 16, 1);  
        RETURN(3);      
    END;   
      
    BEGIN TRY  
      
        --Create member attribute staging temporary table  
        --Note: This has to be a temporary table, compared to a table variable, because we need to reference it in dynamic SQL.  
        CREATE TABLE #tblStage   
        (  
            Stage_ID                BIGINT NOT NULL,   
            Entity_ID                INT NULL,   
            Entity_Name                NVARCHAR(250) COLLATE database_default NULL,   
            Entity_Table            sysname COLLATE database_default NULL,   
            Hierarchy_Table            sysname COLLATE database_default NULL,   
            MemberType_ID            TINYINT NULL,   
            Member_ID                INT NULL,  
            Member_Status_ID        INT NULL DEFAULT 0,  
            Member_Code                NVARCHAR(125) COLLATE database_default NULL,  
            Attribute_ID            INT NULL,   
            AttributeType_ID        INT NULL,   
            Attribute_Entity_Table    sysname COLLATE database_default NULL,   
            Attribute_Name            NVARCHAR(250) COLLATE database_default NULL,  
            Attribute_Column        sysname COLLATE database_default NULL,  
            Attribute_Value            NVARCHAR(2000) COLLATE database_default NULL,  
            Attribute_Value_Mapped    NVARCHAR(2000) COLLATE database_default NULL, --FFA: Contains the attribute value, DBA: contains the corresponding DBA.ID value for the associated DBA.Code value.  
            Attribute_ChangeTrackingGroup INT,  
            STG_Status_ID            INT NULL DEFAULT 1,  
            STG_Status_ErrorCode    NVARCHAR(10) COLLATE database_default NOT NULL DEFAULT N'210000',  
            TransactionType_ID      INT NULL  
        );  
  
        --Create temporary table to the IDs of the updated members.  
        --Note: This has to be a temporary table, compared to a table variable, because we need to reference it in dynamic SQL.  
        CREATE TABLE #tblUpdatedMembers  
            (  
             ID int  
            );  
              
        --Create temporary table to store business rule attribute inheritance information  
        --Note: This has to be a temporary table, compared to a table variable, because we need to reference it in dynamic SQL.  
        CREATE TABLE #tblBRAttributeInheritance  
            (  
             ModelID int  
            ,ParentEntityID int  
            ,ParentEntityName nvarchar(250) Collate database_default  
            ,ParentEntityTableName sysname Collate database_default  
            ,ParentAttributeName nvarchar(250) Collate database_default NULL  
            ,ParentAttributeColumnName nvarchar(250) Collate database_default NULL  
            ,ChildEntityID int NULL  
            ,ChildEntityName nvarchar(250) Collate database_default NULL  
            ,ChildEntityTableName sysname  
            ,ChildAttributeName nvarchar(250) Collate database_default NULL  
            ,ChildAttributeColumnName nvarchar(250) Collate database_default NULL  
            ,ChildEntityMemberTypeID INT  
            )  
  
        --Load business rule attribute inheritance information  
        INSERT INTO #tblBRAttributeInheritance  
        SELECT   
             ParentModelID  
            ,ParentEntityID  
            ,ParentEntityName  
            ,parEnt.EntityTableName  
            ,ParentAttributeName  
            ,ParentAttributeColumnName  
            ,ChildEntityID  
            ,ChildEntityName  
            ,chiEnt.EntityTableName  
            ,ChildAttributeName  
            ,ChildAttributeColumnName  
            ,Attribute_MemberType_ID  
        FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY i  
        INNER JOIN mdm.viw_SYSTEM_TABLE_NAME parEnt  
            ON i.ParentEntityID = parEnt.ID  
        INNER JOIN mdm.viw_SYSTEM_TABLE_NAME chiEnt  
            ON i.ChildEntityID = chiEnt.ID  
        WHERE i.ParentModelID = @Model_ID  
  
  
        --Create temporary table to store business rule hierarchy inheritance information  
        --Note: This has to be a temporary table, compared to a table variable, because we need to reference it in dynamic SQL.  
        CREATE TABLE #tblBRHierarchyInheritance  
            (  
             ModelID int  
            ,EntityID int  
            ,EntityName nvarchar(250) Collate database_default  
            ,EntityTableName sysname Collate database_default  
            ,AttributeName nvarchar(250) Collate database_default NULL  
            ,AttributeColumnName nvarchar(250) Collate database_default NULL  
            ,[HierarchyID] int NULL  
            ,HierarchyName nvarchar(250) Collate database_default NULL  
            )  
  
        --Load business rule hierarchy inheritance information  
        INSERT INTO #tblBRHierarchyInheritance  
        SELECT   
             i.ModelID  
            ,i.EntityID  
            ,i.EntityName  
            ,ent.HierarchyParentTableName  
            ,i.AttributeName  
            ,i.AttributeColumnName  
            ,i.[HierarchyID]  
            ,i.HierarchyName  
        FROM mdm.viw_SYSTEM_BUSINESSRULES_HIERARCHY_CHANGEVALUE_INHERITANCE i  
        INNER JOIN mdm.viw_SYSTEM_TABLE_NAME ent  
            ON i.EntityID = ent.ID  
        WHERE i.ModelID = @Model_ID  
  
  
        --Update errors already identified by the staging view.  
        UPDATE tStage SET   
            tStage.Status_ID = vStage.Status_ID,   
            tStage.ErrorCode = vStage.Status_ErrorCode  
        FROM mdm.tblStgMemberAttribute AS tStage   
        INNER JOIN mdm.udfStagingMemberAttributesGet(@User_ID, @Model_ID, 2,@Batch_ID) AS vStage   
        ON tStage.ID = vStage.Stage_ID;  
  
        --PRE-PROCESSING AND VALIDATION  
        --Exclude duplicate actions on a single code in the staging table              
        WITH rawWithCount AS  
        (  
            SELECT  
                ROW_NUMBER() OVER (PARTITION BY Entity_Name, Member_Code ORDER BY Stage_ID) AS RN,  
                Stage_ID  
            --FROM mdm.udfStagingMemberAttributesGet(NULL, 7, 0, 3) --Used for debugging  
            FROM mdm.udfStagingMemberAttributesGet(@User_ID, @Model_ID, 0, @Batch_ID)  
            WHERE Attribute_Name = N'Code' AND Status_ID = @StatusDefault  
        ),  
        duplicateCodeValues AS  
        (  
            SELECT Stage_ID FROM rawWithCount WHERE RN > 1  
        )  
        UPDATE tStage SET  
           Status_ID = @StatusError,   
           ErrorCode = N'210001'  
        FROM mdm.tblStgMemberAttribute AS tStage  
        INNER JOIN duplicateCodeValues AS dup  
            ON tStage.ID = dup.Stage_ID;  
  
        --Exclude duplicate member codes across the entity in the staging table              
        WITH rawWithCount AS  
        (  
            SELECT  
                ROW_NUMBER() OVER (PARTITION BY Entity_Name, Attribute_Value ORDER BY Stage_ID) AS RN,  
                Stage_ID  
            FROM mdm.udfStagingMemberAttributesGet(@User_ID, @Model_ID, 0, @Batch_ID)  
            WHERE Attribute_Name = N'Code' AND Status_ID = @StatusDefault  
        ),  
        duplicateCodeValues AS  
        (  
            SELECT Stage_ID FROM rawWithCount WHERE RN > 1  
        )  
        UPDATE tStage SET  
           Status_ID = @StatusError,   
           ErrorCode = N'210001'  
        FROM mdm.tblStgMemberAttribute AS tStage  
        INNER JOIN duplicateCodeValues AS dup  
            ON tStage.ID = dup.Stage_ID;  
  
        --Load records that were not identified by the staging view as errors.  
        INSERT INTO #tblStage  
        (  
            Stage_ID,   
            Entity_ID,   
            Entity_Name,   
            Entity_Table,  
            Hierarchy_Table,   
            MemberType_ID,   
            Member_Code,   
            Attribute_ID,   
            AttributeType_ID,   
            Attribute_Entity_Table,   
            Attribute_Name,   
            Attribute_Column,   
            Attribute_Value,   
            Attribute_Value_Mapped,   
            Attribute_ChangeTrackingGroup,  
            TransactionType_ID  
        )  
        SELECT     
            Stage_ID,  
            Entity_ID,  
            Entity_Name,   
            Entity_Table,   
            Hierarchy_Table,  
            MemberType_ID,   
            Member_Code,  
            Attribute_ID,   
            AttributeType_ID,   
            Attribute_Entity_Table,   
            Attribute_Name,  
            Attribute_Column,  
            Attribute_Value,  
            CASE AttributeType_ID WHEN @FreeformTypeId THEN Attribute_Value ELSE NULL END,  
            Attribute_ChangeTrackingGroup,  
            CASE Attribute_Column WHEN N'Status_ID' THEN @StatusChangedId ELSE @AttributeChangedId END  
        FROM  
            mdm.udfStagingMemberAttributesGet(@User_ID, @Model_ID, 0,@Batch_ID) AS vStage   
        ORDER BY Stage_ID;  
      
        --When Staging deletions, the Code must be changed to a guid so it can be re-used  
        INSERT INTO #tblStage  
        (  
            Stage_ID,   
            Entity_ID,   
            Entity_Name,   
            Entity_Table,  
            Hierarchy_Table,   
            MemberType_ID,   
            Member_Code,   
            Attribute_ID,   
            AttributeType_ID,   
            Attribute_Entity_Table,   
            Attribute_Name,   
            Attribute_Column,   
            Attribute_Value,   
            Attribute_Value_Mapped,   
            Attribute_ChangeTrackingGroup  
        )  
        SELECT     
            vStage.Stage_ID,  
            vStage.Entity_ID,  
            vStage.Entity_Name,   
            vStage.Entity_Table,   
            vStage.Hierarchy_Table,  
            vStage.MemberType_ID,   
            vStage.Member_Code,  
            att.ID,   
            @FreeformTypeId,   
            N'',   
            N'Code',  
            N'Code',  
            cd.guid,  
            cd.guid,  
            att.ChangeTrackingGroup  
        FROM  
            mdm.udfStagingMemberAttributesGet(@User_ID, @Model_ID, 0,@Batch_ID) AS vStage  
            INNER JOIN mdm.tblAttribute att ON att.Entity_ID = vStage.Entity_ID  
                AND att.MemberType_ID = vStage.MemberType_ID  
                AND att.Name = N'Code'  
                AND vStage.Attribute_Column = N'Status_ID'  
            INNER JOIN (SELECT NEWID() guid) cd ON 1=1  
        ORDER BY Stage_ID;  
              
         --Flag attributes with length greater than the allowable attribute length    
        UPDATE #tblStage SET       
                  STG_Status_ID = @StatusError,       
                  STG_Status_ErrorCode = N'210024'       
            FROM #tblStage AS vStage    
        INNER JOIN mdm.tblAttribute Attr ON Attr.ID = vStage.Attribute_ID    
        WHERE vStage.STG_Status_ID = @StatusOK AND vStage.Attribute_Entity_Table IS NULL AND Attr.DataType_ID = 1    
        AND LEN(vStage.Attribute_Value) > Attr.DataTypeInformation;    
    
        --Flag attributes with incorrect numeric types	    
        --@DataType_ID = 2    
        --@DataType_ID = 7    
        UPDATE #tblStage SET       
                STG_Status_ID = @StatusError,       
                STG_Status_ErrorCode = CASE ISNUMERIC(vStage.Attribute_Value) WHEN 0 THEN   
                N'210025' ELSE -- 'Error - The AttributeValue must be a number.'  
                N'210024' END  -- 'Error - The AttributeValue is too long.'   
        FROM #tblStage AS vStage    
        INNER JOIN mdm.tblAttribute Attr ON   
            Attr.ID = vStage.Attribute_ID AND   
            vStage.STG_Status_ID = @StatusOK AND   
            vStage.Attribute_Entity_Table IS NULL AND   
            (Attr.DataType_ID = @DataType_Decimal OR   
             Attr.DataType_ID = @DataType_Integer) AND   
            vStage.Attribute_Value IS NOT NULL AND  
            CASE -- using a CASE statement here ensures Boolean short-circuiting. If the value isn't numeric then trying to convert it to float will crash  
                WHEN ISNUMERIC(vStage.Attribute_Value) <> 1 THEN 1  
                WHEN ISNUMERIC(STR(CONVERT(FLOAT, vStage.Attribute_Value), 38, Attr.DataTypeInformation)) <> 1 THEN 1  
                ELSE 0 END = 1  
          
        -- Numeric data types in scientific notation format cannot be directly converted to type   
        -- DECIMAL, so convert them to fixed-point notation.  
        UPDATE #tblStage SET       
            Attribute_Value_Mapped =   
            -- the CASE condition is redundant with part of the JOIN clause, but it is necessary because even when false the query will still  
            -- sometimes evaluate the right-hand side of this assignment, which can cause a "failure to convert nvarchar to float" error.  
                CASE vStage.STG_Status_ID  
                    WHEN @StatusOK THEN STR(CONVERT(FLOAT, vStage.Attribute_Value_Mapped), 38, Attr.DataTypeInformation)   
                    ELSE  vStage.Attribute_Value_Mapped  
                END    
        FROM #tblStage AS vStage    
        INNER JOIN mdm.tblAttribute Attr ON   
            Attr.ID = vStage.Attribute_ID AND   
            vStage.STG_Status_ID = @StatusOK AND   
            vStage.Attribute_Entity_Table IS NULL AND   
            (Attr.DataType_ID = @DataType_Decimal OR Attr.DataType_ID = @DataType_Integer) AND  
            CHARINDEX(N'E', UPPER(vStage.Attribute_Value_Mapped)) > 0 	-- CHARINDEX uses 1-based indexing	    
  
        --Flag attributes with incorrect date type    
        --@DataType_ID = 3 BEGIN --DATETIME    
        UPDATE #tblStage SET       
                  STG_Status_ID = @StatusError,       
                  STG_Status_ErrorCode = N'210026'       
            FROM #tblStage AS vStage  		  
        INNER JOIN mdm.tblAttribute Attr ON   
                Attr.ID = vStage.Attribute_ID AND  
                vStage.STG_Status_ID = @StatusOK AND   
                vStage.Attribute_Entity_Table IS NULL AND   
                Attr.DataType_ID = @DataType_DateTime AND  
                LEN(COALESCE(vStage.Attribute_Value, N'')) > 0 AND  
                mdq.IsDateTime2(vStage.Attribute_Value) = 0;   
         
        UPDATE #tblStage SET   
             Entity_Table = SUBSTRING(Entity_Table, 6, LEN(Entity_Table) - 6)  
            ,Attribute_Entity_Table = CASE   
                WHEN LEFT(Attribute_Entity_Table, 7) = 'mdm.[tb' THEN SUBSTRING(Attribute_Entity_Table, 6, LEN(Attribute_Entity_Table) - 6)  
                ELSE Attribute_Entity_Table      
             END  
            ,Hierarchy_Table = SUBSTRING(Hierarchy_Table, 6, LEN(Hierarchy_Table) - 6);  
  
        --Fetch user and system DBA IDs associated with the code value (system domain-based attribute values are not version-specific)  
        INSERT INTO @TableMeta (AttributeEntityTable, AttributeTypeID)  
        SELECT DISTINCT   
             Attribute_Entity_Table  
            ,AttributeType_ID   
        FROM #tblStage AS sma   
        WHERE AttributeType_ID IN (@DomainTypeId, @SystemTypeId);  
          
        SET @ParamList = N'@VersionID INT, @AttributeEntityTable sysname, @StatusOK INT';  
  
        WHILE EXISTS(SELECT 1 FROM @TableMeta)    BEGIN  
          
            SELECT TOP 1  
                @MetaID = ID,   
                @AttributeEntityTable = AttributeEntityTable,  
                @AttributeTypeID = AttributeTypeID,  
                @MemberType_ID = MemberType_ID  
            FROM @TableMeta;  
          
            IF @AttributeEntityTable = N'mdm.udfTransactionGetByTransactionType(2)' BEGIN  
                SET @SQL = N'  
                    UPDATE #tblStage SET   
                        Attribute_Value_Mapped = dba.ID  
                    FROM #tblStage AS sma   
                    LEFT OUTER JOIN mdm.udfTransactionGetByTransactionType(2) AS dba ON dba.Code = sma.Attribute_Value ' +  
                        CASE @AttributeTypeID WHEN @DomainTypeId THEN N'AND dba.Version_ID = @VersionID ' ELSE N'' END + N'   
                    WHERE Attribute_Entity_Table = @AttributeEntityTable '  
            END ELSE BEGIN  
                SET @SQL = N'  
                    UPDATE #tblStage SET   
                        Attribute_Value_Mapped = dba.ID  
                    FROM #tblStage AS sma   
                    LEFT OUTER JOIN mdm.' + QUOTENAME(@AttributeEntityTable) + N' AS dba ON dba.Code = sma.Attribute_Value ' +  
                        CASE @AttributeTypeID WHEN @DomainTypeId THEN N'AND dba.Version_ID = @VersionID ' ELSE N'' END + N'   
                    WHERE dba.Status_ID = @StatusOK AND Attribute_Entity_Table = @AttributeEntityTable '  
            END; --if  
              
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @AttributeEntityTable, @StatusOK;  
  
            DELETE FROM @TableMeta WHERE ID = @MetaID;  
              
        END; --while  
  
        --Perform validation check on all user DBA code values (EDM-1060: allow nulls values to be staged for user DBAs)  
        UPDATE #tblStage SET   
            STG_Status_ID = @StatusError,   
            STG_Status_ErrorCode = N'210003'   
        FROM #tblStage   
        WHERE AttributeType_ID = @DomainTypeId AND Attribute_Value_Mapped IS NULL AND Attribute_Value IS NOT NULL;  
  
        --Perform validation check on all system DBA code values  
        UPDATE #tblStage SET   
            STG_Status_ID = @StatusError,   
            STG_Status_ErrorCode = N'210004'   
        FROM #tblStage   
        WHERE AttributeType_ID = @SystemTypeId AND Attribute_Value_Mapped IS NULL;  
  
        --Perform existing member validations  
        INSERT INTO @TableMeta (EntityTable)  
        SELECT DISTINCT   
            Entity_Table  
        FROM  #tblStage AS sma   
        WHERE STG_Status_ID = @StatusOK;  
  
        SET @ParamList = N'@VersionID INT, @EntityTable sysname';         
        WHILE EXISTS(SELECT 1 FROM @TableMeta)    BEGIN  
          
            SELECT TOP 1   
                  @MetaID = ID,   
                  @EntityTableName = EntityTable  
            FROM @TableMeta;  
              
            SET @SQL= N'  
                UPDATE #tblStage SET     
                     Member_ID = ent.ID  
                    ,Member_Status_ID = ent.Status_ID  
                FROM #tblStage AS sma   
                LEFT OUTER JOIN mdm.' + QUOTENAME(@EntityTableName) + N' AS ent   
                    ON ent.Code = sma.Member_Code AND ent.Version_ID = @VersionID  
                WHERE Entity_Table = @EntityTable;';  
  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @EntityTableName;  
  
            DELETE FROM @TableMeta WHERE ID = @MetaID;  
        END; --while  
  
        -- Update the member code values for member deletions. This is necessary to allow  
        -- the transaction to be reversible when deleting a member or changing its code.              
        UPDATE sma SET     
            sma.Member_Code = COALESCE(smaCode.Attribute_Value, sma.Member_Code)  
        FROM #tblStage AS sma   
        LEFT JOIN #tblStage smaCode  
            ON smaCode.Member_ID = sma.Member_ID AND  
               smaCode.Member_Code = sma.Member_Code AND  
               smaCode.MemberType_ID = sma.MemberType_ID AND  
               smaCode.Entity_Table = sma.Entity_Table AND  
               smaCode.Attribute_Column = N'Code' AND  
               sma.Attribute_Column = N'Status_ID';         
        UPDATE #tblStage SET     
            Member_Code = Attribute_Value  
        WHERE  
            Attribute_Column = N'Code';  
  
        --Check for the attribute ObjectId for the Metadata Entities (IsSystem = 1)  
        UPDATE #tblStage SET   
            STG_Status_ID = @StatusError,   
            STG_Status_ErrorCode = N'210051'  
        FROM #tblStage tStage  
            INNER JOIN mdm.tblEntity e  
            ON tStage.Entity_Name = e.Name  
        WHERE e.IsSystem = 1 AND  
              UPPER(tStage.Attribute_Name) = 'OBJECTID'  
  
        UPDATE #tblStage SET   
            STG_Status_ID = @StatusError,   
            STG_Status_ErrorCode = N'300002'  
        FROM #tblStage  
        WHERE Member_ID IS NULL AND STG_Status_ID <> 2;  
  
        UPDATE #tblStage SET   
            STG_Status_ID = @StatusError,   
            STG_Status_ErrorCode = N'210006'  
        FROM #tblStage  
        WHERE Member_ID IS NOT NULL AND Member_Status_ID = @StatusError AND AttributeType_ID <> @SystemTypeId; --Exlude system attributes so that reversals of deletions may be performed  
  
        --Perform validation check on code attribute changes  
        INSERT INTO @TableMeta   
        (  
            EntityID,   
            EntityName  
        )  
        SELECT DISTINCT  
            Entity_ID,  
            Entity_Name  
        FROM #tblStage AS sma  
        WHERE sma.STG_Status_ID = @StatusOK AND sma.Attribute_Name = N'Code';  
  
        WHILE EXISTS(SELECT 1 FROM @TableMeta) BEGIN  
          
            SELECT TOP 1 @MetaID = ID, @EntityID = EntityID, @EntityName = EntityName FROM @TableMeta;  
  
            SELECT   
                @EntityTable = EntityTableName, @HierarchyTable = HierarchyParentTableName, @CollectionTable = CollectionTableName   
            FROM [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @EntityID;  
              
            SET @ParamList =  N'@VersionID INT, @EntityName sysname, @StatusError INT';  
              
            --Verify uniqueness against the entity table if updating the Code attribute  
            SET @SQL = N'  
                UPDATE tStage SET   
                     STG_Status_ID = @StatusError  
                    ,STG_Status_ErrorCode = N''300003''  
                FROM #tblStage AS tStage   
                INNER JOIN mdm.' + QUOTENAME(@EntityTable) + N' AS tSource   
                    ON tStage.Attribute_Value = tSource.Code   
                WHERE tSource.Version_ID = @VersionID AND tStage.Entity_Name = @EntityName  
                AND tStage.MemberType_ID IN (SELECT ID FROM mdm.tblEntityMemberType WHERE ID IN (1,2,3))   
                AND tStage.Attribute_Name = N''Code'';';  
  
  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @EntityName, @StatusError;  
  
            --Verify uniqueness against the parent table if updating the Code attribute  
            SET @SQL = N'  
                UPDATE tStage SET   
                     STG_Status_ID = @StatusError  
                    ,STG_Status_ErrorCode = N''300003''  
                FROM #tblStage AS tStage   
                INNER JOIN mdm.' + QUOTENAME(@HierarchyTable) + N' AS tSource   
                    ON tStage.Attribute_Value = tSource.Code   
                WHERE tSource.Version_ID = @VersionID AND tStage.Entity_Name = @EntityName  
                AND tStage.MemberType_ID IN (SELECT ID FROM mdm.tblEntityMemberType WHERE ID IN (1,2,3))  
                AND tStage.Attribute_Name = N''Code'';';  
  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @EntityName, @StatusError;  
  
            --Verify uniqueness against the collection table if updating the Code attribute (EDM-2486)  
            SET @SQL = N'  
                UPDATE tStage SET   
                     STG_Status_ID = @StatusError  
                    ,STG_Status_ErrorCode = N''300003''  
                FROM #tblStage AS tStage   
                INNER JOIN mdm.' + QUOTENAME(@CollectionTable) + N' AS tSource   
                    ON tStage.Attribute_Value = tSource.Code   
                WHERE tSource.Version_ID = @VersionID AND tStage.Entity_Name = @EntityName  
                AND tStage.MemberType_ID IN (SELECT ID FROM mdm.tblEntityMemberType WHERE ID IN (1,2,3))  
                AND tStage.Attribute_Name = N''Code'';';  
  
            EXEC sp_executesql @SQL, @ParamList, @Version_ID, @EntityName, @StatusError;  
  
            DELETE FROM @TableMeta WHERE ID = @MetaID;  
  
        END; --while  
  
        --Perform validation checks on member deletions    
        DECLARE @TableMemberDeletions AS TABLE  
        (    
            Stage_ID BIGINT NOT NULL,              
            Entity_ID INT NOT NULL,   
            Member_ID INT NOT NULL  
        )    
          
        INSERT INTO @TableMemberDeletions  
        SELECT DISTINCT    
            Stage_ID,  
            Entity_ID,  
            Member_ID    
        FROM #tblStage AS sma   
        WHERE sma.STG_Status_ID = @StatusOK   
            AND sma.Attribute_Value = 'De-Activated';    
              
        WHILE EXISTS(SELECT 1 FROM @TableMemberDeletions) BEGIN              
            SELECT TOP 1 @StageID = Stage_ID, @EntityID = Entity_ID, @MemberID = Member_ID FROM @TableMemberDeletions;    
              
            --Check if member is use as the value of another Entity's DBA.  
            EXEC mdm.udpGetFirstEntityUsingMember @EntityID, @MemberID, @Version_ID, @ReferencingEntityName OUTPUT                  
              
            IF @ReferencingEntityName IS NOT NULL  
            BEGIN  
                UPDATE #tblStage  
                SET  
                    STG_Status_ID = @StatusError,     
                    STG_Status_ErrorCode = N'210052'  
                FROM #tblStage AS tStage  
                WHERE tStage.Stage_ID = @StageID           
            END  
  
            DELETE FROM @TableMemberDeletions WHERE Stage_ID = @StageID;    
        END; --while (Perform validation checks on member deletions)                       
  
        -- Check if any of the attributes are in a recursive derived hierarchy  
        IF EXISTS (  
              SELECT 1               
              FROM mdm.tblDerivedHierarchyDetail d    
              INNER JOIN mdm.tblAttribute a ON a.ID = d.Foreign_ID    
              WHERE d.ForeignParent_ID = a.DomainEntity_ID    
              AND a.Name IN (SELECT DISTINCT sma.Attribute_Name FROM #tblStage AS sma))  
        BEGIN  
  
           -- Perform circular reference check on remaining DBAs  
             DECLARE @TableDBA AS TABLE    
            (     
                Stage_ID BIGINT NOT NULL,   
                Attribute_Name NVARCHAR(50),    
                Member_Code NVARCHAR(250),  
                DBA_Value NVARCHAR(250)  
            );  
                  
            INSERT INTO @TableDBA     
            (    
                Stage_ID, Attribute_Name, Member_Code, DBA_Value    
            )     
            SELECT DISTINCT --Get distinct list of DBAs that need staging     
                sma.Stage_ID,    
                sma.Attribute_Name,    
                sma.Member_Code,    
                sma.Attribute_Value    
            FROM  #tblStage AS sma    
            WHERE sma.STG_Status_ID = 1 AND AttributeType_ID = @DomainTypeId;    
        
            WHILE EXISTS(SELECT 1 FROM @TableDBA) BEGIN                
                SELECT TOP 1 @StageID = Stage_ID, @AttributeName = Attribute_Name, @MemberCode = Member_Code, @DBAValue = DBA_Value FROM @TableDBA;      
                    
                --Check if member value will result in a circular reference.  
                DECLARE @IsCircular INT  
                EXEC mdm.udpMemberRecursiveCircularCheck @Model_ID, @Version_ID, @AttributeName, @MemberCode, @DBAValue, @IsCircular OUTPUT    
                    
                IF @IsCircular = 1    
                BEGIN    
                    UPDATE #tblStage    
                    SET    
                        STG_Status_ID = @StatusError,       
                        STG_Status_ErrorCode = N'210053'    
                    FROM #tblStage AS tStage    
                    WHERE tStage.Stage_ID = @StageID             
                END    
                    
                DELETE FROM @TableDBA WHERE Stage_ID = @StageID;      
            END; --while (Perform circular reference check on remaining DBAs)     
        END; -- end Check if any of the attributes are in a recursive derived hierarchy   
       
        --Update attributes  
        INSERT INTO @TableMeta   
        (  
            EntityTable, AttributeName, AttributeColumn, AttributeTypeID, AttributeEntityTable  
        )   
        SELECT DISTINCT --Get distinct list of attributes that need staging  
            sma.Entity_Table,   
            sma.Attribute_Name,  
            sma.Attribute_Column,  
            sma.AttributeType_ID,  
            sma.Attribute_Entity_Table  
        FROM  #tblStage AS sma  
        WHERE sma.STG_Status_ID = @StatusOK;  
  
  
        WHILE EXISTS(SELECT 1 FROM @TableMeta) BEGIN  
             --Start transaction, being careful to check if we are nested  
            SET @TranCounter = @@TRANCOUNT;  
            IF @TranCounter > 0 SAVE TRANSACTION TX;  
            ELSE BEGIN TRANSACTION;   
            BEGIN TRY  
  
                SELECT TOP 1  
                    @MetaID               = ID,   
                    @EntityTable          = EntityTable,  
                    @AttributeName        = AttributeName,  
                    @AttributeColumn      = AttributeColumn,  
                    @AttributeTypeID      = AttributeTypeID,  
                    @AttributeEntityTable = AttributeEntityTable  
                FROM @TableMeta;  
  
               /*  
               ---------------------------  
               PROCESS TRANSACTION LOGGING  
               ---------------------------  
               If logging is requested then insert into the transaction log  
               */  
               IF @LogFlag = 1 BEGIN  
  
                  --Insert transactions only for the attribute values that have changed.  
                  IF @AttributeTypeID = @FreeformTypeId BEGIN --Free-Form Attributes  
  
                     SET @ParamList = N'@VersionID INT, @UserID INT, @EntityTable sysname, @AttributeName sysname, @StatusOK INT';  
                     SET @SQL= N'  
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
                        ) SELECT   
                            @VersionID ,  
                            COALESCE(sma.TransactionType_ID, ' + CAST(@AttributeChangedId AS NVARCHAR(1)) + N'),  
                            0,  
                            sma.Entity_ID,  
                            sma.Attribute_ID,  
                            sma.Member_ID,  
                            sma.MemberType_ID,  
                            sma.Member_Code,   
                            ent.' + QUOTENAME(@AttributeColumn) + N',  
                            ent.' + QUOTENAME(@AttributeColumn) + N',  
                            sma.Attribute_Value,  
                            sma.Attribute_Value,  
                            GETUTCDATE(),   
                            @UserID,  
                            GETUTCDATE(),  
                            @UserID   
                        FROM #tblStage AS sma   
                        INNER JOIN mdm.' + QUOTENAME(@EntityTable) + N' AS ent' +  
                            N' ON  sma.Member_ID = ent.ID' +  
                            N' AND ent.Version_ID = @VersionID    
                            AND (CASE   
                                WHEN ent.' + QUOTENAME(@AttributeColumn) + N' IS NULL AND sma.Attribute_Value_Mapped IS NOT NULL THEN 1   
                                WHEN ent.' + QUOTENAME(@AttributeColumn) + N' IS NOT NULL AND sma.Attribute_Value_Mapped IS NULL THEN 1'  
                                   
                        -- Look up the ID from tblUser since the Owner_ID is populated with the Username    
                        IF @AttributeColumn = 'Owner_ID'  
                            SET @SQL = @SQL + N' WHEN ent.' + QUOTENAME(@AttributeColumn) + N' <> COALESCE((SELECT ID FROM mdm.tblUser WHERE UserName = sma.Attribute_Value_Mapped), ent.Owner_ID) THEN 1'     
                        ELSE  
                            SET @SQL = @SQL + N' WHEN ent.' + QUOTENAME(@AttributeColumn) + N' <> sma.Attribute_Value_Mapped THEN 1'     
                              
                        SET @SQL = @SQL + N'                          
                            ELSE 0 END    
                        ) = 1 AND sma.Entity_Table = @EntityTable   
                            AND sma.Attribute_Name = @AttributeName   
                        WHERE  sma.STG_Status_ID = @StatusOK;';  
                        EXEC sp_executesql @SQL, @ParamList, @Version_ID, @User_ID, @EntityTable, @AttributeName, @StatusOK;  
  
                  END ELSE IF @AttributeTypeID = @DomainTypeId BEGIN--User Domain-Based Attributes  
  
                    SET @ParamList = N'@VersionID INT, @UserID INT, @EntityTable sysname, @AttributeName sysname, @StatusOK INT';  
                        IF @AttributeEntityTable = CAST(N'mdm.udfTransactionGetByTransactionType(2)' as sysname) BEGIN  
                            SET @SQL= N'  
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
                                ) SELECT   
                                    @VersionID ,  
                                    COALESCE(sma.TransactionType_ID, ' + CAST(@AttributeChangedId AS NVARCHAR(1)) + N'),  
                                    0,  
                                    sma.Entity_ID,  
                                    sma.Attribute_ID,  
                                    sma.Member_ID,  
                                    sma.MemberType_ID,  
                                    sma.Member_Code,   
                                    ISNULL(ent.' + QUOTENAME(@AttributeColumn) + N',0),  
                                    ISNULL(dba.Code,''''),  
                                    sma.Attribute_Value_Mapped,  
                                    sma.Attribute_Value,  
                                    GETUTCDATE(),   
                                    @UserID,  
                                    GETUTCDATE(),  
                                    @UserID  
                                FROM #tblStage AS sma   
                                INNER JOIN mdm.' + QUOTENAME(@EntityTable) + ' ent' +  
                                    ' ON  sma.Member_ID = ent.ID' +  
                                    ' AND ent.Version_ID = @VersionID  
                                     AND (CASE   
                                        WHEN ent.' + QUOTENAME(@AttributeColumn) + N' IS NULL AND sma.Attribute_Value_Mapped IS NOT NULL THEN 1   
                                        WHEN ent.' + QUOTENAME(@AttributeColumn) + N' IS NOT NULL AND sma.Attribute_Value_Mapped IS NULL THEN 1   
                                        WHEN ent.' + QUOTENAME(@AttributeColumn) + N' <> sma.Attribute_Value_Mapped THEN 1   
                                        ELSE 0 END) = 1' +  
                                    ' AND sma.Entity_Table = @EntityTable  
                                     AND sma.Attribute_Name = @AttributeName   
                                LEFT OUTER JOIN mdm.udfTransactionGetByTransactionType(2) dba' +  
                                    ' ON dba.ID = ent.' + QUOTENAME(@AttributeColumn) +  
                                    ' AND dba.Version_ID = @VersionID  
                                WHERE sma.STG_Status_ID = @StatusOK;';  
  
                        END ELSE BEGIN  
  
                            SET @SQL= N'  
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
                                ) SELECT   
                                    @VersionID ,  
                                    COALESCE(sma.TransactionType_ID, ' + CAST(@AttributeChangedId AS NVARCHAR(1)) + N'),  
                                    0,  
                                    sma.Entity_ID,  
                                    sma.Attribute_ID,  
                                    sma.Member_ID,  
                                    sma.MemberType_ID,  
                                    sma.Member_Code,   
                                    ISNULL(ent.' + QUOTENAME(@AttributeColumn) + N',0),  
                                    ISNULL(dba.Code,''''),  
                                    sma.Attribute_Value_Mapped,  
                                    sma.Attribute_Value,  
                                    GETUTCDATE(),   
                                    @UserID,  
                                    GETUTCDATE(),  
                                    @UserID  
                                FROM #tblStage AS sma   
                                INNER JOIN mdm.' + QUOTENAME(@EntityTable) + ' ent' +  
                                    ' ON  sma.Member_ID = ent.ID' +  
                                    ' AND ent.Version_ID = @VersionID  
                                     AND (CASE   
                                        WHEN ent.' + QUOTENAME(@AttributeColumn) + N' IS NULL AND sma.Attribute_Value_Mapped IS NOT NULL THEN 1   
                                        WHEN ent.' + QUOTENAME(@AttributeColumn) + N' IS NOT NULL AND sma.Attribute_Value_Mapped IS NULL THEN 1   
                                        WHEN ent.' + QUOTENAME(@AttributeColumn) + N' <> sma.Attribute_Value_Mapped THEN 1   
                                        ELSE 0 END) = 1' +  
                                    ' AND sma.Entity_Table = @EntityTable  
                                     AND sma.Attribute_Name = @AttributeName   
                                LEFT OUTER JOIN mdm.' + QUOTENAME(@AttributeEntityTable) + N' dba' +  
                                    ' ON dba.ID = ent.' + QUOTENAME(@AttributeColumn) +  
                                    ' AND dba.Version_ID = @VersionID  
                                WHERE sma.STG_Status_ID = @StatusOK;';  
  
                        END; --if  
  
                        EXEC sp_executesql @SQL, @ParamList, @Version_ID, @User_ID, @EntityTable, @AttributeName, @StatusOK;  
  
                  END ELSE IF @AttributeTypeID = @SystemTypeId BEGIN --System Domain-Based Attributes  
  
                    SET @ParamList = N'@VersionID INT, @UserID INT, @EntityTable sysname, @AttributeName sysname, @StatusOK INT';  
                    SET @SQL= N'  
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
                        ) SELECT   
                            @VersionID ,  
                            COALESCE(sma.TransactionType_ID, ' + CAST(@AttributeChangedId AS NVARCHAR(1)) + N'),  
                            0,  
                            sma.Entity_ID,  
                            sma.Attribute_ID,  
                            sma.Member_ID,  
                            sma.MemberType_ID,  
                            sma.Member_Code,   
                            ISNULL(ent.' + quotename(@AttributeColumn) + N',0),  
                            ISNULL(dba.Code,''''),  
                            sma.Attribute_Value_Mapped,  
                            sma.Attribute_Value,  
                            GETUTCDATE(),  
                            @UserID,  
                            GETUTCDATE(),  
                            @UserID   
                        FROM #tblStage AS sma   
                        INNER JOIN mdm.' + QUOTENAME(@EntityTable) + N' AS ent' +  
                            N' ON  sma.Member_ID = ent.ID' +  
                            N' AND ent.Version_ID = @VersionID   
                               AND (ent.' + QUOTENAME(@AttributeColumn) + N' <> sma.Attribute_Value_Mapped OR ent.' + QUOTENAME(@AttributeColumn) + N' IS NULL)' +  
                            N' AND sma.Entity_Table = @EntityTable  
                             AND sma.Attribute_Name = @AttributeName  
                        LEFT OUTER JOIN '   
                          
                        IF @AttributeEntityTable = CAST(N'mdm.udfTransactionGetByTransactionType(2)' AS sysname)  
                            SET @SQL = @SQL + N'mdm.udfTransactionGetByTransactionType(2)';  
                        ELSE  
                            SET @SQL = @SQL + QUOTENAME(@AttributeEntityTable);  
                           
                        SET @SQL = @SQL + N' AS dba ON dba.ID = ent.' + QUOTENAME(@AttributeColumn) + N' WHERE sma.STG_Status_ID = @StatusOK;';  
                               
                        EXEC sp_executesql @SQL, @ParamList, @Version_ID, @User_ID, @EntityTable, @AttributeName, @StatusOK;  
  
                  END; --if  
  
                END; --if  
                /*  
                ------------------  
                PROCESS ATTRIBUTES   
                ------------------  
                */  
                --First, denote attribute values that have not changed (EDM-2470)  
                SET @ParamList =  N'@VersionID INT, @EntityTable sysname, @AttributeName sysname, @User_ID INT, @StatusOK INT';  
  
                SET @SQL= N'  
                    UPDATE sma SET   
                        STG_Status_ErrorCode = N''210007''  
                    FROM #tblStage AS sma   
                    INNER JOIN mdm.' + QUOTENAME(@EntityTable) + N' AS ent ON sma.Member_ID = ent.ID AND (CASE   
                        WHEN ent.' + QUOTENAME(@AttributeColumn) + N' IS NULL AND sma.Attribute_Value_Mapped IS NOT NULL THEN 1   
                        WHEN ent.' + QUOTENAME(@AttributeColumn) + N' IS NOT NULL AND sma.Attribute_Value_Mapped IS NULL THEN 1'  
                      
                    -- Look up the ID from tblUser since the Owner_ID is populated with the Username    
                    IF @AttributeColumn = 'Owner_ID'  
                        SET @SQL = @SQL + N' WHEN ent.' + QUOTENAME(@AttributeColumn) + N' <> COALESCE((SELECT ID FROM mdm.tblUser WHERE UserName = sma.Attribute_Value_Mapped), 0) THEN 1'     
                    ELSE  
                        SET @SQL = @SQL + N' WHEN ent.' + QUOTENAME(@AttributeColumn) + N' <> sma.Attribute_Value_Mapped THEN 1'     
                          
                    SET @SQL = @SQL + N'                          
                        ELSE 0 END    
                    ) = 0    
                    WHERE Version_ID = @VersionID   
                        AND sma.STG_Status_ID = @StatusOK  
                        AND sma.Entity_Table = @EntityTable  
                        AND sma.Attribute_Name = @AttributeName;';  
           
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @EntityTable, @AttributeName, @User_ID, @StatusOK;  
  
                --Then, perform a bulk update for all the members where the attribute value has changed  
                 SELECT @SQL= N'  
                    UPDATE mdm.' + QUOTENAME(@EntityTable) + N' SET '   
                      
                    -- Look up the ID from tblUser since the Owner_ID is populated with the Username, IF Owner_ID is not found, keep the old value to confirm to the foreign key constraint  
                    -- in the CN table   
                    IF @AttributeColumn = 'Owner_ID'  
                    BEGIN      
                        SET @SQL = @SQL + QUOTENAME(@AttributeColumn) + N' = COALESCE((SELECT ID FROM mdm.tblUser WHERE UserName = sma.Attribute_Value_Mapped), ent.Owner_ID)';  
                           
                    END  
                    ELSE  
                    BEGIN      
                         SET @SQL = @SQL + QUOTENAME(@AttributeColumn) + N' = sma.Attribute_Value_Mapped';  
                           
                    END; --end if  
                    SET @SQL = @SQL + N',ValidationStatus_ID = 4   
                        ,LastChgDTM = GETUTCDATE()  
                        ,LastChgUserID = @User_ID' + CASE WHEN @MemberType_ID IN(1,2) THEN N'   
                        ,ChangeTrackingMask = ISNULL(ChangeTrackingMask, 0) | ISNULL(POWER(2, sma.Attribute_ChangeTrackingGroup - 1), 0)  ' ELSE N'' END + N'  
                    OUTPUT inserted.ID INTO #tblUpdatedMembers      
                    FROM (SELECT  ROW_NUMBER() OVER(ORDER BY Stage_ID DESC) AS Sequence_ID,*  FROM #tblStage ) AS sma   
                    INNER JOIN mdm.' + QUOTENAME(@EntityTable) + N' AS ent ON sma.Member_ID = ent.ID AND (CASE   
                        WHEN ent.' + QUOTENAME(@AttributeColumn) + N' IS NULL AND sma.Attribute_Value_Mapped IS NOT NULL THEN 1   
                        WHEN ent.' + QUOTENAME(@AttributeColumn) + N' IS NOT NULL AND sma.Attribute_Value_Mapped IS NULL THEN 1'  
                      
                    -- Look up the ID from tblUser since the Owner_ID is populated with the Username    
                    IF @AttributeColumn = 'Owner_ID'  
                        SET @SQL = @SQL + N' WHEN ent.' + QUOTENAME(@AttributeColumn) + N' <> COALESCE((SELECT ID FROM mdm.tblUser WHERE UserName = sma.Attribute_Value_Mapped), 0) THEN 1'     
                    ELSE  
                        SET @SQL = @SQL + N' WHEN ent.' + QUOTENAME(@AttributeColumn) + N' <> sma.Attribute_Value_Mapped THEN 1'     
                          
                    SET @SQL = @SQL + N'                          
                        ELSE 0 END    
                    ) = 1   
                    WHERE Version_ID = @VersionID  
                    AND sma.STG_Status_ID = @StatusOK  
                    AND sma.Entity_Table =  @EntityTable  
                    AND sma.Attribute_Name = @AttributeName;';  
                      
                --PRINT @SQL;  
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @EntityTable, @AttributeName, @User_ID, @StatusOK;  
                  
                --Check for Inheritance Business Rules and update dependent members validation status.  
                --Attribute Inheritance  
                IF EXISTS (SELECT 1 FROM #tblBRAttributeInheritance) BEGIN   
                    SELECT   
                         @ChildEntityTable = ChildEntityTableName  
                        ,@ChildAttributeColumnName = ChildAttributeColumnName  
                    FROM #tblBRAttributeInheritance  
                    WHERE ParentEntityTableName = @EntityTable  
                    AND ParentAttributeColumnName = @AttributeColumn  
                      
                    IF @ChildEntityTable IS NOT NULL BEGIN  
                        --Update immediate dependent member table's validation status.  
                        SELECT @SQL = N'  
                             UPDATE   mdm.' + quotename(@ChildEntityTable) + N'  
                             SET      ValidationStatus_ID = 5  
                             FROM  mdm.' + quotename(@ChildEntityTable) + N' ch  
                                   INNER JOIN mdm.tblModelVersion dv   
                                      ON ch.Version_ID = dv.ID   
                                      AND dv.Status_ID <> 3  
                                      AND   ch.ValidationStatus_ID <> 5  
                                      AND   ch.Version_ID = @Version_ID  
                                      AND   ch.' + quotename(@ChildAttributeColumnName) + N' IN (SELECT ID FROM #tblUpdatedMembers);  
                             '  
                        EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;  
                    END -- IF  
                END -- IF  
  
                --Hierarchy Inheritance  
                IF EXISTS (SELECT 1 FROM #tblBRHierarchyInheritance) BEGIN   
                    IF CHARINDEX('_HP', @EntityTable) > 0 BEGIN  
                        SELECT TOP 1   
                             @HierarchyEntityID = i.EntityID  
                            ,@ChildAttributeColumnName = i.AttributeColumnName  
                        FROM #tblBRHierarchyInheritance i  
                        WHERE AttributeColumnName = @AttributeColumn  
                        AND   i.EntityTableName = @EntityTable  
                        ORDER BY i.HierarchyID;  
                          
                        IF @ChildAttributeColumnName IS NOT NULL BEGIN  
                            DECLARE @parentIdList mdm.IdList;  
                            INSERT INTO @parentIdList (ID) SELECT ID FROM #tblUpdatedMembers;  
                              
                            EXEC mdm.udpHierarchyMembersValidationStatusUpdate  
                                 @Entity_ID = @HierarchyEntityID  
                                ,@Version_ID = @Version_ID  
                                ,@Hierarchy_ID = NULL  
                                ,@ParentIdList = @parentIdList  
                                ,@ValidationStatus_ID = 5  
                                ,@MaxLevel = 0  
                                ,@IncludeParent = 0;  
                        END -- IF @ChildAttributeColumnName  
  
                    END -- IF _HP table  
                END  
               DELETE FROM #tblUpdatedMembers;  
                 
               -- --When Staging deletions, the Code msut be changed to a guid to it can be re-used  
               -- SELECT @SQL= N'  
                  --  UPDATE mdm.' + QUOTENAME(@EntityTable) + N' SET   
                        -- Code  =  NEWID()  
                        --,ValidationStatus_ID = 4   
                        --,LastChgDTM = GETUTCDATE()  
                        --,LastChgUserID = @User_ID  
                  --  FROM (SELECT TOP 100 PERCENT * FROM #tblStage ORDER BY Stage_ID DESC) AS sma   
                  --  INNER JOIN mdm.' + QUOTENAME(@EntityTable) + N' AS ent ON sma.Member_ID = ent.ID  
                  --  WHERE Version_ID = @VersionID  
                  --  AND sma.STG_Status_ID = @StatusOK  
                  --  AND sma.Entity_Table =  @EntityTable  
                  --  AND sma.Attribute_Name = ''Status_ID'';';  
               -- EXEC sp_executesql @SQL, @ParamList, @Version_ID, @EntityTable, @AttributeName, @User_ID;  
                 
                DELETE FROM @TableMeta WHERE ID = @MetaID;  
                  
                -- commit good records  
                IF @TranCounter = 0   
                    COMMIT TRANSACTION;  
  
            END TRY    
                      
            BEGIN CATCH    
                
                --Rollback any previously uncommitted transactions    
                IF @TranCounter = 0     
                    ROLLBACK TRANSACTION ;      
                ELSE IF XACT_STATE() <> @UncommittableTransaction       
                    ROLLBACK TRANSACTION ;     
                    
                SET @ParamList =  N'@VersionID INT, @EntityTable sysname, @AttributeName sysname, @StatusError INT, @StatusOK INT';    
                  
                --Mark the records as having an unknown exception and continue processing the rest of the batch  
                SET @SQL= N'    
                    UPDATE sma SET     
                        STG_Status_ID = @StatusError,  
                        STG_Status_ErrorCode = N''210054''    
                    FROM #tblStage AS sma    
                    INNER JOIN mdm.' + QUOTENAME(@EntityTable) + ' ent' +    
                                        ' ON  sma.Member_ID = ent.ID' +    
                                        ' AND ent.Version_ID = @VersionID    
                    WHERE sma.STG_Status_ID = @StatusOK    
                        AND sma.Entity_Table = @EntityTable    
                        AND sma.Attribute_Name = @AttributeName;';    
             
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @EntityTable, @AttributeName, @StatusError, @StatusOK;    
                  
                DELETE FROM @TableMeta WHERE ID = @MetaID;      
                   
         
            END CATCH;    
        END; --while  
  
        /*  
        ------------------------------------------------------------------------------  
        Additional updates required for member de-activation or re-activation  
        ------------------------------------------------------------------------------  
        */  
  
        DECLARE @ID int  
        DECLARE @DeactivatingMembers bit  
        DECLARE @tblStatusChangeMeta TABLE   
        (  
                ID INT IDENTITY (1, 1) NOT NULL  
                , EntityID INT  
                , EntityTable    sysname  COLLATE database_default  
                , HierarchyTable sysname COLLATE database_default NULL  
                , IsProcessed Bit  
                , DeactivatingMembers Bit  
        );  
  
        INSERT INTO @tblStatusChangeMeta  
        SELECT      
                Entity_ID,  
                Entity_Table,  
                Hierarchy_Table,   
                IsProcessed,  
                Deactivating = CASE   
                        WHEN EXISTS (SELECT 1 FROM #tblStage WHERE AttributeType_ID = @SystemTypeId AND Attribute_Name = N'Status_ID'   
                                AND Attribute_Value = N'De-Activated' AND Entity_Table = t.Entity_Table)   
                        THEN 1   
                        ELSE 0 END  
        FROM (  
            SELECT    DISTINCT  
                    Entity_ID,  
                    Entity_Table,   
                    Hierarchy_Table,   
                    0 IsProcessed  
            FROM    #tblStage  
                WHERE AttributeType_ID = @SystemTypeId  
                AND Attribute_Name = N'Status_ID'  
                AND (Attribute_Value = N'Active' OR Attribute_Value = N'De-Activated')  
                AND STG_Status_ID = @StatusOK  
        ) AS t  
  
        WHILE (SELECT COUNT(*) FROM @tblStatusChangeMeta WHERE IsProcessed = 0) > 0 BEGIN  
  
            SELECT TOP 1  
                  @ID = ID,  
                  @EntityID = EntityID,  
                  @EntityTable = EntityTable,  
                  @HierarchyTable = HierarchyTable,  
                  @DeactivatingMembers = DeactivatingMembers  
            FROM  @tblStatusChangeMeta  
            WHERE IsProcessed = 0;  
  
            IF @HierarchyTable <> N'' BEGIN  
              
                SET @ParamList =  N'@VersionID INT, @HierarchyTable sysname';  
              
                --Update The hierarchy relationship record and reset level number for recalculation  
                SET @SQL = N'  
                        UPDATE tSource SET   
                             Status_ID = tStage.Attribute_Value_Mapped  
                            ,LevelNumber = -1   
                        FROM mdm.' + QUOTENAME(@HierarchyTable) + N' AS tSource   
                        INNER JOIN #tblStage AS tStage   
                            ON tStage.Member_ID = CASE tSource.ChildType_ID WHEN 1 THEN tSource.Child_EN_ID WHEN 2 THEN tSource.Child_HP_ID END  
                        AND tStage.MemberType_ID = tSource.ChildType_ID   
                        AND tSource.Version_ID = @VersionID    
                        AND tStage.AttributeType_ID = ' + CAST(@SystemTypeId as NVARCHAR(1)) + N'   
                        AND tStage.Attribute_Name = N''Status_ID''   
                        AND tStage.Hierarchy_Table = @HierarchyTable';  
                          
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @HierarchyTable;  
  
                --Update children of consolidated nodes to Root and reset level number for recalculation  
                SET @SQL = N'  
                    UPDATE tSource SET  
                         ' + CASE WHEN @HierarchyTable LIKE N'%HR' THEN N'Parent_HP_ID = NULL' ELSE N'Parent_CN_ID = NULL' END + N'  
                        ,LevelNumber = -1   
                    FROM mdm.' + QUOTENAME(@HierarchyTable) + N' AS tSource   
                    INNER JOIN #tblStage AS tStage   
                    ON tStage.Member_ID = tSource.' + CASE WHEN @HierarchyTable LIKE N'%HR' THEN N'Parent_HP_ID' ELSE N'Parent_CN_ID' END + N'  
                    AND tStage.MemberType_ID = 2   
                    AND tSource.Version_ID = @VersionID   
                    AND tStage.AttributeType_ID = ' + CAST(@SystemTypeId as NVARCHAR(1)) + N'   
                    AND tStage.Attribute_Name = N''Status_ID''   
                    AND tStage.Hierarchy_Table = @HierarchyTable';  
                      
                EXEC sp_executesql @SQL, @ParamList, @Version_ID, @HierarchyTable;  
                  
            END; --if  
  
            --If de-activating members then delete any validation issues  
            IF @DeactivatingMembers = 1  
                DELETE FROM mdm.tblValidationLog  
                WHERE ID IN (  
                    SELECT    v.ID  
                    FROM     mdm.viw_SYSTEM_ISSUE_VALIDATION AS v INNER JOIN  
                            #tblStage AS tStage   
                                ON    v.Version_ID           = @Version_ID   
                                AND    v.Entity_ID            = @EntityID  
                                AND    v.Member_ID            = tStage.Member_ID  
                                AND v.MemberType_ID        = tStage.MemberType_ID  
                    );  
  
            UPDATE @tblStatusChangeMeta SET IsProcessed = 1 WHERE ID = @ID;  
  
        END; --while  
  
        /*  
        ----------------------  
        UPDATE STAGING RECORDS  
        ----------------------  
        Update mdm.tblStgMemberAttribute with member status  
        */  
        UPDATE tStage SET   
            Status_ID = sma.STG_Status_ID,   
            ErrorCode = sma.STG_Status_ErrorCode  
        FROM mdm.tblStgMemberAttribute AS tStage   
        INNER JOIN #tblStage sma ON sma.Stage_ID = tStage.ID;  
  
        DROP TABLE #tblStage;  
  
        SET NOCOUNT OFF;  
          
        RETURN(0);  
          
    END TRY  
    BEGIN CATCH  
          
        SET NOCOUNT OFF;  
  
        RAISERROR('MDSERR310052|An unknown error occurred when staging member attributes.', 16, 1);  
          
        RETURN(1);  
      
    END CATCH  
      
    SET NOCOUNT OFF;  
END; --proc
GO
