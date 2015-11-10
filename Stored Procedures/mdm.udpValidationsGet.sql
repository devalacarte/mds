SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*    
==============================================================================    
 Copyright (c) Microsoft Corporation. All Rights Reserved.    
==============================================================================    
  
DECLARE @memberIds mdm.IdList;  
--INSERT INTO @memberIds VALUES (1),(2)  
  
exec mdm.udpValidationsGet 1,16,23,@memberIds,1    
exec mdm.udpValidationsGet 2,16,23,@memberIds,1    
    
exec mdm.udpValidationsGet 1,20,31,@memberIds,1    
exec mdm.udpValidationsGet 4,20,31,@memberIds,1    
    
exec mdm.udpValidationsGet 1,16,NULL,@memberIds    
exec mdm.udpValidationsGet 2,16,NULL,@memberIds    
    
exec mdm.udpValidationsGet null,16    
    
-- use paging within a version  
DECLARE @TotalCount INT;  
exec mdm.udpValidationsGet 1,20,NULL,@memberIds,NULL,NULL,1,50,N'MemberCode',N'ASC',@TotalCount OUTPUT;   
SELECT @TotalCount  
  
select * from mdm.tblValidationLog    
select * from mdm.viw_SYSTEM_ISSUE_VALIDATION    
select * from mdm.tblList    
  
  
Dependency: udpSecurityMembersResolverGet  
*/    
CREATE PROCEDURE [mdm].[udpValidationsGet]  
(    
    @User_ID		        INT,    
    @Version_ID		        INT,    
    @Entity_ID		        INT = NULL,    
    @Member_IDs		        mdm.IdList READONLY,    
    @MemberType_ID	        INT = NULL,    
    @NotificationUser_ID    INT = NULL,  
    @PageNumber             INT = NULL,  
    @PageSize               INT = NULL, -- Null: use system setting, <=0: return all records, X: return X records.  
    @SortColumn             sysname = NULL,  
    @SortDirection          NVARCHAR(4) = NULL,  
    @TotalIssueCount        INT OUTPUT        
)    
WITH EXECUTE AS N'mds_schema_user' -- Execute as a user that has permission to select on [tblUserGroupAssignment], [tblBRBusinessRule], [udfSecurityUserBusinessRuleList], [viw_SYSTEM_ISSUE_VALIDATION]  
AS BEGIN    
    SET NOCOUNT ON    
  
    -- Create a temp table to store the results  
    CREATE TABLE #ValidationIssueIDs (  
        [RowId]                 INT,  
        [ID]                    INT PRIMARY KEY CLUSTERED,   
        [Model_ID]              INT,    
        [Model_MUID]            UNIQUEIDENTIFIER,    
        [Model_Name]            NVARCHAR(50),    
        [Version_ID]            INT,    
        [Version_MUID]          UNIQUEIDENTIFIER,    
        [Version_Name]          NVARCHAR(50),    
        [Hierarchy_ID]          INT,    
        [Hierarchy_MUID]        UNIQUEIDENTIFIER,    
        [Hierarchy_Name]        NVARCHAR(50),    
        [Entity_ID]             INT,    
        [Entity_MUID]           UNIQUEIDENTIFIER,    
        [Entity_Name]           NVARCHAR(50),    
        [MemberType_ID]         TINYINT,    
        [Member_ID]             INT,    
        [MemberCode]            NVARCHAR(250),    
        [Description]           NVARCHAR(MAX),      
        [BRBusinessRule_ID]     INT,    
        [BRBusinessRule_MUID]   UNIQUEIDENTIFIER,    
        [BRBusinessRule_Name]   NVARCHAR(50),    
        [BRItem_ID]             INT,    
        [BRItem_MUID]           UNIQUEIDENTIFIER,    
        [BRItem_Name]           NVARCHAR(MAX),    
        [EnterDTM]              DATETIME2(3),     
        [EnterUserID]           INT,    
        [EnterUserMUID]         UNIQUEIDENTIFIER,    
        [EnterUserName]         NVARCHAR(100),     
        [LastChgDTM]            DATETIME2(3),     
        [LastChgUserID]         INT,    
        [LastChgUserMUID]       UNIQUEIDENTIFIER,    
        [LastChgUserName]       NVARCHAR(100),     
        [NotificationStatus_ID] INT   
        );    
  
    DECLARE   
        @SQL                NVARCHAR(MAX),  
        @PagingSQL          NVARCHAR(MAX) = N'',  
        @SortSQL            NVARCHAR(MAX),  
        @FromAndWhereSQL    NVARCHAR(MAX),  
        @StartRow           INT,  
        @EndRow             INT,  
        @SecurityLevel                     TINYINT,  
        @SecLvl_NoAccess                   TINYINT = 0,  
        @SecLvl_MemberSecurity             TINYINT = 2,  
        @SecLvl_ObjectAndMemberSecurity    TINYINT = 3,  
        @Permission_Deny       INT = 1;  
  
    ----------------------------------------------------------------------------------------  
    --Check security  
    ----------------------------------------------------------------------------------------  
    --Check Object Permissions.  Mark any attributes the user doesn't have permission to.  
    -- When checking validation status for whole versions, the @Entity_ID is not sent in  
    IF @Entity_ID IS NOT NULL  
    BEGIN  
        EXEC mdm.udpSecurityLevelGet @User_ID, @Entity_ID, @SecurityLevel OUTPUT;  
    END  
  
    --Only check for security level if we had an @Entity_ID sent in  
    IF @Entity_ID IS NULL OR @SecurityLevel <> @SecLvl_NoAccess  
    BEGIN  
        IF (@PageSize IS NULL)  
        BEGIN  
            SELECT @PageSize = SettingValue FROM mdm.tblSystemSetting WHERE SettingName = CAST(N'RowsPerBatch' AS NVARCHAR(100));          
            SET @PageSize = COALESCE(@PageSize, 0); -- If the system setting is null, return all records.    
        END;  
      
        -- Set sort column SQL.  
        SET @SortColumn = QUOTENAME(COALESCE(NULLIF(@SortColumn, N''), N'ID')); -- Sort by ID by default.  
        SET @SortDirection = CASE WHEN UPPER(@SortDirection) = N'DESC' THEN N'DESC' ELSE N'ASC' END; -- Sort ascending by default, and protect against SQL injection.  
        SET @SortSQL = @SortColumn + N' ' + @SortDirection;   
      
        -- Set paging SQL.  
      
        IF (@PageSize > 0)  
        BEGIN  
            -- Ensure page number is greater than zero.  
            IF (COALESCE(@PageNumber, 0) < 1)   
            BEGIN  
                SET @PageNumber = 1;  
            END  
  
            SET @StartRow = (COALESCE(@PageNumber, 1) - 1) * (@PageSize) + 1;  
            SET @EndRow = @StartRow + @PageSize - 1;  
            SET @PagingSQL = N'  
                    WHERE RowId BETWEEN @StartRow AND @EndRow';  
        END;  
  
  
        SET @FromAndWhereSQL = N'  
                    FROM mdm.viw_SYSTEM_ISSUE_VALIDATION L';  
        IF (EXISTS(SELECT 1 FROM @Member_IDs))  
        BEGIN  
            SET @FromAndWhereSQL += N'  
                    INNER JOIN @Member_IDs m   
                        ON m.ID = L.Member_ID';  
        END  
  
        --Create a temp table to cache the list of business rules this user has access to  
        CREATE TABLE #BusinessRuleList  
        (  
            BusinessRule_ID INT PRIMARY KEY CLUSTERED  
        );  
  
        --Fill the temp table up with the list of business rule IDs  
        INSERT INTO #BusinessRuleList  
        SELECT BusinessRule_ID FROM mdm.udfSecurityUserBusinessRuleList(@User_ID, @Entity_ID, @MemberType_ID);  
  
        SET @FromAndWhereSQL += N'  
                    INNER JOIN #BusinessRuleList AS BRACL  
                        ON BRACL.BusinessRule_ID = L.BRBusinessRule_ID  
                    LEFT JOIN mdm.tblBRBusinessRule BR       
                        ON BR.ID = L.BRBusinessRule_ID                        
                    WHERE  
                        L.Version_ID = @Version_ID     
                        AND (@NotificationUser_ID IS NULL OR     
                            BR.NotificationUserID = @NotificationUser_ID OR     
                            BR.NotificationGroupID IN (SELECT UserGroup_ID FROM mdm.tblUserGroupAssignment uga WHERE uga.[User_ID] = @NotificationUser_ID))';  
        SET @SQL = N'  
                -- Use a CTE to apply sorting and paging  
                WITH pageItems AS (  
                    SELECT   
                        ROW_NUMBER() OVER (ORDER BY L.' + @SortSQL + N') AS RowId,  
                        L.*' +  
                        @FromAndWhereSQL + N'  
                    )   
                -- Insert the specified page of results into the temp table      
                INSERT INTO #ValidationIssueIDs   
                SELECT *  
                FROM pageItems' +   
                @PagingSQL + N';  
  
                -- Get the total number of validaiton issues  
                SET @TotalIssueCount =  @@ROWCOUNT;  
                IF (@StartRow > 1 OR @PageSize = @TotalIssueCount)   
                BEGIN  
                    -- Paging is being used and the results set may only be a subset of the total number of   
                    -- results, so re-execute the query (without paging) to get the total row count.  
                    SET @TotalIssueCount = (  
                        SELECT COUNT(*) ' +  
                        @FromAndWhereSQL + N');  
                END;';  
       -- PRINT @SQL   
  
        -- Execute SQL  
        DECLARE @SqlParameters AS NVARCHAR(MAX) = N'@User_ID INT, @Version_ID INT, @Entity_ID INT, @Member_IDs mdm.IdList READONLY, @MemberType_ID INT, @NotificationUser_ID INT, @StartRow INT, @EndRow INT, @PageSize INT, @TotalIssueCount INT OUTPUT';  
        EXEC sp_executesql @SQL, @SqlParameters,  
            @User_ID, @Version_ID, @Entity_ID, @Member_IDs, @MemberType_ID, @NotificationUser_ID, @StartRow, @EndRow, @PageSize, @TotalIssueCount OUTPUT;   
      
        -- Remove the RowId column, which is no longer needed now that sorting and paging has been applied.  
        ALTER TABLE #ValidationIssueIDs DROP COLUMN RowId;  
      
        DECLARE     
            @emptyCriteria      mdm.MemberGetCriteria,    
            @memberCount        INT,    
            @memberId           INT,    
            @entityId           INT,    
            @memberTypeId       INT;    
  
        --If getting issues for a notification recipient user or a single member, determine if user has permission to view member    
        --Model admins have permission for entire model so no need to check member security.    
        IF (@NotificationUser_ID IS NOT NULL OR EXISTS(SELECT 1 FROM @Member_IDs)) AND @SecurityLevel IN (@SecLvl_MemberSecurity, @SecLvl_ObjectAndMemberSecurity)  
        BEGIN        
            DECLARE @MemberPermissions AS TABLE (ID INT, MemberType_ID INT, Privilege_ID INT);  
            DECLARE @MemberPermissionsInput mdm.MemberId;  
  
            --Select member IDs into the input parameter for security members resolver get  
            INSERT INTO @MemberPermissionsInput(ID, MemberType_ID)  
            SELECT     
                DISTINCT     
                 VI.Member_ID    
                ,VI.MemberType_ID    
            FROM     
                #ValidationIssueIDs VI;  
  
            --Select the output from security resolver into a table valued variable  
            INSERT INTO @MemberPermissions  
            EXEC mdm.udpSecurityMembersResolverGet @User_ID = @User_ID, @Version_ID = @Version_ID, @Entity_ID = @Entity_ID, @MemberIds = @MemberPermissionsInput;  
  
            --Delete all issues for members the the user does not have access to. We only want to eliminate  
            --the denies. The reads and updates can stay.   
            DELETE Issues  
            FROM #ValidationIssueIDs Issues  
            INNER JOIN @MemberPermissions Prm ON Prm.ID = Issues.Member_ID  
            WHERE     
                Prm.Privilege_ID = @Permission_Deny;  
        END    
    END  
             
    -- Return the results.   
    SET @SQL = N'SELECT * FROM #ValidationIssueIDs ORDER BY ' + @SortSQL + N';';  
    EXEC sp_executesql @SQL;  
    SET NOCOUNT OFF    
    
END --proc
GO
