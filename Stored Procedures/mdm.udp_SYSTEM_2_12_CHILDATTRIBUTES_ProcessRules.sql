SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

  /*
  ==============================================================================
  Copyright (c) Microsoft Corporation. All Rights Reserved.
  ==============================================================================
  */
  CREATE PROCEDURE [mdm].[udp_SYSTEM_2_12_CHILDATTRIBUTES_ProcessRules]
    (
    
	@User_ID INT, 
	@Version_ID INT, 
	@Entity_ID INT, 
	@MemberIdList mdm.IdList READONLY, 
	@MemberType_ID INT, 
	@ProcessOptions INT
    )
    WITH EXECUTE AS CALLER
    AS BEGIN
      SET NOCOUNT ON;
       SET @User_ID = 1; -- hardcode user ID to 1, since validation should always run as a model admin
       /*------------------------------------------------------------------------------
        [auto-generated]
              This code was generated.
    
              Changes to this file may cause incorrect behavior and will be lost if
              the code is regenerated.
    
       [auto-generated]
       ------------------------------------------------------------------------------*/

      /*************************************************************
       * This procedure is the main business rule processor for an
       * entity/member type.  It makes attribute assignments, such as
       * defaulting and changing values.  It also validates attribute
       * values according to the validation rules in place.
       *************************************************************/
    
      /*************************************************************
       * Simple test harness
       *************************************************************/
      /*
      DECLARE @ProcessOptionDefault                            INT = 1;
      DECLARE @ProcessOptionChangeValue                        INT = 2;
      DECLARE @ProcessOptionAssignments                        INT = @ProcessOptionDefault | @ProcessOptionChangeValue;
      DECLARE @ProcessOptionValidation                         INT = 4;
      DECLARE @ProcessOptionExternalAction                     INT = 16;
      DECLARE @ProcessOptionLogging                            INT = 128;    
      DECLARE @ValidationOptions                               INT = @ProcessOptionAssignments | @ProcessOptionValidation | @ProcessOptionLogging;
      DECLARE
         @User_ID INT = 1,
         @Version_ID INT = ?,
         @Entity_ID INT = ?,
         @MemberType_ID INT = 1,
         @MemberIdList mdm.IdList;
    
      INSERT INTO @MemberIdList
          SELECT ID FROM mdm.[viw_SYSTEM_2_12_CHILDATTRIBUTES]
          WHERE Version_ID = @Version_ID; --Add other filtering as needed
    
      --Uncomment the following line to truncate database log
      --ALTER DATABASE {db} SET RECOVERY SIMPLE; DBCC SHRINKFILE ({db log}, 1); ALTER DATABASE {db} SET RECOVERY FULL;
    
      --The following line validates multiple members
      EXEC mdm.udp_SYSTEM_2_12_CHILDATTRIBUTES_ProcessRules @User_ID, @Version_ID, @Entity_ID, @MemberIdList, 1, @ValidationOptions;
      */
    
      /*************************************************************
       * Initialization and transaction management
       *************************************************************/
      BEGIN TRANSACTION;
      BEGIN TRY
    
      /*************************************************************
       * Create temporary tables
       *************************************************************/
      -- A local cache with the results of evaluating each business rule.  For performance reasons the conditions
      -- are evaluated only once and the results are referenced in various places in this sproc.
       CREATE TABLE #BRConditionEvaluation
       (
         [MemberID]                     INT NOT NULL
        ,[BusinessRuleID]               INT NOT NULL
        ,[IsConditionTrue]              BIT      -- 0 = False, 1 = True
        PRIMARY KEY CLUSTERED (MemberID, BusinessRuleID)
        );
        CREATE UNIQUE NONCLUSTERED INDEX #ix_BRConditionEvaluation ON #BRConditionEvaluation(BusinessRuleID, MemberID);
    
      -- A local cache with member attribute values.
      -- For performance and contention reasons the values are retrieved once and cached.
      -- The columns created will be based on the entity and attribute member type and the attributes being .
      -- referenced in the rules.
      CREATE TABLE #BRMemberData
      (
         [MemberID] INT NOT NULL PRIMARY KEY CLUSTERED
        ,[OriginalCode] nvarchar (250) Collate database_default  NULL --Needed later for processing of staging.
        ,[ChangeTrackingMask] INT NOT NULL
          ,[Name] nvarchar (250) Collate database_default  NULL
        ,[Code] nvarchar (250) Collate database_default  NULL
        ,[AddressLine1] nvarchar (100) Collate database_default  NULL
        ,[StateProvince] nvarchar (250) Collate database_default  NULL
        ,[Country] nvarchar (250) Collate database_default  NULL
        ,[PostalCode] nvarchar (100) Collate database_default  NULL
        ,[CustomerType] nvarchar (250) Collate database_default  NULL
        ,[PaymentTerms] nvarchar (250) Collate database_default  NULL
        ,[SalesDistrict] nvarchar (250) Collate database_default  NULL
        ,[AddressType] nvarchar (250) Collate database_default  NULL
        ,[City] nvarchar (100) Collate database_default  NULL
    );
    
      /*************************************************************
       * Declare, check and initialize input parameters and variables
       *************************************************************/
      /*
      Business Rule Processing Options are stored in the bits of the @ProcessOptions parameter.  Any combination can be present.
      Bits              876543210
      ===================================
      Default         = 000000001 =  1
      ChangeValue     = 000000010 =  2
      Assignment      = 000000011 =  3
      Validation      = 000000100 =  4
      UI              = 000001000 =  8
      ExternalAction  = 000010000 =  16
      Logging         = 010000000 =  128
      */
    
      DECLARE @ProcessOptionDefault                            INT = 1;
      DECLARE @ProcessOptionChangeValue                        INT = 2;
      DECLARE @ProcessOptionAssignments                        INT = @ProcessOptionDefault | @ProcessOptionChangeValue;
      DECLARE @ProcessOptionValidation                         INT = 4;
      DECLARE @ProcessOptionUI                                 INT = 8;
      DECLARE @ProcessOptionExternalAction                     INT = 16;
      DECLARE @ProcessOptionLogging                            INT = 128;
      DECLARE @doAssignments                                   BIT = 0;
      DECLARE @doValidation                                    BIT = 0;
      DECLARE @doValidationLogging                             BIT = 0;
      DECLARE @doExternalAction                                BIT = 0;
      DECLARE @stagingMergeOverwrite                           INT = 0;
      DECLARE @ValidationStatus_NewAwaitingValidation          INT = 0;
      DECLARE @ValidationStatus_AwaitingRevalidation           INT = 4;
      DECLARE @ValidationStatus_ValidationFailed               INT = 2;
      DECLARE @ValidationStatus_AwaitingDependentRevalidation  INT = 5;
      IF (ISNULL(@ProcessOptions, 0) = 0)
         SET @ProcessOptions = @ProcessOptionAssignments | @ProcessOptionValidation | @ProcessOptionLogging;
    
      SELECT @doAssignments = CASE WHEN @ProcessOptions IN ((@ProcessOptions | @ProcessOptionDefault), (@ProcessOptions | @ProcessOptionChangeValue)) THEN 1 ELSE 0 END;
      SELECT @doValidation = CASE WHEN @ProcessOptions = (@ProcessOptions | @ProcessOptionValidation) THEN 1 ELSE 0 END;
      SELECT @doValidationLogging = CASE WHEN @ProcessOptions = (@ProcessOptions | @ProcessOptionValidation | @ProcessOptionLogging) THEN 1 ELSE 0 END;
      SELECT @doExternalAction = CASE WHEN @ProcessOptions = (@ProcessOptions | @ProcessOptionExternalAction) THEN 1 ELSE 0 END;
    
      /*************************************************************
       * Populate initial data structures
       *************************************************************/
    
      /*************************************************************
       * Load values from the fact table
       *************************************************************/
      INSERT INTO #BRMemberData (
        MemberID,OriginalCode,ChangeTrackingMask,
    [Name],[Code],[AddressLine1],[StateProvince],[Country],[PostalCode],[CustomerType],[PaymentTerms],[SalesDistrict],[AddressType],[City]
       )
      SELECT
    fact.ID
        ,fact.Code
        ,fact.ChangeTrackingMask
         ,fact.[Name]
      ,CASE WHEN CHARINDEX(N'#SYS-', ISNULL(fact.[Code],N'')) > 0 THEN NULL ELSE fact.[Code] END
      ,fact.[AddressLine1]
      ,fact.[StateProvince]
      ,fact.[Country]
      ,fact.[PostalCode]
      ,fact.[CustomerType]
      ,fact.[PaymentTerms]
      ,fact.[SalesDistrict]
      ,fact.[AddressType]
      ,fact.[City]
             FROM mdm.[viw_SYSTEM_2_12_CHILDATTRIBUTES] AS fact --Main table
      INNER JOIN @MemberIdList AS m ON (fact.ID = m.ID) --MemberIDList parameter table
      WHERE fact.Version_ID = @Version_ID
      AND fact.ValidationStatus_ID IN (@ValidationStatus_NewAwaitingValidation, @ValidationStatus_AwaitingRevalidation, @ValidationStatus_AwaitingDependentRevalidation
    );
    
      /*************************************************************
       * Initialize #BRConditionEvaluation according to the IDs of the members passed in.
       * The table reflects whether the predicate for each member/BR combination us true.
       * The code makes use of advanced SQL2005 functionality such as PIVOT to make changes to all rows
       * in a single set-based pass.
       *************************************************************/
        WITH cte AS (
          SELECT MemberID
             , 0 AS [1]
           , 0 AS [2]
           , 0 AS [3]
        FROM #BRMemberData AS md
        )
        INSERT INTO #BRConditionEvaluation(MemberID, BusinessRuleID, IsConditionTrue)
        SELECT MemberID, BusinessRuleID, IsConditionTrue FROM cte
        UNPIVOT (IsConditionTrue FOR BusinessRuleID IN ([1],[2],[3])) AS unpvt;
    
        DECLARE @EntityName NVARCHAR(250),
                @IsFlat BIT,
                @EntityTable sysname,
                @HierarchyParentTable sysname,
                @CollectionTable sysname,
                @ModelName  NVARCHAR(250),
                @Model_ID INT,
                @InParams XML,
                @SendData INT,
	            @AttributeDataType TINYINT;
    
      /*************************************************************
         * Main block for Default and ChangeValue processing
         *************************************************************/
      
         SELECT  @EntityName = e.Name, @ModelName = e.Model_Name, @IsFlat = e.IsFlat, @EntityTable = EntityTable, @HierarchyParentTable = HierarchyParentTable, @CollectionTable = CollectionTable FROM mdm.viw_SYSTEM_SCHEMA_ENTITY e WHERE ID = @Entity_ID;
      
        IF @doAssignments = 1 BEGIN
          CREATE TABLE #BRAssignmentStaging
          (
           [ID] INT NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
          ,[MemberID] INT NOT NULL
          ,[MemberCode] [NVARCHAR] (250) Collate database_default NOT NULL
          ,[AttributeName] [NVARCHAR] (250) Collate database_default NOT NULL
          ,[AttributeValue] [NVARCHAR] (MAX) Collate database_default  NULL
          ,[IsChanged] [BIT] NULL
          );
          CREATE NONCLUSTERED INDEX #ix_BRAssignmentStaging_MemberCode ON #BRAssignmentStaging(MemberCode);
          CREATE NONCLUSTERED INDEX #ix_BRAssignmentStaging_IsChanged ON #BRAssignmentStaging(IsChanged);
      
        CREATE TABLE #BRAttributeValueGeneration(
           MemberID INT
          ,GeneratedValue DECIMAL(38,0) NULL
          );
      
        DECLARE @maxvalue  DECIMAL(38,0),
                  @seed      DECIMAL(38,0),
                  @incr      DECIMAL(38,0);
      
    ---------------------------------------------------------------------------------------
        -- Rule 2 Condition Evaluation: IF CustomerType is equal to 2
      ---------------------------------------------------------------------------------------
         UPDATE #BRConditionEvaluation SET
           IsConditionTrue = CASE WHEN ((( (md.[CustomerType] IS NULL AND N'2' IS NULL) OR md.[CustomerType] = N'2' ))) THEN 1 ELSE 0 END
         FROM #BRConditionEvaluation AS ce
         INNER JOIN #BRMemberData AS md ON (ce.MemberID = md.MemberID) AND ce.BusinessRuleID = 2;
    ---------------------------------------------------------------------------------------
      -- Rule 2 Assignment: PaymentTerms defaults to CASH
    ---------------------------------------------------------------------------------------
	  SELECT @AttributeDataType = DataType_ID
	  FROM [mdm].[tblAttribute] AT
	  JOIN [mdm].[tblEntity] ET
	  ON AT.Entity_ID = ET.ID
	  WHERE AT.Name = N'PaymentTerms'
	  AND ET.Name = @EntityName;
	    UPDATE  md
      SET   [PaymentTerms] = N'CASH'
        OUTPUT inserted.[MemberID], 
               inserted.[OriginalCode],     
               N'PaymentTerms', 
               inserted.[PaymentTerms], 
               CASE WHEN ISNULL( NULLIF(inserted.[PaymentTerms], 
               deleted.[PaymentTerms]),  
               NULLIF(deleted.[PaymentTerms], 
               inserted.[PaymentTerms])) IS NULL THEN 0 ELSE 1 END
        INTO #BRAssignmentStaging
      FROM    #BRMemberData AS md
      INNER JOIN #BRConditionEvaluation AS ce
        ON  md.[MemberID] = ce.[MemberID]
        AND md.[PaymentTerms] IS NULL -- defaulting so must be empty
      AND ce.[BusinessRuleID] = 2  AND ce.[IsConditionTrue] = 1
	  WHERE NOT (@AttributeDataType = 2 AND -- 2 means Number data type.
	    [mdq].[IsNumber](N'CASH') = 0);
	  -- When the attribute data type is Number (2) and the value to be assigned cannot be converted to Number don't assign the value.
    
    ---------------------------------------------------------------------------------------
        -- Rule 3 Condition Evaluation: IF CustomerType is equal to 1
      ---------------------------------------------------------------------------------------
         UPDATE #BRConditionEvaluation SET
           IsConditionTrue = CASE WHEN ((( (md.[CustomerType] IS NULL AND N'1' IS NULL) OR md.[CustomerType] = N'1' ))) THEN 1 ELSE 0 END
         FROM #BRConditionEvaluation AS ce
         INNER JOIN #BRMemberData AS md ON (ce.MemberID = md.MemberID) AND ce.BusinessRuleID = 3;
    ---------------------------------------------------------------------------------------
      -- Rule 3 Assignment: PaymentTerms defaults to 210Net30
    ---------------------------------------------------------------------------------------
	  SELECT @AttributeDataType = DataType_ID
	  FROM [mdm].[tblAttribute] AT
	  JOIN [mdm].[tblEntity] ET
	  ON AT.Entity_ID = ET.ID
	  WHERE AT.Name = N'PaymentTerms'
	  AND ET.Name = @EntityName;
	    UPDATE  md
      SET   [PaymentTerms] = N'210Net30'
        OUTPUT inserted.[MemberID], 
               inserted.[OriginalCode],     
               N'PaymentTerms', 
               inserted.[PaymentTerms], 
               CASE WHEN ISNULL( NULLIF(inserted.[PaymentTerms], 
               deleted.[PaymentTerms]),  
               NULLIF(deleted.[PaymentTerms], 
               inserted.[PaymentTerms])) IS NULL THEN 0 ELSE 1 END
        INTO #BRAssignmentStaging
      FROM    #BRMemberData AS md
      INNER JOIN #BRConditionEvaluation AS ce
        ON  md.[MemberID] = ce.[MemberID]
        AND md.[PaymentTerms] IS NULL -- defaulting so must be empty
      AND ce.[BusinessRuleID] = 3  AND ce.[IsConditionTrue] = 1
	  WHERE NOT (@AttributeDataType = 2 AND -- 2 means Number data type.
	    [mdq].[IsNumber](N'210Net30') = 0);
	  -- When the attribute data type is Number (2) and the value to be assigned cannot be converted to Number don't assign the value.
    
      /*************************************************************
         *Use staging to change the attribute values
         *************************************************************/
         DECLARE @UserName NVARCHAR(250),
                 @NewBatchID INT,
                 @LogFlag INT = NULL ,
                 @BatchName NVARCHAR(50),
                 @BatchTag NVARCHAR(50),
                 @VersionName NVARCHAR(50),
                 @stagingStatusNotRunning INT = 2,
                 @lock INT;
      
         EXEC @lock = sp_getapplock
                           @Resource=N'udp_SYSTEM_2_12_CHILDATTRIBUTES_ProcessRules',
                           @LockMode=N'Exclusive',
                           @LockOwner=N'Transaction',
                           @LockTimeout=10000,
                           @DbPrincipal=N'public';
      
         IF @lock NOT IN (0,1) BEGIN
           RAISERROR(N'Unable to acquire Lock', 16, 1);
         END
         ELSE BEGIN
      
         SELECT  @UserName = mdm.udfUserNameGetByUserID(@User_ID);      
         SELECT  @LogFlag = SettingValue FROM mdm.tblSystemSetting WHERE SettingName = 'StagingTransactionLogging';
         SELECT  @VersionName = Name FROM mdm.tblModelVersion WHERE ID = @Version_ID;
      
       --Save the entity staging batch.  Set staging staus to NotRunning so the SB queue will not process it.
         SELECT @BatchTag = NEWID(), @BatchName = N'BR Assignments';
         EXECUTE mdm.udpStagingBatchSave @User_ID, @Version_ID, NULL, NULL, @BatchName, NULL, @stagingStatusNotRunning, @BatchTag, @Entity_ID, @MemberType_ID, NULL, NULL, NULL, NULL, NULL, NULL, @NewBatchID output
      
       -- Seed staging table with Code values.
         INSERT INTO stg.[Customer_Leaf]
               (BatchTag, Batch_ID, ImportType, Code
        
        )
         SELECT DISTINCT
              @BatchTag, @NewBatchID, @stagingMergeOverwrite,brstg.MemberCode
         FROM #BRAssignmentStaging brstg
         WHERE brstg.IsChanged = 1

        -- Update stage assignment: PaymentTerms
         UPDATE  stg.[Customer_Leaf]
         SET   [PaymentTerms] = brstg.AttributeValue
         FROM    #BRAssignmentStaging AS brstg INNER JOIN stg.[Customer_Leaf] AS entstg
         ON brstg.MemberCode = entstg.Code
         AND brstg.AttributeName = N'PaymentTerms' AND brstg.IsChanged = 1
         AND brstg.ID = (SELECT MAX(ID) FROM #BRAssignmentStaging mx WHERE brstg.MemberCode = mx.MemberCode and brstg.AttributeName = mx.AttributeName);
      -- Update stage assignment: PaymentTerms
         UPDATE  stg.[Customer_Leaf]
         SET   [PaymentTerms] = brstg.AttributeValue
         FROM    #BRAssignmentStaging AS brstg INNER JOIN stg.[Customer_Leaf] AS entstg
         ON brstg.MemberCode = entstg.Code
         AND brstg.AttributeName = N'PaymentTerms' AND brstg.IsChanged = 1
         AND brstg.ID = (SELECT MAX(ID) FROM #BRAssignmentStaging mx WHERE brstg.MemberCode = mx.MemberCode and brstg.AttributeName = mx.AttributeName);
    
    
       --Process the staging batch
         EXECUTE stg.[udp_Customer_Leaf] @VersionName, @LogFlag, NULL, @NewBatchID;
        
       --Delete the entity staging batch.  
         EXECUTE mdm.udpEntityStagingFlagForClearing @NewBatchID, @User_ID;
      
         --Process clearing batch to delete the records in the entity staging table.
         EXECUTE mdm.udpStagingProcessAllReadyToRun;
      
         EXEC @lock = sp_releaseapplock
                          @Resource=N'udp_SYSTEM_2_12_CHILDATTRIBUTES_ProcessRules',
                          @DbPrincipal = N'public',
                          @LockOwner = N'Transaction';
      
         END; --if block for staging applock
      
        END; --if Main block for Default and ChangeValue processing

      /*************************************************************
       * Main block for Validation processing
       *************************************************************/
      IF @doValidation = 1 BEGIN
    
       -- Update #BRConditionEvaluation prior to validation
          UPDATE #BRConditionEvaluation SET
            IsConditionTrue = CASE BusinessRuleID
                WHEN 1 THEN 1
        END --case
          FROM #BRConditionEvaluation AS ce
          INNER JOIN #BRMemberData AS md ON (ce.MemberID = md.MemberID);
      
        CREATE TABLE #BRValidation
        (
           [MemberID] INT NOT NULL
          ,[BusinessRuleID] INT
          ,[BRItemID] INT
          ,[RuleItemText] NVARCHAR(MAX) NULL
          ,[ValidationStatusID] INT NULL
          ,[HasExistingIssue] BIT
        );
        CREATE UNIQUE NONCLUSTERED INDEX #ix_BRValidation ON #BRValidation(MemberID, BusinessRuleID, BRItemID);
    
        DECLARE @ValidationStatus_Failed     INT = 2;
        DECLARE @ValidationStatus_Succeeded  INT = 3;

        --Initially update all members in MemberCache to 'Succeeded'.
        UPDATE mdm.tbl_2_12_EN
          SET ValidationStatus_ID = @ValidationStatus_Succeeded
        FROM mdm.tbl_2_12_EN t
        INNER JOIN  #BRMemberData AS md
          ON t.ID = md.MemberID
          AND t.Version_ID = @Version_ID;

        --Get any current validation issues.
        WITH cteCurrentValidationIssues AS
        (
            SELECT
                 iss.Member_ID AS MemberID
                ,iss.BRBusinessRule_ID AS BusinessRuleID
                ,iss.BRItem_ID AS BRItemID
            FROM mdm.viw_SYSTEM_ISSUE_VALIDATION iss
            INNER JOIN #BRMemberData AS md
                ON md.MemberID = iss.Member_ID
                AND iss.Version_ID = @Version_ID
        ),
    
        cteGetValidations AS
        (
        --Need this empty result to ensure the SQL is correct in case there are no validations.
        SELECT
            0 AS MemberID
           ,0 AS BusinessRuleID
           ,0 AS BRItemID
           ,N'' AS RuleItemText
           ,0 AS IsConditionTrue
           ,0 AS IsRuleBroken
           ,0 AS HasExistingIssue

     UNION
    ---------------------------------------------------------------------------------------
      -- Rule 1 Validation: Name is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,1 AS BusinessRuleID
                ,1 AS BRItemID
                ,N'Name is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([Name], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 1
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 1 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 1 Validation: AddressLine1 is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,1 AS BusinessRuleID
                ,2 AS BRItemID
                ,N'AddressLine1 is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([AddressLine1], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 1
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 2 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 1 Validation: City is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,1 AS BusinessRuleID
                ,3 AS BRItemID
                ,N'City is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([City], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 1
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 3 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 1 Validation: StateProvince is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,1 AS BusinessRuleID
                ,4 AS BRItemID
                ,N'StateProvince is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([StateProvince], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 1
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 4 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 1 Validation: Country is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,1 AS BusinessRuleID
                ,5 AS BRItemID
                ,N'Country is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([Country], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 1
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 5 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 1 Validation: PostalCode is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,1 AS BusinessRuleID
                ,6 AS BRItemID
                ,N'PostalCode is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([PostalCode], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 1
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 6 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 1 Validation: CustomerType is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,1 AS BusinessRuleID
                ,7 AS BRItemID
                ,N'CustomerType is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([CustomerType], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 1
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 7 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 1 Validation: SalesDistrict is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,1 AS BusinessRuleID
                ,8 AS BRItemID
                ,N'SalesDistrict is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([SalesDistrict], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 1
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 8 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 1 Validation: AddressType is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,1 AS BusinessRuleID
                ,9 AS BRItemID
                ,N'AddressType is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([AddressType], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 1
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 9    ),
        cteGetIssues AS
        (
        SELECT
            MemberID
           ,BusinessRuleID
           ,BRItemID
           ,RuleItemText
           ,CASE
               WHEN IsConditionTrue=0 AND HasExistingIssue=1 THEN @ValidationStatus_Succeeded
               WHEN IsConditionTrue=1 AND IsRuleBroken=0 AND HasExistingIssue=1 THEN @ValidationStatus_Succeeded
               WHEN IsConditionTrue=1 AND IsRuleBroken=1 THEN @ValidationStatus_Failed
               ELSE 0
            END AS ValidationStatusID
           ,HasExistingIssue
        FROM cteGetValidations
        WHERE BusinessRuleID <> 0
        )
        INSERT INTO #BRValidation
           (MemberID, BusinessRuleID, BRItemID, RuleItemText, ValidationStatusID, HasExistingIssue)
        SELECT
            MemberID
           ,BusinessRuleID
           ,BRItemID
           ,RuleItemText
           ,ValidationStatusID
           ,HasExistingIssue
        FROM cteGetIssues
        WHERE ValidationStatusID IN (@ValidationStatus_Succeeded, @ValidationStatus_Failed);


      --Update all members with failed validation issues to @ValidationStatus_Failed
        UPDATE mdm.tbl_2_12_EN
        SET ValidationStatus_ID = v.ValidationStatusID
        FROM mdm.tbl_2_12_EN AS t
        INNER JOIN #BRValidation AS v
            ON t.ID = v.MemberID
        WHERE t.Version_ID = @Version_ID
        AND v.ValidationStatusID = @ValidationStatus_Failed;

        -- Create validation issues for any validation errors
        IF @doValidationLogging = 1 BEGIN
            IF EXISTS(SELECT 1 FROM #BRValidation) BEGIN

                INSERT INTO mdm.tblValidationLog
                   (Version_ID, Hierarchy_ID, Entity_ID, Member_ID, MemberCode, MemberType_ID,
                    BRBusinessRule_ID, BRItem_ID, [Description], Status_ID,
                    EnterUserID, LastChgUserID)
                SELECT
                     t.[Version_ID]
    
                    ,0
      
                    , @Entity_ID
                    , t.[ID]
                    , t.[Code]
                    , @MemberType_ID
                    , v.[BusinessRuleID]
                    , v.[BRItemID]
                    , v.[RuleItemText]
                    , CASE WHEN v.[ValidationStatusID] = @ValidationStatus_Failed THEN 1 ELSE 0 END
                    , @User_ID
                    , @User_ID
                FROM #BRValidation AS v
                INNER JOIN mdm.tbl_2_12_EN AS t
                    ON v.MemberID = t.ID
                    AND t.[Version_ID] = @Version_ID
                    AND (v.ValidationStatusID = @ValidationStatus_Succeeded OR (v.ValidationStatusID = @ValidationStatus_Failed AND v.HasExistingIssue = 0));

            END; --if Validation issue to log
        END; --if Logging
      END; --if Validation
    
      /*************************************************************
       * Zero out change tracking mask on processed members
       *************************************************************/
       UPDATE mdm.[tbl_2_12_EN] SET
         [ChangeTrackingMask] = 0
       FROM #BRMemberData AS md
       INNER JOIN mdm.[tbl_2_12_EN] AS fact
         ON md.[MemberID]= fact.[ID] AND fact.[Version_ID] = @Version_ID
       WHERE md.[ChangeTrackingMask] <> 0
      /*************************************************************
       * Structured error and transaction Handling
       *************************************************************/
      COMMIT TRANSACTION;
      RETURN(0);
      END TRY
      BEGIN CATCH --Compensate as necessary
          -- Get error info
          DECLARE
             @ErrorMessage NVARCHAR(4000),
             @ErrorSeverity INT,
             @ErrorState INT;
          EXEC mdm.udpGetErrorInfo
             @ErrorMessage = @ErrorMessage OUTPUT,
             @ErrorSeverity = @ErrorSeverity OUTPUT,
             @ErrorState = @ErrorState OUTPUT;
        IF XACT_STATE() <> -1 ROLLBACK TRANSACTION;
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN(1);
      END CATCH;

    SET NOCOUNT OFF;
  END; --proc
GO
