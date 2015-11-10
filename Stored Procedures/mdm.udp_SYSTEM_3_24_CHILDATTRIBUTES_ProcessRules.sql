SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

  /*
  ==============================================================================
  Copyright (c) Microsoft Corporation. All Rights Reserved.
  ==============================================================================
  */
  CREATE PROCEDURE [mdm].[udp_SYSTEM_3_24_CHILDATTRIBUTES_ProcessRules]
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
          SELECT ID FROM mdm.[viw_SYSTEM_3_24_CHILDATTRIBUTES]
          WHERE Version_ID = @Version_ID; --Add other filtering as needed
    
      --Uncomment the following line to truncate database log
      --ALTER DATABASE {db} SET RECOVERY SIMPLE; DBCC SHRINKFILE ({db log}, 1); ALTER DATABASE {db} SET RECOVERY FULL;
    
      --The following line validates multiple members
      EXEC mdm.udp_SYSTEM_3_24_CHILDATTRIBUTES_ProcessRules @User_ID, @Version_ID, @Entity_ID, @MemberIdList, 1, @ValidationOptions;
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
        ,[ProductSubCategory] nvarchar (250) Collate database_default  NULL
        ,[Color] nvarchar (250) Collate database_default  NULL
        ,[Country] nvarchar (250) Collate database_default  NULL
        ,[StandardCost] decimal (38,2) NULL
        ,[SafetyStockLevel] decimal (38,0) NULL
        ,[ReorderPoint] decimal (38,0) NULL
        ,[MSRP] decimal (38,4) NULL
        ,[DaysToManufacture] decimal (38,0) NULL
        ,[DealerCost] decimal (38,2) NULL
        ,[SellStartDate] datetime2 NULL
        ,[InHouseManufacture] nvarchar (250) Collate database_default  NULL
        ,[FinishedGoodIndicator] nvarchar (250) Collate database_default  NULL
        ,[ProductLine] nvarchar (250) Collate database_default  NULL
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
    [Name],[Code],[ProductSubCategory],[Color],[Country],[StandardCost],[SafetyStockLevel],[ReorderPoint],[MSRP],[DaysToManufacture],[DealerCost],[SellStartDate],[InHouseManufacture],[FinishedGoodIndicator],[ProductLine]
       )
      SELECT
    fact.ID
        ,fact.Code
        ,fact.ChangeTrackingMask
         ,fact.[Name]
      ,CASE WHEN CHARINDEX(N'#SYS-', ISNULL(fact.[Code],N'')) > 0 THEN NULL ELSE fact.[Code] END
      ,fact.[ProductSubCategory]
      ,fact.[Color]
      ,fact.[Country]
      ,fact.[StandardCost]
      ,fact.[SafetyStockLevel]
      ,fact.[ReorderPoint]
      ,fact.[MSRP]
      ,fact.[DaysToManufacture]
      ,fact.[DealerCost]
      ,fact.[SellStartDate]
      ,fact.[InHouseManufacture]
      ,fact.[FinishedGoodIndicator]
      ,fact.[ProductLine]
             FROM mdm.[viw_SYSTEM_3_24_CHILDATTRIBUTES] AS fact --Main table
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
             , 0 AS [4]
           , 0 AS [5]
           , 0 AS [6]
           , 0 AS [7]
        FROM #BRMemberData AS md
        )
        INSERT INTO #BRConditionEvaluation(MemberID, BusinessRuleID, IsConditionTrue)
        SELECT MemberID, BusinessRuleID, IsConditionTrue FROM cte
        UNPIVOT (IsConditionTrue FOR BusinessRuleID IN ([4],[5],[6],[7])) AS unpvt;
    
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
       * Main block for Validation processing
       *************************************************************/
      IF @doValidation = 1 BEGIN
    
       -- Update #BRConditionEvaluation prior to validation
          UPDATE #BRConditionEvaluation SET
            IsConditionTrue = CASE BusinessRuleID
                WHEN 4 THEN 1
            WHEN 5 THEN CASE WHEN ((( (md.[InHouseManufacture] IS NULL AND N'Y' IS NULL) OR md.[InHouseManufacture] = N'Y' ))) THEN 1 ELSE 0 END
              WHEN 6 THEN 1
            WHEN 7 THEN CASE WHEN ((( (md.[FinishedGoodIndicator] IS NULL AND N'Y' IS NULL) OR md.[FinishedGoodIndicator] = N'Y' ))) THEN 1 ELSE 0 END
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
        UPDATE mdm.tbl_3_24_EN
          SET ValidationStatus_ID = @ValidationStatus_Succeeded
        FROM mdm.tbl_3_24_EN t
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
      -- Rule 4 Validation: Name is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,14 AS BRItemID
                ,N'Name is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([Name], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 14 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 4 Validation: ProductSubCategory is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,15 AS BRItemID
                ,N'ProductSubCategory is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([ProductSubCategory], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 15 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 4 Validation: Color is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,16 AS BRItemID
                ,N'Color is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([Color], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 16 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 4 Validation: Country is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,17 AS BRItemID
                ,N'Country is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([Country], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 17 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 4 Validation: StandardCost is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,18 AS BRItemID
                ,N'StandardCost is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    [StandardCost] IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 18 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 4 Validation: SafetyStockLevel is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,19 AS BRItemID
                ,N'SafetyStockLevel is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    [SafetyStockLevel] IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 19 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 4 Validation: ReorderPoint is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,20 AS BRItemID
                ,N'ReorderPoint is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    [ReorderPoint] IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 20 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 4 Validation: InHouseManufacture is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,21 AS BRItemID
                ,N'InHouseManufacture is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([InHouseManufacture], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 21 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 4 Validation: SellStartDate is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,22 AS BRItemID
                ,N'SellStartDate is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    [SellStartDate] IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 22 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 4 Validation: FinishedGoodIndicator is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,23 AS BRItemID
                ,N'FinishedGoodIndicator is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([FinishedGoodIndicator], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 23 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 4 Validation: ProductLine is required 
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,4 AS BusinessRuleID
                ,24 AS BRItemID
                ,N'ProductLine is required ' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    NULLIF([ProductLine], N'') IS NOT NULL THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 4
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 24 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 5 Validation: DaysToManufacture must be between 1 and 10
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,5 AS BusinessRuleID
                ,25 AS BRItemID
                ,N'DaysToManufacture must be between 1 and 10' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    md.[DaysToManufacture] BETWEEN 1 AND 10 THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 5
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 25 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 6 Validation: StandardCost must be greater than 0
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,6 AS BusinessRuleID
                ,27 AS BRItemID
                ,N'StandardCost must be greater than 0' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    md.[StandardCost] > 0 THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 6
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 27 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 7 Validation: MSRP must be greater than 0
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,7 AS BusinessRuleID
                ,28 AS BRItemID
                ,N'MSRP must be greater than 0' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    md.[MSRP] > 0 THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 7
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 28 UNION
    ---------------------------------------------------------------------------------------
      -- Rule 7 Validation: DealerCost must be greater than 0
    ---------------------------------------------------------------------------------------
            SELECT
                 md.MemberID
                ,7 AS BusinessRuleID
                ,29 AS BRItemID
                ,N'DealerCost must be greater than 0' AS RuleItemText
                ,ce.IsConditionTrue
                ,CASE WHEN 
    md.[DealerCost] > 0 THEN 0 ELSE 1 END AS IsRuleBroken
                ,CASE WHEN iss.MemberID IS NOT NULL THEN 1 ELSE 0 END AS HasExistingIssue
            FROM    #BRMemberData AS md
            INNER JOIN #BRConditionEvaluation AS ce
                ON  md.[MemberID] = ce.[MemberID]
                AND ce.[BusinessRuleID] = 7
            LEFT JOIN cteCurrentValidationIssues iss
                ON  ce.[MemberID] = iss.[MemberID]
                AND iss.[BusinessRuleID] = ce.[BusinessRuleID]
                AND iss.BRItemID = 29    ),
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
        UPDATE mdm.tbl_3_24_EN
        SET ValidationStatus_ID = v.ValidationStatusID
        FROM mdm.tbl_3_24_EN AS t
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
                INNER JOIN mdm.tbl_3_24_EN AS t
                    ON v.MemberID = t.ID
                    AND t.[Version_ID] = @Version_ID
                    AND (v.ValidationStatusID = @ValidationStatus_Succeeded OR (v.ValidationStatusID = @ValidationStatus_Failed AND v.HasExistingIssue = 0));

            END; --if Validation issue to log
        END; --if Logging
      END; --if Validation
    
      /*************************************************************
       * Zero out change tracking mask on processed members
       *************************************************************/
       UPDATE mdm.[tbl_3_24_EN] SET
         [ChangeTrackingMask] = 0
       FROM #BRMemberData AS md
       INNER JOIN mdm.[tbl_3_24_EN] AS fact
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
