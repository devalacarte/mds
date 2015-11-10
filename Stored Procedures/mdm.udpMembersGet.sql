SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    THIS SPROC (IN THEORY) SHOULD ONLY BE CALLED BY udpEntityMembersGet.   
    Nothign in the application calls this directly.  
     
    --examples  
    --/Account/Version3/Account  
    DECLARE @SearchTable    mdm.MemberGetCriteria  
    exec mdm.udpMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=NULL,@Entity_ID=6,@Parent_ID=NULL,@Member_ID=NULL,@MemberType_ID=1,@Attribute_ID=NULL,@AttributeValue=NULL,@PageNumber=NULL,@PageSize=NULL,@SortColumn=NULL,@SortDirection=NULL,@SearchTable=@SearchTable,@AttributeGroup_ID=NULL,@CountOnly=0,@IDOnly=0,@ColumnString=NULL  
     
     
*/  
CREATE PROCEDURE [mdm].[udpMembersGet]  
(  
    @User_ID            INT,  
    @Version_ID         INT,  
    @Hierarchy_ID       INT,  
    @HierarchyType_ID   INT = NULL,  
    @Entity_ID          INT,  
    @Parent_ID          INT = NULL,  
    @Member_ID          INT = NULL,  
    @MemberType_ID      TINYINT,  
    @Attribute_ID       INT = NULL,  
    @AttributeValue     INT = NULL,  
    @PageNumber         INT = NULL,  
    @PageSize           INT = NULL, -- Null: use system setting, <=0: return all records, X: return X records.  
    @SortColumn         sysname = NULL,  
    @SortDirection      NVARCHAR(4) = NULL,  
    @SearchTable        mdm.MemberGetCriteria READONLY,  
    @AttributeGroup_ID  INT = NULL,  
    @MemberReturnOption INT = 5, -- Data & membership information  
    @IDOnly             BIT = 0,  
    @ColumnString       NVARCHAR(MAX) = NULL,  
    @MemberCount        INT = NULL OUTPUT  
)  
WITH EXECUTE AS N'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
     
    DECLARE @SQL                            NVARCHAR(MAX),  
            @ViewName                       NVARCHAR(262),  
            @ViewNameRaw                    NVARCHAR(262),  
            @RealViewNameRaw                NVARCHAR(262),  
            @TableName                      NVARCHAR(262),  
            @SecurityTable                  NVARCHAR(262),  
            @LeafTable                      NVARCHAR(262),  
            @StartRow                       INT,  
            @EndRow                         INT,  
            @Model_ID                       INT,  
            @Privilege_ID                   INT,  
            @Securable_ID                   INT,  
            @Object_ID                      INT,  
            @RootSecured                    BIT,  
            @IsFlatEntity                   BIT,  
            @Mode                           INT,  
            @MemberType_Leaf                TINYINT = 1,  
            @MemberType_Consolidated        TINYINT = 2,  
            @MemberType_Collection          TINYINT = 3,  
            @UseMemberSecurity              INT, --0=No,1=Yes,2=LeafOnly  
            @UserMemberSecurity_No          INT = 0,  
            @UserMemberSecurity_Yes         INT = 1,  
            @UserMemberSecurity_LeafOnly    INT = 2,  
            @Root_ID                        INT = 0,  
            @SortOrderColumn                sysname,  
            @SortOrderColumnQuoted          NVARCHAR(300),  
            @SortColumnQuoted               NVARCHAR(300),  
            @SearchTerm                     NVARCHAR(MAX),  
            @FullSearchTerm                 NVARCHAR(MAX),  
            @MemberSecurityCTE              NVARCHAR(MAX),  
            @PageCTEOrder                   NVARCHAR(MAX),  
            @PageGetQuery                   NVARCHAR(MAX),  
            @MemberDetailsQuery             NVARCHAR(MAX),  
            @MemberDetailsRawQuery          NVARCHAR(MAX),  
            @ViewNameToUse			        NVARCHAR(MAX),  
            @SQLSuffixToUse			        NVARCHAR(MAX),  
            @IsExplicitHierarchy            BIT,  
            @AttributesRequired             BIT = 1,  
            @DerivedHierarchyTypeId         INT = 1,  
            @MemberStatusActive             NVARCHAR(1) = '1',  
            @MemberReturnOptionData			TINYINT = 1,  
            @MemberReturnOptionCount		TINYINT = 2,  
            @MemberReturnOptionMembershipInformation TINYINT = 4,  
            @CountOnly						BIT;  
              
    SET @CountOnly = CASE WHEN (@MemberReturnOption & @MemberReturnOptionCount) <> 0 THEN 1 ELSE 0 END;  
     
    DECLARE @e                      sysname;  
  
    --Set a flag to identify an explicit hierarchy.   
    SET @IsExplicitHierarchy = CASE WHEN @Hierarchy_ID IS NOT NULL AND (COALESCE(@HierarchyType_ID, 0) = 0) THEN 1 ELSE 0 END;  
  
    SET @e = OBJECT_NAME(@@PROCID);  
  
    SELECT   
        @Model_ID       = e.Model_ID,  
        @IsFlatEntity   = e.IsFlat  
    FROM mdm.tblEntity AS e INNER JOIN mdm.tblModelVersion AS mv ON e.Model_ID = mv.Model_ID  
    WHERE e.ID = @Entity_ID AND mv.ID = @Version_ID;  
     
    SET @PageSize = COALESCE(@PageSize, (SELECT SettingValue FROM mdm.tblSystemSetting WHERE SettingName = CAST(N'RowsPerBatch' AS NVARCHAR(100))))     
  
    -- ensure @PageNumber is >= 1.  
    IF COALESCE(@PageNumber, 0) < 1 SET @PageNumber = 1;       
             
    --Initialize variables  
    SELECT  
        @SQL                = CAST(N'' AS NVARCHAR(max)),  
        @ColumnString       = NULLIF(@ColumnString, N''),  
        @SortColumn         = NULLIF(NULLIF(@SortColumn, N''), N'ID'), -- already sorting by ID after the specified sort column  
        @SortDirection      = ISNULL(NULLIF(UPPER(@SortDirection), N''), N'ASC'),  
        @UseMemberSecurity  = @UserMemberSecurity_No;  
        
    --Initialize dependant variables  
    SELECT  
        @SortOrderColumn    = @SortColumn,  
        @StartRow           = (@PageNumber - 1) * (@PageSize) + 1,  
        @EndRow             = @StartRow + @PageSize - 1;  
  
    --Test for invalid parameters  
    IF (@Model_ID IS NULL)  
        OR (UPPER(@SortDirection) NOT IN (N'ASC', N'DESC')) --Invalid @SortDirection  
        OR (@CountOnly = 1 AND (@MemberReturnOption & (@MemberReturnOptionData | @MemberReturnOptionMembershipInformation) <> 0)) -- Requesting data and counts together is not supported.  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
  
    IF (COALESCE(@MemberType_ID, 0) NOT IN (@MemberType_Leaf, @MemberType_Consolidated, @MemberType_Collection))  
    BEGIN  
        RAISERROR('MDSERR100002|The Member Type is not valid.', 16, 1);  
        RETURN;  
    END     
  
    IF (@IsFlatEntity = 1 AND COALESCE(@MemberType_ID, 0) <> @MemberType_Leaf)  
    BEGIN  
        RAISERROR('MDSERR300035|The member type is not valid. Flat entities have only leaf members.', 16, 1);  
        RETURN;  
    END     
  
    --Silly, but no way to inject with this.  
    SET @SortDirection = CASE WHEN UPPER(@SortDirection) = N'ASC' THEN N'ASC' ELSE N'DESC' END  
     
    /*  
    convert @SearchTerm into something that is injection safe.  
    */  
    IF EXISTS (SELECT 1 FROM @SearchTable)  
    BEGIN  
        DECLARE @maxFilterCount     INT,  
                @groupID            INT,  
                @schemaName         sysname,  
                @objectName         sysname,  
                @fullObjectName     NVARCHAR(MAX),  
                @operator           NVARCHAR(15),  
                @operatorParameters NVARCHAR(MAX),  
                @filterValue        NVARCHAR(MAX),  
                @filterClause       NVARCHAR(MAX),  
                @currentGroup       INT,  
                @CurrentFilterId    INT,  
                @matchOrderBy       NVARCHAR(MAX),  
                @regexMask          INT = mdq.RegexMask(1, 1, 1, 0, 0, 0, 1); --CultureInvariant, ExplicitCapture, IgnoreCase, SingleLine (71)  
          
        --This table variable is used to keep track of unique filters in the search table. A set of records  
        --in the search table that belong to the same group (by way of having the same group ID) are considered  
        --one unique filter and are processed as such. However, records having a group ID of 0 are each considered  
        --their own separate unique filter. For example a search table like:  
        --INSERT INTO @SearchTable(ID,  SchemaName, ObjectName,     Operator,   OperatorParameters, GroupId,    [Value])  
        --                  values(1,   N'',        N'Name',        N'=',       N'',                0,          N'NewMember'),  
        --                        (2,   N'',        N'ModelName',   N'LIKE',    N'',                0,          N'%Premium'),  
        --                        (3,   N'',        N'SubCategory', N'IN',      N'',                1,          N'12'),  
        --                        (4,   N'',        N'SubCategory', N'IN',      N'',                1,          N'14'),  
        --                        (5,   N'',        N'SubCategory', N'IN',      N'',                1,          N'31'),  
        --                        (6,   N'',        N'SubCategory', N'IN',      N'',                1,          N'2'),  
        --                        (7,   N'',        N'Color',       N'IN',      N'',                2,          N'Silver'),  
        --                        (8,   N'',        N'Color',       N'IN',      N'',                2,          N'Yellow')  
        --  
        --would amount to 4 unique filters  
        DECLARE @UniqueFilters TABLE(FilterId INT PRIMARY KEY, Processed BIT DEFAULT 0);  
                 
        SET @currentGroup = 0;  
        SET @SearchTerm = N'';  
  
        --Get filters with no GroupId in as unique filter  
        INSERT INTO @UniqueFilters(FilterId)  
        SELECT ID FROM @SearchTable WHERE GroupId = 0;  
  
        --Pick out the lowest ID for a group and stuff it into UniqueFilters  
        INSERT INTO @UniqueFilters(FilterId)  
        SELECT MIN(ID) FROM @SearchTable   
        WHERE GroupId <> 0  
        GROUP BY GroupId;  
  
        --Count out the total number of unique filters  
        SELECT @maxFilterCount = COUNT(1) from @UniqueFilters;  
  
        --Restrict the number of filters supported to a maximum of 100  
        IF @maxFilterCount > 100  
        BEGIN  
            RAISERROR('MDSERR100046|A maximum of 100 filter criteria are supported.', 16, 1);  
            RETURN;  
        END  
  
        --Build filter clause using table param for joins  
        WHILE EXISTS(SELECT 1 FROM @UniqueFilters WHERE Processed = 0)  
        BEGIN  
            SET @filterClause = NULL;     
            SELECT TOP 1  
                 @CurrentFilterId = UF.FilterId  
                ,@operator = UPPER(LTRIM(RTRIM(COALESCE(ST.Operator, N''))))  
                ,@filterValue = ST.[Value]  
                ,@groupID = ST.GroupId  
                ,@schemaName = LTRIM(RTRIM(COALESCE(ST.SchemaName, N'')))  
                ,@objectName = LTRIM(RTRIM(COALESCE(ST.ObjectName, N'')))  
                ,@operatorParameters = UPPER(LTRIM(RTRIM(COALESCE(ST.OperatorParameters, N''))))  
            FROM @UniqueFilters UF  
            INNER JOIN @SearchTable ST ON ST.ID = UF.FilterId  
            WHERE UF.Processed = 0;  
  
            --Validate the filter value if it is non-null  
            IF @filterValue IS NOT NULL  
            BEGIN  
                --Filter values larger than 255 chars are not allowed  
                IF (LEN(@filterValue) > 255)  
                    BEGIN  
                        RAISERROR('MDSERR100045|Filter criteria values can not be larger than 255 characters.', 16, 1);  
                        RETURN;  
                    END  
  
                --Replace any single quotes with double quotes to avoid SQL injection  
                SET @filterValue = REPLACE(@filterValue, '''', '''''');  
            END  
  
            SET @fullObjectName = CASE WHEN LEN(@schemaName) > 0 THEN QUOTENAME(@schemaName) + N'.' ELSE N'' END +   
                                  CASE WHEN @objectName = 'ValidationStatus_ID' THEN 'T.[ValidationStatus_ID]' ELSE QUOTENAME(@objectName) END;  
  
            DECLARE @isOperatorNegated  BIT = mdq.RegexIsMatch(@operator, N'NOT ', @regexMask),  
                    @isOperatorFuzzy    BIT = mdq.RegexIsMatch(@operator, N'^(NOT )?MATCH$', @regexMask),  
                    @isOperatorRegex    BIT = mdq.RegexIsMatch(@operator, N'^(NOT )?REGEX$', @regexMask),  
                    @isOperatorIsNull   BIT = mdq.RegexIsMatch(@operator, N'^IS (NOT )?NULL$', @regexMask),  
                    @isOperatorIn       BIT = mdq.RegexIsMatch(@operator, N'^(NOT )?IN$', @regexMask);  
            DECLARE @isOperatorValid    BIT = CASE WHEN @operator IN (  
                             N'='  
                            ,N'<>'  
                            ,N'LIKE'  
                            ,N'NOT LIKE'  
                            ,N'>'  
                            ,N'<'  
                            ,N'>='  
                            ,N'<=')  
                            OR @isOperatorFuzzy = 1  
                            OR @isOperatorRegex = 1  
                            OR @isOperatorIsNull = 1  
                            OR @isOperatorIn = 1  
                            THEN 1 ELSE 0 END;  
  
            IF (@isOperatorValid = 1  
                AND LEN(@fullObjectName) > 0  
                AND (@currentGroup <> @groupID OR @groupID = 0))  
            BEGIN  
                SET @currentGroup = @groupID;                 
                 
                IF (@isOperatorFuzzy = 1)  
                BEGIN  
                     
                    -- do fuzzy match  
                    /*  
                     * Fuzzy matching requires operator parameters in this format: 'minSimilarity[ algorithm][ containmentBias]'  
                     *  
                     * minSimilarity: 0 <= value <= 1. Used by all algorithms.  
                     * algorithm:   
                     *      - 0 = Levenstein (default)  
                     *      - 1 = Jaccard  
                     *      - 2 = JaroWinkler  
                     *      - 3 = Longest Common Subsequence  
                     * lengthThreshold 0 <= value <= 1. Default = 0.62. Used only by Jaccard and Longest Common Subsequence algorithms.  
                     *  
                     * Example: '0.5 1 0.32' means use Jaccard algorithm with minSimilarity = 0.5 and containmentBias = 0.32  
                     */  
                    DECLARE @Levenstein  NVARCHAR(1)              = N'0',  
                            @Jaccard     NVARCHAR(1)              = N'1',  
                            @JaroWinkler NVARCHAR(1)              = N'2',  
                            @LongestCommonSubsequence NVARCHAR(1) = N'3',  
                            @numericPattern NVARCHAR(100) = N'(\d*(\.\d+)?)';  
                    DECLARE @pattern NVARCHAR(100) = N'^(?<minSimilarity>' + @numericPattern + N')( +(?<algorithm>(\d)))?( +(?<containmentBias>' + @numericPattern + N'))?',  
                            @defaultAlgorithm NVARCHAR(1) = @Levenstein,  
                            @defaultLengthThreshold NVARCHAR(10) = N'0.62';  
                    DECLARE @minSimilarity NVARCHAR(100) = mdq.RegexExtract(@operatorParameters, @pattern, N'minSimilarity', @regexMask),  
                            @algorithm NVARCHAR(1) = COALESCE(NULLIF(mdq.RegexExtract(@operatorParameters, @pattern, N'algorithm', @regexMask), N''), @defaultAlgorithm),                             
                            @lengthThreshold NVARCHAR(100) = COALESCE(NULLIF(mdq.RegexExtract(@operatorParameters, @pattern, N'containmentBias', @regexMask), N''), @defaultLengthThreshold);  
                             
                    -- validate parameters  
                    IF (ISNUMERIC(@minSimilarity) = 0)    
                    BEGIN  
                        RAISERROR('MDSERR100032|You must provide a valid similarity value for the fuzzy match operation.', 16, 1);  
                        RETURN;  
                    END  
                    IF (@algorithm NOT IN (@Levenstein, @Jaccard, @JaroWinkler, @LongestCommonSubsequence))  
                    BEGIN  
                        RAISERROR('MDSERR100033|You must provide a valid fuzzy match algorithm code.', 16, 1);  
                        RETURN;  
                    END  
                    IF (ISNUMERIC(@lengthThreshold) = 0)  
                    BEGIN  
                        RAISERROR('MDSERR100034|You must provide a valid containment bias value.', 16, 1);  
                        RETURN;  
                    END                     
  
                    SET @filterClause = N'mdq.Similarity(' + @fullObjectName  
                        + N', N''' + @filterValue  
                        + N''', ' + @algorithm     
                        + N', ' + @lengthThreshold  
                        + N', '  
                        + CASE @isOperatorNegated  
                                WHEN 0 THEN @minSimilarity  
                                ELSE N'0.0'  
                        END --case  
                        + N')';  
                         
                    --Add the match expression to the custom ORDER BY clause  
                    SET @matchOrderBy =  
                        CASE  
                            WHEN @matchOrderBy IS NULL THEN N''  
                            ELSE @matchOrderBy + N' + '  
                        END  
                        + N'  
                        '  
                        + CASE @isOperatorNegated  
                            WHEN 0 THEN @filterClause  
                            WHEN 1 THEN N'(1.0 - ' + @filterClause + N')'  
                        END; --case  
                         
                    --Complete the rest of the predicate  
                    SET @filterClause =  
                        N'('  
                        + @filterClause  
                        + CASE @isOperatorNegated  
                            WHEN 0 THEN N' >= '  
                            WHEN 1 THEN N' < '  
                        END --case  
                        + @minSimilarity  
                        + N')';  
                         
                END   
                ELSE IF (@isOperatorRegex = 1)  
                BEGIN  
                     
                    -- do regular expression match  
                     
                    -- This if statement is commented out because, for now, the desired behavior for an invalid  
                    -- regular expression is to allow an exception to be thrown when it is parsed.  
                    --IF (mdq.RegexIsValid(@filterValue) = 1)  
                    --BEGIN  
                    SET @filterClause = N'(mdq.RegexIsMatch(' + @fullObjectName + N', N''' + @filterValue + N''', ' + CONVERT(NVARCHAR(MAX), @regexMask) + N') '  
                    + CASE @isOperatorNegated  
                        WHEN 0 THEN N'='  
                        WHEN 1 THEN N'<>'  
                        END  
                    + N' 1)';  
                    --END  
                END   
                ELSE IF (@isOperatorIsNull = 1)  
                    BEGIN  
                        SET @filterClause = @fullObjectName + N' ' + @operator;  
                    END  
                ELSE IF (@isOperatorIn = 1)  
                    BEGIN  
                        SET @filterClause = @fullObjectName + N' ' + @operator + N' (SELECT [Value] FROM @SearchTable WHERE GroupId = ' + CONVERT(NVARCHAR(100), @groupID) + N')';  
                    END  
                ELSE  
                    BEGIN                     
                        SET @filterClause = @fullObjectName + N' ' + @operator + N' N''' + @filterValue + N'''';  
                    END  
                                 
                IF @filterClause IS NOT NULL  
                BEGIN  
                    IF LEN(@SearchTerm) <> 0  
                    BEGIN  
                        SET @SearchTerm = @SearchTerm + N'  
                            AND ';  
                    END; --if  
                    SET @SearchTerm = @SearchTerm + @filterClause;  
                END; --if filterclause is not null  
            END; --if  
                 
            UPDATE @UniqueFilters  
            SET Processed = 1  
            WHERE FilterId = @CurrentFilterId;  
        END;    --WHILE EXISTS(SELECT * FROM @UniqueFilters WHERE Processed = 0)  
    END; --EXISTS in @SearchTerm  
    SET @SearchTerm = NULLIF(@SearchTerm, N'');  
  
    IF @CountOnly = 1 AND @SearchTerm IS NULL -- Counts only and no search term  
        BEGIN  
            SET @AttributesRequired = 0;  
        END  
     
    --PRINT @SearchTerm;  
     
    --IF EXISTS(SELECT 1 FROM mdm.tblAttribute WHERE Entity_ID = @Entity_ID AND MemberType_ID = @MemberType_ID AND [Name] = @SortColumn AND DomainEntity_ID > 0) BEGIN --DBA Sort Column  
    --    IF @DisplayType_ID = 1 SET @SortOrderColumn = quotename(@SortOrderColumn);  
    --    ELSE IF @DisplayType_ID = 2 SET @SortOrderColumn = quotename(@SortColumn + N'.Code') + N' ';  
    --    ELSE IF @DisplayType_ID = 3 SET @SortOrderColumn = quotename(@SortColumn + N'.Name') + N' ' +  
    --        @SortDirection + N', ' + quotename(@SortColumn + N'.Code');  
    --END ELSE  
     
    IF (@matchOrderBy IS NOT NULL)  
    BEGIN  
        SET @PageCTEOrder = N'(' + @matchOrderBy + N') DESC, '  
    END  
    ELSE BEGIN  
        SET @PageCTEOrder = N'';  
    END;  
     
    SET @SortOrderColumnQuoted = QUOTENAME(@SortOrderColumn);  
    SET @SortColumnQuoted = QUOTENAME(@SortColumn);  
     
    --Assign the Object ID {** Need to refactor (consolidate lists, security types, and enumerations **}  
    IF @IsExplicitHierarchy = 1   
        BEGIN --an Explicit Hierarchy  
            SET @Object_ID = 6;  
            SET @Securable_ID = @Hierarchy_ID;  
        END   
    ELSE  
        BEGIN  
            SET @Object_ID = 3;  
            SET @Securable_ID = @Entity_ID;  
        END; --if  
  
     --Fetch the default privilege for the selected member type within the current entity.  
    --Due to bi-directional inheritance of privileges in model security, if a 99 is returned  
    --this should be interpreted as a soft deny (evaluating the member type permission requires an eval of attribute permissions)  
    --(i.e. if the user does NOT have any permissions at the DH levels evaluated below, 99 == DENY)  
    --PERF - moved this call to a udp to decrease the execution plan compile time.   
    EXEC mdm.udpSecurityUserMemberDefault  
        @User_ID = @User_ID,  
        @Item_ID = @Securable_ID,  
        @Object_ID = @Object_ID,  
        @MemberType_ID = @MemberType_ID,  
        @Privilege_ID = @Privilege_ID OUTPUT;  
         
    --Incorporate Derived Hierarchy explicit assignments (EDM-2384)  
    IF @Privilege_ID = (SELECT ID FROM mdm.tblSecurityPrivilege WHERE Code = CAST(N'DENY' AS NVARCHAR(15)))  
        --If default privilege is Deny then do not return any rows  
        SELECT @PageSize = 0; --!I think this code will cause "ROWCOUNT:=0" which means return *all* rows, so it won't work as expected?  
    ELSE     
        --If the object appears in a Derived Hierarchy then resolve against any explicit assignments for the hierarchy(ies)  
        SET @Privilege_ID = mdm.udfMin(mdm.udfSecurityUserHierarchyDerivedItem(@User_ID, @Hierarchy_ID, @Object_ID, @Securable_ID), @Privilege_ID);  
  
    --Identify data sources  
    SELECT  
        @ViewName = N'mdm.' + quotename(mdm.udfViewNameGetByID(@Entity_ID, @MemberType_ID, 4)), --EXP View - Which is exploaded by hierarchy parent  
        @ViewNameRaw = N'mdm.' + quotename(mdm.udfViewNameGetByID(@Entity_ID, @MemberType_ID, 0)),  
        @TableName = N'mdm.' + quotename(mdm.udfTableNameGetByID(@Entity_ID, 4)),  
        @SecurityTable = N'mdm.' + quotename(mdm.udfTableNameGetByID(@Entity_ID, 6)),  
        @LeafTable = N'mdm.' + quotename(mdm.udfTableNameGetByID(@Entity_ID, 1));  
     
    --Extra perf - Needs more testing  
    SET @RealViewNameRaw = @ViewNameRaw; -- this is needed as we are going to lose the real view name in the following if clause  
    If @SortColumnQuoted IN (N'[Code]', N'[Name]') AND NULLIF(@SearchTerm,N'') IS NULL  
    BEGIN  
        SET @ViewNameRaw  = N'(SELECT * FROM mdm.' + quotename(mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID)) + N' WHERE Status_ID =1) ';  
    END;  
      
  
    --Fetch the list of columns  
    IF @IDOnly = 1 SET @ColumnString = CAST(N'T.ID' AS NVARCHAR(max));  
    ELSE IF @CountOnly = 0 BEGIN  
        IF @ColumnString IS NULL  
            EXEC mdm.udpAttributeColumnListGet @User_ID, @Entity_ID, @MemberType_ID, @AttributeGroup_ID, @ColumnString OUTPUT;  
    END ELSE SET @ColumnString = CAST(N'@MemberCount = COUNT(T.ID)' AS NVARCHAR(max));  
     
    -------------------------------------------------------------------------------------  
    --Figure out if Member security is used  
    SET @RootSecured = 0;  
    --PRINT '@UseMemberSecurity: ' + convert(nvarchar(100),@UseMemberSecurity)  
    IF @MemberType_ID IN (@MemberType_Leaf, @MemberType_Consolidated)  
        SET @UseMemberSecurity = mdm.udfUseMemberSecurity(@User_ID, @Version_ID, 1, @Hierarchy_ID, NULL, @Entity_ID, @MemberType_ID, @Attribute_ID);  
  
    --Any value other than No means we need to cache security info  
    IF @UseMemberSecurity <> @UserMemberSecurity_No  
        BEGIN  
            --If we are using member security we need to get all the privileges for this user into a temp table  
            --This optimization really speeds up gets on large secured entities  
            CREATE TABLE #SecurityRoles(RoleID INT PRIMARY KEY);  
            INSERT INTO #SecurityRoles  
            SELECT Role_ID FROM mdm.[viw_SYSTEM_SECURITY_USER_ROLE] WHERE User_ID = @User_ID;  
        END  
  
    DECLARE @LoadParentMemberSecurity BIT = 0;  
    IF (@UseMemberSecurity = @UserMemberSecurity_Yes) BEGIN     
        --Check to see if Root is secured for Explicit  
        IF (@Hierarchy_ID IS NOT NULL AND @Attribute_ID IS NULL AND EXISTS(  
            SELECT 1 FROM mdm.[viw_SYSTEM_SECURITY_USER_MEMBER] WHERE  
                IsMapped = 1 AND  
                User_ID = @User_ID AND  
                Hierarchy_ID = @Hierarchy_ID AND  
                HierarchyType_ID = 0 AND  
                Member_ID = 0  
            ))  
        --Check to see if Root is secured for Derived Hierarchy  
        OR (EXISTS(  
            SELECT 1 FROM mdm.[viw_SYSTEM_SECURITY_USER_MEMBER] WHERE  
                IsMapped = 1 AND  
                User_ID = @User_ID AND  
                Hierarchy_ID IN (SELECT Hierarchy_ID FROM mdm.[viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS] WHERE Foreign_ID = @Entity_ID AND [Object_ID] = 3) AND  
                HierarchyType_ID = 1 AND  
                Member_ID = 0  
            ))  
            SET @RootSecured = 1;  
  
        -- Need to add additional logic to the membersresolved CTE to get Consolidated (parent) member security when...  
        IF      @Parent_ID = @Root_ID                      -- getting the children of the ROOT node   
            AND @IsExplicitHierarchy = 1                   -- of an explicit hierarchy, and  
            AND @RootSecured = 0                           -- ROOT doesn't have an explicit permission, and  
            AND @MemberType_ID <> @MemberType_Consolidated -- not already getting Consolidated member permissions.  
        BEGIN  
            SET @LoadParentMemberSecurity = 1;  
        END;  
    END; --if  
  
    --Figure out the member ID column name for use in the CTE     
    DECLARE @MemberIdColumnName NVARCHAR(10);  
    SET @MemberIdColumnName = CASE @MemberType_ID WHEN @MemberType_Leaf THEN N'EN_ID' ELSE N'HP_ID' END;  
  
    --This cte is selectively added to the overall query based on if member security is needed to be applied  
    SET @MemberSecurityCTE = N'  
                            --Member security cte  
                            WITH membersresolved as    
                            (    
                                SELECT    
                                    @Version_ID AS Version_ID,    
                                    ' + @MemberIdColumnName + N' AS Member_ID,  
                                    ' +  
                            CASE WHEN @LoadParentMemberSecurity = 1  
                                THEN N'X.MemberType_ID'  
                                ELSE N'@MemberType_ID AS MemberType_ID' END + N',  
                                    MIN(X.Privilege_ID) AS Privilege_ID  
                                FROM    
                                    ' + @SecurityTable + N' X    
                                INNER JOIN #SecurityRoles R ON X.SecurityRole_ID = R.RoleID  
                                WHERE   
                                        ' +   
                            CASE WHEN @LoadParentMemberSecurity = 1  
                                 THEN N'MemberType_ID IN (@MemberType_ID, ' + CONVERT(NVARCHAR, @MemberType_Consolidated) + N')'  
                                 ELSE N'MemberType_ID = @MemberType_ID' END + N'   
                                    AND Version_ID = @Version_ID  
                                GROUP BY X.' + @MemberIdColumnName +   
                            CASE WHEN @LoadParentMemberSecurity = 1  
                                THEN N', X.MemberType_ID' ELSE N'' END + N'  
                                HAVING MIN(X.Privilege_ID) <> 1  
                            )';  
  
    ------------------------------------------------------------------------------  
    --in the case of no member security, a Privilege_ID of 99 here  
    --should be interpreted as a DENY because the user had no  
    --inherited privileges to the memberType, attribute, attribute group or DH  
    IF @UseMemberSecurity = @UserMemberSecurity_No AND @Privilege_ID = 99  
    BEGIN  
        SET @Privilege_ID = 1;  
    END;  
         
    --PRINT '@UseMemberSecurity: ' + convert(nvarchar(100),@UseMemberSecurity)  
  
    IF @CountOnly = 0  
    BEGIN  
        IF @UseMemberSecurity = @UserMemberSecurity_No  
        BEGIN  
            SET @ColumnString = @ColumnString + N', @Privilege_ID AS Privilege_ID';  
        END  
        ELSE BEGIN  
            SET @ColumnString = @ColumnString + N', CONVERT(INTEGER,ISNULL(SR.Privilege_ID, @Privilege_ID)) AS Privilege_ID';  
        END;  
  
        -- Create the query to get the members we are intrested in.  
        SET @MemberDetailsQuery = N'  
                --Return just the page we are interested in     
                SELECT  
                    ' + @ColumnString + N'  
                FROM  
                    ' + @ViewName + N' AS T  
                    INNER JOIN #TempItems AS SR ON (T.ID = SR.ID)  
                WHERE T.Version_ID = @Version_ID  
                ORDER BY SR.RowNo ASC';  
     
        SET @MemberDetailsRawQuery = N'  
                --Return just the page we are interested in     
                SELECT  
                    ' + @ColumnString + N'  
                FROM  
                    ' + @RealViewNameRaw + N' AS T  
                    INNER JOIN #TempItems AS SR ON (T.ID = SR.ID)  
                WHERE T.Version_ID = @Version_ID  
                ORDER BY SR.RowNo ASC';  
  
        -- Create code to add required page to temp table  
        SET @PageGetQuery = N'  
                )  
                INSERT INTO #TempItems(ID, Privilege_ID)  
                    SELECT ID, Privilege_ID  
                    FROM pageItems  
                    ' + CASE @PageSize WHEN 0 THEN N''  
                        ELSE N'WHERE RowID BETWEEN @StartRow AND @EndRow;' END;  
    END;  
  
    --Criterion 1: display all members (Attribute Explorer)  
    --First part is for normal entity explorer get where no hierarchy ID or parent attribute ID is specified  
    -- Second part is the root of a derived hierarchy  
    IF (@Hierarchy_ID IS NULL AND @Attribute_ID IS NULL) OR (@HierarchyType_ID = @DerivedHierarchyTypeId AND @Hierarchy_ID IS NOT NULL AND @Parent_ID IS NULL AND @Attribute_ID IS NULL)   
    BEGIN  
  
        IF @UseMemberSecurity <> @UserMemberSecurity_No AND @MemberType_ID = @MemberType_Leaf  
        BEGIN  
            SET @FullSearchTerm = N'  
                        INNER JOIN membersresolved AS SR  
                            ON SR.Member_ID = T.ID AND SR.Version_ID = T.Version_ID AND SR.MemberType_ID = @MemberType_ID';  
        END ELSE IF @UseMemberSecurity = @UserMemberSecurity_Yes AND @MemberType_ID = @MemberType_Consolidated  
        BEGIN  
            SET @FullSearchTerm = N'  
                        LEFT JOIN membersresolved AS SR  
                            ON SR.Member_ID = T.ID AND SR.Version_ID = T.Version_ID AND SR.MemberType_ID = @MemberType_ID';  
        END  
        ELSE BEGIN  
            SET @FullSearchTerm = N''  
        END; --if  
  
        SET @FullSearchTerm += N'  
                    WHERE T.Version_ID = @Version_ID';  
             
        -- Given no member security filtering, must exclude items on deny.  
        IF @UseMemberSecurity = @UserMemberSecurity_No  
        BEGIN  
            SET @FullSearchTerm += N'  
                    AND @Privilege_ID <> 1';  
        END;  
  
        IF @Member_ID IS NOT NULL  
        BEGIN   
            -- Only get the specified member.  
            SET @FullSearchTerm += N'  
                    AND T.ID = @Member_ID';  
        END;  
  
        IF @UseMemberSecurity = @UserMemberSecurity_Yes AND @MemberType_ID = @MemberType_Consolidated  
        BEGIN  
            SET @FullSearchTerm += N'  
                    AND ISNULL(SR.Privilege_ID, 0) <> CASE  
                        WHEN T.Hierarchy_ID IN (SELECT DISTINCT Hierarchy_ID FROM mdm.[viw_SYSTEM_SECURITY_USER_MEMBER] WHERE User_ID = @User_ID AND Entity_ID = @Entity_ID AND HierarchyType_ID = 0) THEN 0  
                        ELSE -1  
                    END';  
        END;  
  
        IF @SearchTerm IS NOT NULL  
        BEGIN  
            SET @FullSearchTerm += N'  
                    AND ' + @SearchTerm;  
        END;  
  
        IF @CountOnly = 0 -- Data required  
            BEGIN  
  
            IF (@SortOrderColumnQuoted IS NOT NULL)  
            BEGIN  
                SET @PageCTEOrder += @SortOrderColumnQuoted + N' ' + @SortDirection + N', ';  
            END  
            SET @PageCTEOrder += N'ID ' + @SortDirection;  
  
            -- if we dont need the membership information we are in the fast lane  
            IF (@MemberReturnOption & @MemberReturnOptionMembershipInformation) = 0  
            BEGIN  
                SET @ViewNameToUse = @RealViewNameRaw;  
                SET @SQLSuffixToUse = @MemberDetailsRawQuery;  
            END  
            ELSE  
            -- This is full query. We need to join with the EXP view  
            BEGIN  
                SET @ViewNameToUse = @ViewName;  
                SET @SQLSuffixToUse = @MemberDetailsQuery;  
            END  
  
            --First populate temporary table with IDs of rows  
            IF @PageSize <> 0  
            BEGIN  
                SET @SQL = N'  
                CREATE TABLE #TempItems(RowNo INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, ID INT, Privilege_ID INT);  
                '+ CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN @MemberSecurityCTE + N',' ELSE N'WITH ' END + N'  
                pageItems as(  
                    SELECT ROW_NUMBER() OVER (ORDER BY ' + @PageCTEOrder + N') AS RowID,  
                            T.*, ' + CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN N'SR.Privilege_ID' ELSE N'NULL AS Privilege_ID' END + N'  
                    FROM ' + @ViewNameRaw + N' AS T' + @FullSearchTerm;  
  
                --if using member security, replace NULLs with the default model security, then remove DENYs  
                IF @UseMemberSecurity <> @UserMemberSecurity_No  
                BEGIN  
                    SET @SQL += N'  
                        AND SR.Privilege_ID IS NOT NULL';  
                END;  
  
                SET @SQL += @PageGetQuery;  
  
                --Get the page we are interested in  
                SET @SQL += @SQLSuffixToUse;  
            END  
            ELSE BEGIN --Returns all the records in the entity.  
                SET @SQL = CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN + @MemberSecurityCTE ELSE + N' ' END + N'	                     
                SELECT  
                    ' + @ColumnString + N'  
                FROM  
                    ' + @ViewNameToUse + N' AS T' + @FullSearchTerm;  
                 
                IF @SearchTerm IS NOT NULL  
                BEGIN  
                    SET @SQL += N'  
                    AND ' + @SearchTerm;  
                END;  
            END             
        END  
        ELSE  
        BEGIN --Count only  
            SET @SQL = CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN + @MemberSecurityCTE ELSE + N' ' END + N'  
            SELECT @MemberCount = COUNT(DISTINCT T.ID)  
            FROM ' + @ViewNameRaw + N' AS T' + @FullSearchTerm;  
            IF @UseMemberSecurity <> @UserMemberSecurity_No BEGIN  
                SET @SQL += N'  
                AND SR.Privilege_ID IS NOT NULL';  
            END;  
        END; --if                  
        SET @Mode = 2;      
    END   
      
    --Criterion 2: display unused members of the hierarchy (Hierarchy Explorer)     
    ELSE IF @IsExplicitHierarchy = 1 AND @Parent_ID = -1 AND @MemberType_ID = @MemberType_Leaf   
    BEGIN  
        IF (Select Count(ID) FROM mdm.tblHierarchy where Entity_ID = @Entity_ID and ID = @Hierarchy_ID) = 0  
        BEGIN  
            --On error, return NULL results  
            RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
            RETURN(1);  
        END  
        --End Resolve  
  
        IF @UseMemberSecurity <> @UserMemberSecurity_No AND @MemberType_ID = @MemberType_Leaf  
        BEGIN  
            SET @FullSearchTerm = N'  
            INNER JOIN membersresolved AS SR  
                ON SR.Member_ID = T.ID  
                AND SR.Version_ID = T.Version_ID  
                AND SR.MemberType_ID = @MemberType_ID';  
        END ELSE IF @UseMemberSecurity = @UserMemberSecurity_Yes AND @MemberType_ID = @MemberType_Consolidated  
        BEGIN  
            SET @FullSearchTerm = N'  
            LEFT JOIN membersresolved AS SR  
                ON SR.Member_ID = T.ID  
                AND SR.Version_ID = T.Version_ID  
                AND SR.MemberType_ID = @MemberType_ID';  
        END  
        ELSE BEGIN  
            SET @FullSearchTerm = N'';  
        END; --if  
  
        --This common table expression brings back all the unused leaf members of an explicit hierarchy while at the same time  
        --filtering on the search filter  
        DECLARE @UnusedCte NVARCHAR(MAX) = N'  
        unused AS (  
                    SELECT T.*, HR.Child_EN_ID AS EN_ID  
                    FROM ' + CASE WHEN @SearchTerm IS NOT NULL THEN @ViewNameRaw ELSE @LeafTable END + N' T  
                    LEFT JOIN ' + @TableName + N' HR ON HR.Version_ID = T.Version_ID AND HR.ChildType_ID = 1 AND HR.Hierarchy_ID = @Hierarchy_ID AND HR.Child_EN_ID = T.ID   
                    WHERE T.Version_ID = @Version_ID AND HR.Child_EN_ID IS NULL '   
                    + CASE WHEN @SearchTerm IS NOT NULL THEN N' AND ' + @SearchTerm ELSE N'' END +   
                N')';  
  
        IF @CountOnly = 0 -- return data  
            BEGIN  
                SET @PageCTEOrder += N'T.Code ASC, T.ID ASC';  
             
                --First populate temporary table with IDs of rows  
                SET @SQL = N'  
                CREATE TABLE #TempItems(RowNo INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, ID INT, Privilege_ID INT);  
                ' + CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN @MemberSecurityCTE + N',' ELSE N'WITH ' END + @UnusedCte + N',  
                pageItems AS(  
                    SELECT ROW_NUMBER() OVER (ORDER BY ' + @PageCTEOrder + N') AS RowID,  
                        T.*, ' + CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN N'SR.Privilege_ID' ELSE N'NULL AS Privilege_ID' END + N'  
                    FROM unused AS T ' + @FullSearchTerm + N' ';  
  
                IF @UseMemberSecurity <> @UserMemberSecurity_No  
                BEGIN  
                    SET @SQL += N'  
                    AND SR.Privilege_ID IS NOT NULL';  
                END;  
  
                SET @SQL += @PageGetQuery;  
  
                --Get the page we are interested in  
                SET @SQL += @MemberDetailsQuery;  
            END  
        ELSE   
            BEGIN --Count only  
  
                SET @SQL = CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN + @MemberSecurityCTE + N',' ELSE + N'WITH ' END + @UnusedCte + N'  
                SELECT @MemberCount = COUNT(*)  
                FROM unused AS T ' + @FullSearchTerm;  
  
            END; --if  
         
        SET @Mode = 3;      
    END   
      
    --Criterion 3: display all members under another in an explicity hierarchy (Hierarchy Explorer)  
    --We allow a NULL parent ID but only when consolidated members (member type 2) are requested. A parent ID of null with a member type of  
    --consolidated results in all the consolidated members under this entity/hierarchy combination  
    ELSE IF @IsExplicitHierarchy = 1 AND COALESCE(@Attribute_ID, 0) = 0 AND (@Parent_ID IS NOT NULL OR @MemberType_ID = @MemberType_Consolidated)  
    BEGIN  
  
        IF @Parent_ID = 0 AND @UseMemberSecurity = @UserMemberSecurity_Yes AND @RootSecured = 0  
        BEGIN  
            SET @FullSearchTerm = N'   
                                    INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBER AS SU   
                                    ON  
                                    SU.User_ID = @User_ID  
                                    AND SU.MemberType_ID = @MemberType_ID   
                                    AND SU.Entity_ID = @Entity_ID ';  
  
            IF @AttributesRequired = 1  
                BEGIN  
                    SET @FullSearchTerm += N'  
                    AND SU.Member_ID = T.ID  
                    AND SU.Version_ID = T.Version_ID   
                    INNER JOIN ' + @TableName + N' AS HR ON   
                    HR.ChildType_ID = @MemberType_ID  
                    AND SU.Member_ID = HR.' + CASE @MemberType_ID WHEN @MemberType_Leaf THEN N'Child_EN_ID' ELSE N'Child_HP_ID' END;  
                END  
            ELSE  
                BEGIN  
                    SET @FullSearchTerm += N'                          
                        AND SU.Member_ID = HR.' + CASE @MemberType_ID WHEN @MemberType_Leaf THEN N'Child_EN_ID' ELSE N'Child_HP_ID' END + N'  
                        AND SU.Version_ID = HR.Version_ID ';  
                END  
        END   
          
        ELSE IF ((@Parent_ID = 0 AND @UseMemberSecurity <> @UserMemberSecurity_Yes) OR @Parent_ID <> 0 OR @RootSecured = 1) AND @AttributesRequired = 1  
        BEGIN  
            SET @FullSearchTerm = N'  
            RIGHT JOIN ' + @TableName + N' AS HR ON T.ID = HR.' + CASE @MemberType_ID WHEN @MemberType_Leaf THEN N'Child_EN_ID' ELSE N'Child_HP_ID' END + N'  
                AND HR.Version_ID = T.Version_ID  
                AND HR.Version_ID = @Version_ID  
                AND HR.ChildType_ID = @MemberType_ID';  
        END  
  
        --If we are requesting all consolidated members in this hierarchy  
        ELSE IF @Parent_ID IS NULL AND @MemberType_ID = @MemberType_Consolidated AND @AttributesRequired = 1  
            BEGIN  
                SET @FullSearchTerm = N'  
                RIGHT JOIN ' + @TableName + N' AS HR ON   
                    T.ID = HR.Child_HP_ID  
                    AND HR.Version_ID = T.Version_ID  
                    AND HR.Version_ID = @Version_ID  
                    AND HR.ChildType_ID = @MemberType_ID';  
            END  
        ELSE   
            BEGIN  
                SET @FullSearchTerm = N'';  
            END; --if  
  
        IF @UseMemberSecurity = @UserMemberSecurity_Yes  
        BEGIN  
            SET @FullSearchTerm += N'  
            LEFT JOIN membersresolved AS SR  
                ON SR.Member_ID = HR.' + CASE @MemberType_ID WHEN @MemberType_Leaf THEN N'Child_EN_ID' ELSE N'Child_HP_ID' END + N'  
                AND SR.MemberType_ID = HR.ChildType_ID  
                AND SR.MemberType_ID = @MemberType_ID';  
        END  
        ELSE IF @UseMemberSecurity = @UserMemberSecurity_LeafOnly  
        BEGIN  
            SET @FullSearchTerm += N'  
            LEFT JOIN membersresolved AS SR  
                ON SR.Member_ID = HR.Child_EN_ID  
                AND SR.MemberType_ID = HR.ChildType_ID  
                AND HR.ChildType_ID = ' + CONVERT(NVARCHAR(3), @MemberType_Leaf) + N'  
                --AND SR.Entity_ID = @Entity_ID';  
        END; --if  
  
        DECLARE   
            @GetVisibleDescendantsOfRootParent BIT = 0,  
            @GetChildrenOfSpecifiedParent     BIT = 0;  
        IF @Parent_ID IS NOT NULL  
        BEGIN  
            IF @Parent_ID = @Root_ID AND @UseMemberSecurity = @UserMemberSecurity_Yes AND @RootSecured = 0  
            BEGIN  
                -- Get all top-level visible children that should appear under ROOT.  
                SET @GetVisibleDescendantsOfRootParent = 1;  
                SET @FullSearchTerm += N'  
            LEFT JOIN membersresolved AS PSR -- parent security  
                ON      HR.Parent_HP_ID = PSR.Member_ID  
                    AND PSR.MemberType_ID = ' + CONVERT(NVARCHAR, @MemberType_Consolidated);  
            END ELSE  
            BEGIN  
                -- Get only children under the specified parent.  
                SET @GetChildrenOfSpecifiedParent = 1;  
            END;  
        END;  
  
        SET @FullSearchTerm += N'  
            WHERE    HR.Version_ID   = @Version_ID  
                 AND HR.Hierarchy_ID = @Hierarchy_ID ';  
  
        IF @AttributesRequired = 0 AND @MemberType_ID = @MemberType_Leaf  
            BEGIN  
                SET @FullSearchTerm += N' AND HR.Child_EN_ID IS NOT NULL AND HR.Status_ID = ' + @MemberStatusActive + N' ';  
            END  
        ELSE IF @AttributesRequired = 0 AND @MemberType_ID = @MemberType_Consolidated  
            BEGIN  
                SET @FullSearchTerm += N' AND HR.Child_HP_ID IS NOT NULL AND HR.Status_ID = ' + @MemberStatusActive + N' ';  
            END  
        ELSE  
            BEGIN  
                SET @FullSearchTerm += N' AND T.ID IS NOT NULL';  
            END  
  
        IF @UseMemberSecurity = @UserMemberSecurity_Yes  
        BEGIN                  
            SET @FullSearchTerm += N'  
                AND SR.Privilege_ID IS NOT NULL';    
        END   
        ELSE   
        IF @UseMemberSecurity = @UserMemberSecurity_LeafOnly  
        BEGIN  
            -- HR.ChildType_ID = @MemberType_ID  
            SET @FullSearchTerm += N'  
               AND ISNULL(SR.Privilege_ID, 0) <> ' + CASE @MemberType_ID WHEN @MemberType_Leaf THEN N'0' ELSE N'-1' END;  
        END;  
  
        IF @GetVisibleDescendantsOfRootParent = 1  
        BEGIN  
            SET @FullSearchTerm += N'  
                AND PSR.Privilege_ID IS NULL'; -- Only get children whose immediate parent is not visible  
        END   
        ELSE IF @GetChildrenOfSpecifiedParent = 1  
        BEGIN  
            SET @FullSearchTerm += N'  
                AND ISNULL(HR.Parent_HP_ID, 0) = @Parent_ID';-- Only get children of the specified parent  
        END;  
  
        IF @SearchTerm IS NOT NULL  
        BEGIN  
            SET @FullSearchTerm += N'  
                AND ' + @SearchTerm;  
        END;  
  
        IF @CountOnly = 0 -- return data  
            BEGIN  
                IF (@SortOrderColumnQuoted IS NOT NULL) BEGIN  
                   SET @PageCTEOrder += @SortOrderColumnQuoted + N' ' + @SortDirection + N', ';  
                END  
                SET @PageCTEOrder += N'HR.SortOrder, T.ID ' + @SortDirection;  
  
                --First populate temporary table with IDs of rows  
                SET @SQL = N'  
                CREATE TABLE #TempItems(RowNo INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, ID INT, Privilege_ID INT);  
                ' + CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN @MemberSecurityCTE + N',' ELSE N'WITH ' END + N'  
                pageItems AS(  
                    SELECT ROW_NUMBER() OVER (ORDER BY ' + @PageCTEOrder + N') AS RowID,  
                        T.*, '+ CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN N'SR.Privilege_ID' ELSE N'NULL AS Privilege_ID' END + N'  
                    FROM ' + @ViewNameRaw + N' AS T' + @FullSearchTerm;  
  
                SET @SQL += @PageGetQuery;  
  
                --Get Remaining Records  
                SET @SQL += @MemberDetailsQuery;         
            END  
        ELSE   
            BEGIN --Count only  
  
                SET @SQL = CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN + @MemberSecurityCTE ELSE + N' ' END  
  
                IF @AttributesRequired = 1  
                    BEGIN  
                        SET @SQL += N'SELECT @MemberCount = COUNT(DISTINCT T.ID)  
                                    FROM ' + @ViewNameRaw + N' AS T' + @FullSearchTerm;  
                    END  
                ELSE  
                    BEGIN  
                        SET @SQL += N'SELECT @MemberCount = COUNT(DISTINCT HR.ID)  
                                    FROM ' + @TableName + N' AS HR ' + @FullSearchTerm;  
                    END  
  
            END; --if  
  
        SET @Mode = 4;  
    END   
      
    --Criterion 4: display all members assigned to the node (Hierarchy Explorer - Derived)  
    ELSE IF @HierarchyType_ID = @DerivedHierarchyTypeId AND COALESCE(@Attribute_ID, 0) <> 0   
    BEGIN --from the Derived Hierarchy  
        DECLARE  
            @AttributeName           sysname,  
            @TempAttributeValue      NVARCHAR(250),  
            @AttributeEntity_ID      INT,  
            @CurrentLevel_ID         INT,  
            @PriorLevel_ID           INT,  
            @PriorItem_ID            INT,  
            @PriorItemType_ID        INT,  
            @SQLFrom                 NVARCHAR(MAX), --Used for getting all the join tables when skipping levels in DH  
            @TempItem_ID             INT,  
            @TempItemType_ID         INT,  
            @TempLookupEntity_ID     INT,  
            @TempLookupViewName      sysname,  
            @TempLookupPriorViewName sysname,  
            @TempLookupAttributeName sysname,  
            @TempTotalCounter        INT,  
            @TempCounter             INT;  
        DECLARE @TempTable           TABLE (Item_ID INT NOT NULL, ItemType_ID INT NOT NULL, Level_ID INT NOT NULL);  
  
        --Fetch the attribute DBA column name  
        SELECT  
            @AttributeName = [Name],  
            @AttributeEntity_ID = DomainEntity_ID  
        FROM mdm.tblAttribute WHERE ID = @Attribute_ID;  
  
        --Fetch the code from the ID           
        IF COALESCE(@AttributeValue, 0) <> 0 -- Leave @TempAttributeValue NULL when getting members under ROOT. @AttributeValue can be NULL/0 along this code path when getting top-level members for a recursive hierarchy that anchors null recursions.  
        BEGIN             
            EXEC mdm.udpMemberDisplayCodeGetByID @Version_ID, @AttributeEntity_ID, @AttributeValue, 1, 1, @TempAttributeValue OUTPUT;  
        END  
  
        --Check to see if any levels were skipped; if so, create the proper join string------------        
        --Fetch the prior level  
        SELECT TOP 1 @PriorLevel_ID = Level_ID  
        FROM mdm.tblDerivedHierarchyDetail  
        WHERE DerivedHierarchy_ID = @Hierarchy_ID AND Foreign_ID = @Attribute_ID  
        ORDER BY Level_ID DESC;  
  
        --Fetch the current level  
        SELECT TOP 1 @CurrentLevel_ID = Level_ID  
        FROM mdm.tblDerivedHierarchyDetail  
        WHERE DerivedHierarchy_ID = @Hierarchy_ID AND Level_ID < @PriorLevel_ID AND IsVisible = 1  
        ORDER BY Level_ID DESC;                       
  
        --Fetch the list of tables to join (if skipping levels)  
        SELECT  
            @SQLFrom = CAST(N'' AS NVARCHAR(max)),  
            @TempCounter = 0,      
            @TempLookupPriorViewName = CAST(N''  AS sysname);  
  
        INSERT INTO @TempTable SELECT Foreign_ID, ForeignType_ID, Level_ID FROM mdm.tblDerivedHierarchyDetail  
        WHERE DerivedHierarchy_ID = @Hierarchy_ID AND Level_ID BETWEEN @CurrentLevel_ID AND @PriorLevel_ID  
        AND Level_ID != @CurrentLevel_ID AND Level_ID != @PriorLevel_ID  
        ORDER BY Level_ID ASC;  
         
        SELECT @TempTotalCounter = COUNT(*) FROM @TempTable;  
         
        WHILE EXISTS(SELECT 1 FROM @TempTable) BEGIN  
            SET @TempCounter = @TempCounter + 1;  
             
            SELECT TOP 1 @TempItem_ID = Item_ID, @TempItemType_ID = ItemType_ID FROM @TempTable ORDER BY Level_ID ASC;  
             
            SET @TempLookupEntity_ID = CASE @TempItemType_ID  
                WHEN 1 THEN (SELECT DomainEntity_ID FROM mdm.tblAttribute WHERE ID = @TempItem_ID)  
                WHEN 0 THEN @TempItem_ID  
            END; --case  
  
            SET @TempLookupViewName = mdm.udfViewNameGetByID(@TempLookupEntity_ID, 1, 0);  
     
            --Determine attribtue DBA column name           
            SELECT @TempLookupAttributeName = [Name] FROM mdm.tblAttribute WHERE ID = @TempItem_ID;  
                 
            --Build join table list  
            IF LEN(@TempLookupPriorViewName) =0  
            SET @SQLFrom = @SQLFrom + N'  
            INNER JOIN mdm.' + quotename(@TempLookupViewName) + N' AS ' + quotename(@TempLookupViewName) + N' ON ' + quotename(@TempLookupViewName) + N'.Code = T.' + quotename(@TempLookupAttributeName);  
            ELSE SET @SQLFrom = @SQLFrom + N'  
            INNER JOIN mdm.' + quotename(@TempLookupViewName) + N' AS ' + quotename(@TempLookupViewName) + N' ON ' + quotename(@TempLookupViewName) + N'.Code = ' + quotename(@TempLookupPriorViewName) + N'.' + quotename(@TempLookupAttributeName);  
             
                 
            SET @SQLFrom = @SQLFrom + N'  
                AND ' + quotename(@TempLookupViewName) + N'.Version_ID = T.Version_ID  
                AND T.Version_ID = @Version_ID';  
  
            --If last table to join then add the final portion of the join  
            IF @TempCounter = @TempTotalCounter  
                SET @SQLFrom = @SQLFrom + N'  
                AND ' + quotename(@TempLookupViewName) + N'.' + quotename(@AttributeName) + N' = @Value'  
  
            SET @TempLookupPriorViewName = @TempLookupViewName;  
            DELETE FROM @TempTable WHERE Item_ID = @TempItem_ID;  
        END; --while  
             
        -------------------------------------------------------------------------------------------  
        IF @Attribute_ID IS NULL AND @UseMemberSecurity = @UserMemberSecurity_Yes  
        BEGIN  
            SET @SQL += N'  
            INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBER AS SU ON SU.Member_ID = T.ID  
                AND T.Version_ID =  SU.Version_ID  
                AND SU.User_ID = @User_ID  
                AND SU.MemberType_ID = @MemberType_ID';  
        END;  
  
        IF @UseMemberSecurity = @UserMemberSecurity_Yes  
        BEGIN  
            SET @SQL += N'  
            LEFT JOIN membersresolved AS SR  
                ON SR.Member_ID = T.ID  
                AND SR.MemberType_ID = @MemberType_ID';  
        END   
        ELSE IF @UseMemberSecurity = @UserMemberSecurity_LeafOnly   
        BEGIN  
            SET @SQL += N'  
            INNER JOIN membersresolved SR  
                ON SR.Member_ID = T.ID  
                AND SR.MemberType_ID = @MemberType_ID';  
        END; --if  
  
        IF LEN(@SQLFrom) <> 0  
            SET @SQL += @SQLFrom;  
        ELSE BEGIN  
            --If the value that defines the relation to the parent is NULL just check the DH column for a null value  
            --otherwise compare it to the value  
            IF @TempAttributeValue IS NULL  
                BEGIN  
                    SET @SQL += N'  
                    WHERE T.Version_ID = @Version_ID  
                    AND  ' + QUOTENAME(@AttributeName) + N' IS NULL ';  
                END  
            ELSE  
                BEGIN  
                    SET @SQL += N'  
                    WHERE T.Version_ID = @Version_ID  
                    AND  ' + QUOTENAME(@AttributeName) + N' = @Value ';  
                END  
  
            IF @UseMemberSecurity <> @UserMemberSecurity_No  
            BEGIN  
                SET @SQL += N'  
                AND SR.Privilege_ID IS NOT NULL ';  
            END;  
        END; --if  
  
        IF @SearchTerm IS NOT NULL  
        BEGIN  
            SET @SQL += N'  
                AND ' + @SearchTerm;  
        END;  
  
        IF @CountOnly = 0  -- return data  
        BEGIN  
             
            --build a snippet to get the unique member Ids for the current page number and size  
            DECLARE @idFilter NVARCHAR(MAX);   
  
            SET @idFilter = N'  
                INSERT INTO #TempIds(ID, Privilege_ID)  
                SELECT ' + CASE WHEN @PageSize <> 0 THEN N'TOP ' + CONVERT(NVARCHAR(30), @StartRow + @PageSize - 1) ELSE N'' END + ' Q.ID, ' + CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN N'Q.Privilege_ID' ELSE N'NULL Privilege_ID' END + N'     
                FROM  
                (SELECT DISTINCT T.[ID], ' + CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN N'SR.Privilege_ID' ELSE N'NULL Privilege_ID' END;  
  
            IF (@SortOrderColumnQuoted IS NOT NULL)  
            BEGIN  
                -- Add the sort column to the result set, so it can be used in the ORDER BY clause.   
                SET @idFilter += N', ' + (CASE @SortOrderColumnQuoted WHEN N'[Name]' THEN N'[Member_Name]' WHEN N'[Code]' THEN N'[Member_Code]' ELSE @SortOrderColumnQuoted END);   
            END               
             
            SET @idFilter += N'  
                FROM ' + @ViewName + N' AS T' + @SQL + N') Q  
                ORDER BY ';  
            IF (@SortOrderColumnQuoted IS NOT NULL)  
            BEGIN   
                SET @idFilter += N'Q.' + (CASE @SortOrderColumnQuoted WHEN N'[Name]' THEN N'[Member_Name]' WHEN N'[Code]' THEN N'[Member_Code]' ELSE @SortOrderColumnQuoted END) + N' ' + @SortDirection + N', ';   
            END                           
             
            SET @idFilter += N'Q.ID ' + @SortDirection + N';  
              ';                 
               
            
             --First populate 2 temporary tables, 1 with unique IDs of members to display  
             --the other containing the many rows neccesary for building the member rows for the current hierarchy  
            SET @SQL = N'   
            --Get keyset up to end of requested page   
            CREATE TABLE #TempItems(RowNo INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, ID INT, Privilege_ID INT);  
            CREATE TABLE #TempIds(RowNo INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, ID INT, Privilege_ID INT);  
             
            ' +    
            CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN + @MemberSecurityCTE ELSE + ' ' END + @idFilter + N'  
            ' +  
            CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN + @MemberSecurityCTE ELSE + ' ' END + N'  
            INSERT INTO #TempItems(ID, Privilege_ID)   
            SELECT  T.ID, Q.Privilege_ID  
            FROM ' + @ViewName + N' AS T  
            INNER JOIN #TempIds Q ON Q.ID = T.ID  
            ' + @SQL + N' AND Q.RowNo >= @StartRow';   
     
            SET @SQL += N'   
            ORDER BY ';             
            IF (@SortOrderColumnQuoted IS NOT NULL) BEGIN  
                SET @SQL += N'T.' + @SortOrderColumnQuoted + N' ' + @SortDirection + N', ';  
            END  
             
            SET @SQL += N'T.ID ' + @SortDirection + N';';   
   
            --Get Remaining Records   
            SET @SQL += N'   
            SELECT    
                ' + @ColumnString + N'    
            FROM    
                ' + @ViewName + N' AS T   
            INNER JOIN #TempItems AS SR ON (T.ID = SR.ID)';   
   
            SET @SQL += N'   
            WHERE T.Version_ID = @Version_ID';  
             
            SET @SQL += N'   
            ORDER BY SR.RowNo ASC';  
        END ELSE BEGIN --Count only  
  
            SET @SQL = CASE WHEN @UseMemberSecurity <> @UserMemberSecurity_No THEN + @MemberSecurityCTE ELSE + ' ' END + N'  
            SELECT @MemberCount = COUNT(DISTINCT T.ID)  
            FROM ' + @ViewName + N' AS T' + @SQL;  
  
        END; --if  
  
        SET @Mode = 5;  
    END; --if  
  
     
    /*  
    ------------------------------------  
    EXECUTE SQL  
    ------------------------------------  
    */  
     
     
    DECLARE @SqlParameters as NVARCHAR(MAX) = N'@User_ID INT, @Version_ID INT, @Hierarchy_ID INT, @Entity_ID INT, @Parent_ID INT, @Member_ID INT, @MemberType_ID TINYINT, @Privilege_ID INT, @StartRow INT, @EndRow INT, @SearchTable mdm.MemberGetCriteria READONLY';  
    --PRINT @Mode  
    --PRINT @SQL;  
    IF @Mode = 2 AND @CountOnly = 1 AND @SearchTerm IS NULL AND @Member_ID IS NULL -- count only  
    BEGIN  
        -- Try to get the results from the last call, as cached in tblUserMemberCount.  
        EXEC mdm.udpUserMemberLastCountGet @User_ID, @Version_ID, @Entity_ID, @MemberType_ID, @MemberCount OUTPUT;   
        IF @MemberCount = -1 BEGIN   
            -- Couldn't find the results in the cache, so compute the count and save it in the cache.  
            SET @SqlParameters += N', @MemberCount INT OUTPUT';  
            EXEC sp_executesql @SQL, @SqlParameters,  
                @User_ID, @Version_ID, @Hierarchy_ID, @Entity_ID, @Parent_ID, @Member_ID, @MemberType_ID, @Privilege_ID, @StartRow, @EndRow, @SearchTable, @MemberCount OUTPUT;   
            EXEC mdm.udpUserMemberLastCountSave @User_ID, @Version_ID, @Entity_ID, @MemberType_ID, @MemberCount;   
        END; --if           
    END   
    ELSE IF @Mode = 5   
    BEGIN  
        SET @SqlParameters += N', @Value NVARCHAR(250)';  
        IF @CountOnly = 1 BEGIN -- count only  
            SET @SqlParameters += N', @MemberCount INT OUTPUT';  
            EXEC sp_executesql @SQL, @SqlParameters,  
                @User_ID, @Version_ID, @Hierarchy_ID, @Entity_ID, @Parent_ID, @Member_ID, @MemberType_ID, @Privilege_ID, @StartRow, @EndRow, @SearchTable, @TempAttributeValue, @MemberCount OUTPUT;  
        END ELSE BEGIN  
            EXEC sp_executesql @SQL, @SqlParameters,  
                @User_ID, @Version_ID, @Hierarchy_ID, @Entity_ID, @Parent_ID, @Member_ID, @MemberType_ID, @Privilege_ID, @StartRow, @EndRow, @SearchTable, @TempAttributeValue;  
        END; --if  
    END   
    ELSE IF @CountOnly = 1 -- count only   
    BEGIN  
        SET @SqlParameters += N', @MemberCount INT OUTPUT';  
        EXEC sp_executesql @SQL, @SqlParameters,  
            @User_ID, @Version_ID, @Hierarchy_ID, @Entity_ID, @Parent_ID, @Member_ID, @MemberType_ID, @Privilege_ID, @StartRow, @EndRow, @SearchTable, @MemberCount OUTPUT;  
    END ELSE   
    BEGIN  
        EXEC sp_executesql @SQL, @SqlParameters,  
            @User_ID, @Version_ID, @Hierarchy_ID, @Entity_ID, @Parent_ID, @Member_ID, @MemberType_ID, @Privilege_ID, @StartRow, @EndRow, @SearchTable;  
    END; --if  
    SET NOCOUNT OFF;  
END; --proc
GO
