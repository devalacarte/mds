SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
--Data, no XML return  
EXEC   
    mdm.udpTransactionLogGet  
        @Model_MUID             = NULL,  
        @Model_ID                 = NULL,  
        @Model_Name             = NULL,  
        @Version_MUID            = NULL,  
        @Version_ID                =12,  
        @Version_Name            = NULL,  
        @Entity_MUID            = NULL,      
        @Entity_ID                 = NULL,  
        @Entity_Name            = NULL,  
        @Attribute_MUID            = NULL,  
        @Attribute_ID             = NULL,  
        @Attribute_Name            = NULL,  
        @ExplicitHierarchy_MUID = NULL,  
        @ExplicitHierarchy_Name = NULL,  
        @User_MUID                = NULL,      
        @User_ID                = NULL,  
        @User_Name                = NULL,  
        @Member_ID                 = NULL,  
        @MemberType                = NULL,      
        @Transaction_ID            = NULL,  
        @TransactionType        = NULL,  
        @NewValue                = NULL,  
        @PriorValue                = NULL,  
        @MemberCode                = NULL,  
        @DateTimeBeginRange        = NULL,  
        @DateTimeEndRange        = '2008-07-28 12:51:55.999',  
        @PageNumber                = NULL,  
        @PageSize                = NULL,  
        @SortColumn                = NULL,  
        @SortDirection            = NULL,  
        @CountOnly                = 0,  
        @IDOnly                    = 0,  
        @debug                    = 1,  
        @ReturnXML                = 0  
  
  
select * from mdm.viw_SYSTEM_TRANSACTIONS  
*/  
CREATE PROCEDURE [mdm].[udpTransactionLogGet]  
(  
    @Model_MUID             uniqueidentifier = NULL,  
    @Model_ID                 INT = NULL,  
    @Model_Name             NVARCHAR(100) = NULL,  
    @Version_MUID            uniqueidentifier = NULL,  
    @Version_ID             INT = NULL,  
    @Version_Name            NVARCHAR(100) = NULL,  
    @Entity_MUID            uniqueidentifier = NULL,      
    @Entity_ID                 INT = NULL,  
    @Entity_Name            NVARCHAR(100) = NULL,  
    @Attribute_MUID            uniqueidentifier = NULL,  
    @Attribute_ID             INT = NULL,  
    @Attribute_Name            NVARCHAR(100) = NULL,  
    @ExplicitHierarchy_MUID uniqueidentifier = NULL,  
    @ExplicitHierarchy_Name NVARCHAR(100) = NULL,  
    @User_MUID                uniqueidentifier = NULL,      
    @User_ID                INT = NULL,  
    @User_Name                NVARCHAR(100) = NULL,  
    @Member_ID                 INT = NULL,  
    @MemberType                NVARCHAR(200) = NULL,      
    @Transaction_ID            INT = NULL,  
    @TransactionType        NVARCHAR(500) = NULL,  
    @NewValue                NVARCHAR(MAX) = NULL,  
    @PriorValue                NVARCHAR(MAX) = NULL,  
    @MemberCode                NVARCHAR(500) = NULL,  
    @DateTimeBeginRange        DATETIME2(3) = null,  
    @DateTimeEndRange        DATETIME2(3) = null,  
    @PageNumber                INT = NULL,  
    @PageSize                INT = NULL,  
    @SortColumn                NVARCHAR(500) = NULL,  
    @SortDirection            NVARCHAR(5) = NULL,  
    @CountOnly                BIT = 0,  
    @IDOnly                    BIT = 0,  
    @debug                    BIT = 0,  
    @ReturnXML                BIT = 0  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
    DECLARE @SQL        NVARCHAR(MAX),  
        @paramList            NVARCHAR(MAX),  
        @strPageSize        NVARCHAR(30),  
        @strStartRow        NVARCHAR(30),  
        @strEndRow          NVARCHAR(30),  
        @Operator            NVARCHAR(5),  
        @ColumnString        NVARCHAR(MAX),  
        @WhereCriteria        NVARCHAR(max),  
        @AndReplace            NVARCHAR(17),  
        @TransactionType_ID INT;   
  
    SET @AndReplace     =N' @AndPlaceHolder '      
  
    IF ((@SortDirection IS NOT NULL ) AND (UPPER(@SortDirection) <> N'ASC' AND UPPER(@SortDirection) <> N'DESC'))   
        BEGIN  
            RAISERROR('MDSERR200086|Invalid Sort Direction.  Supported Values are ''ASC'' and ''DESC''.', 16, 1);  
            RETURN;  
        END;   
  
    IF @SortDirection IS NULL SET @SortDirection = CAST(N'ASC' AS NVARCHAR(5))  
  
    IF @SortColumn IS NOT NULL  
        BEGIN  
            IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS  
                WHERE COLUMN_NAME = @SortColumn  
                AND TABLE_NAME = N'viw_SYSTEM_TRANSACTIONS'  
                AND TABLE_SCHEMA = N'mdm')  
                BEGIN  
                    RAISERROR('MDSERR200087|Sort Column not found in target table.', 16, 1);  
                    RETURN;  
                END  
        END  
        ELSE  
        BEGIN  
            SET @SortColumn = CAST(N'Date Time' AS NVARCHAR(500))  
        END  
      
  
    SET @PageNumber = ISNULL(@PageNumber, 1);  
                  
    SET @WhereCriteria = CAST(N'' AS  NVARCHAR(max))  
    SET @paramList =  '@User_ID                 INT  
                      ,@User_MUID               UNIQUEIDENTIFIER  
                      ,@User_Name                NVARCHAR(100)   
                      ,@Model_ID                INT  
                      ,@Model_MUID              UNIQUEIDENTIFIER  
                      ,@Model_Name               NVARCHAR(100)  
                      ,@Version_ID              INT  
                      ,@Version_MUID            UNIQUEIDENTIFIER  
                      ,@Version_Name             NVARCHAR(100)  
                      ,@Entity_ID               INT  
                      ,@Entity_MUID             UNIQUEIDENTIFIER  
                      ,@Entity_Name              NVARCHAR(100)   
                      ,@Attribute_ID            INT  
                      ,@Attribute_MUID          UNIQUEIDENTIFIER  
                      ,@Attribute_Name           NVARCHAR(100)   
                      ,@ExplicitHierarchy_MUID  UNIQUEIDENTIFIER  
                      ,@ExplicitHierarchy_Name   NVARCHAR(100)   
                      ,@Member_ID               INT  
                      ,@MemberType              NVARCHAR(200)   
                      ,@NewValue                NVARCHAR(max)   
                      ,@PriorValue              NVARCHAR(max)   
                      ,@MemberCode              NVARCHAR(500)  
                      ,@Transaction_ID          INT  
                      ,@TransactionType_ID      INT  
                      ,@DateTimeBeginRange      DATETIME2(3)  
                      ,@DateTimeEndRange        DATETIME2(3)  
                        ';  
      
      
    IF @Model_MUID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Model_MUID = @Model_MUID';   
    END  
          
    IF @Model_ID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Model_ID = @Model_ID';  
    END  
          
    IF @Model_Name IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Model_Name LIKE @Model_Name';  
    END  
      
    IF @Version_MUID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Version_MUID = @Version_MUID';  
    END  
  
    IF @Version_ID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Version_ID = @Version_ID';  
    END  
          
    IF @Version_Name IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Version_Name LIKE @Version_Name';   
    END  
  
    IF @Entity_MUID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Entity_MUID = @Entity_MUID';  
    END  
  
    IF @Entity_ID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Entity_ID = @Entity_ID';  
    END  
  
    IF @Entity_Name IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Entity LIKE @Entity_Name';   
    END  
  
    IF @Attribute_MUID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Attribute_MUID = @Attribute_MUID';  
    END  
  
    IF @Attribute_ID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Attribute_ID = @Attribute_ID';  
    END  
  
    IF @Attribute_Name IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Attribute LIKE @Attribute_Name';   
    END  
  
    IF @ExplicitHierarchy_MUID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' ExplicitHierarchy_MUID = @ExplicitHierarchy_MUID';  
    END  
  
    IF @ExplicitHierarchy_Name IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' [Explicit Hierarchy] LIKE @ExplicitHierarchy_Name';   
    END  
  
    IF @User_MUID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' User_MUID = @User_MUID';  
    END  
  
    IF @User_ID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' [User ID] = @User_ID';  
    END  
      
    IF @User_Name IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' [User Name] LIKE @User_Name';   
    END  
      
    IF @Member_ID IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' Member_ID = @Member_ID';  
    END  
      
    IF @MemberType IS NOT NULL  
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' [Member Type] LIKE @MemberType';   
    END  
      
    IF @Transaction_ID IS NOT NULL    
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' ID = @Transaction_ID';  
    END  
      
    IF @TransactionType IS NOT NULL   
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' TransactionType_ID = @TransactionType_ID';  
        SET @TransactionType_ID = Case @TransactionType  
            WHEN 'CreateMember'         THEN 1  
            WHEN 'ChangeMemberStatus'   THEN 2  
            WHEN 'SetAttributeValue'    THEN 3  
            WHEN 'MoveMemberToParent'   THEN 4  
            WHEN 'MoveMemberToSibling'  THEN 5  
            WHEN 'AnnotateMember'       THEN 6  
            ELSE -1  
            END              
    END  
  
    IF @NewValue IS NOT NULL   
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' [New Value] LIKE @NewValue';   
    END  
    IF @PriorValue IS NOT NULL   
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' [Prior Value] LIKE @PriorValue';   
    END  
    IF @MemberCode IS NOT NULL   
    BEGIN  
        SET @WhereCriteria += @AndReplace + N' [Member Code] LIKE @MemberCode';   
    END      
    IF     @DateTimeBeginRange IS NOT NULL  
    BEGIN  
            SET @WhereCriteria += @AndReplace + N' [Date Time] >= @DateTimeBeginRange';  
    END      
    IF     @DateTimeEndRange IS NOT NULL  
    BEGIN  
            SET @WhereCriteria += @AndReplace + N' [Date Time] <= @DateTimeEndRange';  
    END      
          
    /*Now clean up the @MDMPlaceHolders.  First one becomes WHERE the rest are ANDS */  
    IF LEN(@WhereCriteria) <> 0  
    BEGIN  
        SET @WhereCriteria  = N'WHERE ' + SUBSTRING(@WhereCriteria,LEN(@AndReplace)+1,LEN(@WhereCriteria)-LEN(@AndReplace))  
        SET @WhereCriteria  = REPLACE( @WhereCriteria,@AndReplace,N' AND ')  
    END  
              
    IF @debug = 1  
        PRINT @WhereCriteria  
  
    /*Default Page Size*/  
    IF @PageSize IS NULL  
        SELECT @PageSize = CAST(SettingValue AS INT) FROM mdm.tblSystemSetting WHERE SettingName = CAST(N'RowsPerBatch' AS NVARCHAR(100));  
    SET @PageSize = ISNULL(@PageSize, 50);  
    SET @strPageSize = CONVERT(NVARCHAR(30), @PageSize);  
  
    /*Get Start Row */  
    IF @PageNumber <= 1 BEGIN  
        SET @PageNumber = 1;  
        SET @strStartRow = CAST(N'1' AS NVARCHAR(30));  
    END      
    ELSE   
    BEGIN  
        SET @strStartRow = CONVERT(NVARCHAR(30), (@PageNumber-1)*(@PageSize)+1);          
    END; --if  
  
    --Set the last row to return  
    SET @strEndRow = CONVERT(NVARCHAR(30), @PageNumber * @PageSize);  
      
    SELECT          
        @SQL = CAST(N'' AS NVARCHAR(max)),  
        /*Set @operator variables.*/      
        @Operator = CASE @SortDirection  
            WHEN N'DESC' THEN N'<'  
            ELSE N'>'  
        END;  
  
    IF @IDOnly = 1   
        BEGIN  
            SET @ColumnString = CAST(N'T.ID'  AS NVARCHAR(max));          
        END  
    ELSE IF @CountOnly = 1   
        BEGIN  
            SET @ColumnString = CAST(N'COUNT(T.ID) AS MemberRowCount' AS NVARCHAR(max));  
        END  
    ELSE   
        IF @ReturnXML <> 1  
        BEGIN  
            SET @ColumnString = CAST(N'  
                ID,  
                TransactionType_ID,  
                Type,  
                [Explicit Hierarchy],  
                Entity,  
                Attribute,      
                [Member Code],  
                [Member Type],  
                [Prior Value],  
                [New Value],  
                [Date Time],  
                [User Name]'  AS NVARCHAR(max))  
        END --@ReturnXML <> 1  
        ELSE  
        BEGIN  
            -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
            -- may fail (sometimes silently) to deserialize out-of-order columns.  
              
            -- Core.BusinessEntities.Transaction members                 
            SET @ColumnString = CAST(N'  
                [Attribute_ID]                      as ''AttributeId/Id'',      
                [Attribute_MUID]                    as ''AttributeId/Muid'',      
                Attribute                           as ''AttributeId/Name'',      
                CONVERT(sql_variant,[Date Time])    as ''Date'',  
                [Entity_ID]                         as ''EntityId/Id'',  
                [Entity_MUID]                       as ''EntityId/Muid'',  
                [Entity]                            as ''EntityId/Name'',  
                [ExplicitHierarchy_ID]              as ''ExplicitHierarchyId/Id'',  
                [ExplicitHierarchy_MUID]            as ''ExplicitHierarchyId/Muid'',  
                [Explicit Hierarchy]                as ''ExplicitHierarchyId/Name'',  
                ID                                  as Id,  
                [Member Code]                       as ''MemberId/Code'',  
                REPLACE([Member Type],'' '','''')   as ''MemberId/MemberType'',  
                ''''                                as ''MemberId/Name'',  
                REPLACE([Member Type],'' '','''')   as ''MemberType'',  
                Model_ID                            as ''ModelId/Id'',  
                Model_MUID                          as ''ModelId/Muid'',  
                Model_Name                          as ''ModelId/Name'',  
                [New Value]                         as ''NewValue'',  
                [Prior Value]                       as ''PriorValue'',  
                Case TransactionType_ID  
                    WHEN 1 then ''CreateMember''  
                    WHEN 2 then ''ChangeMemberStatus''  
                    WHEN 3 then ''SetAttributeValue''  
                    WHEN 4 then ''MoveMemberToParent''  
                    WHEN 5 then ''MoveMemberToSibling''  
                    WHEN 6 then ''AnnotateMember''  
                END                                 as TransactionType,  
                [User ID]                           as ''UserId/Id'',  
                [User_MUID]                         as ''UserId/Muid'',  
                [User Name]                         as ''UserId/Name'',  
                Version_ID                          as ''VersionId/Id'',  
                Version_MUID                        as ''VersionId/Muid'',  
                Version_Name                        as ''VersionId/Name''  
            '  AS NVARCHAR(max))  
        END  
  
  
    IF @CountOnly = 0   
    BEGIN  
        SET @SQL += N' WITH ctePaging AS  
            (  
                SELECT T.*, ROW_NUMBER() OVER(ORDER BY ' + QUOTENAME(@SortColumn) + N' ' + CASE @SortDirection WHEN N'ASC' THEN N'ASC' ELSE N'DESC' END + N') AS Row  
                FROM [mdm].[viw_SYSTEM_TRANSACTIONS] AS T '  
                + @WhereCriteria  
            + N'  
            )  
            SELECT ' + @ColumnString  
            + N' FROM ctePaging AS T   
            WHERE T.Row BETWEEN ' + @strStartRow + N' AND ' + @strEndRow;  
    END  
    ELSE  
    BEGIN  
        SET @SQL += N'              
            SELECT ' + @ColumnString + N'   
            FROM [mdm].[viw_SYSTEM_TRANSACTIONS] AS T '  
            + @WhereCriteria;   
    END  
          
    IF @ReturnXML = 1   
    BEGIN  
        SET @SQL += N' FOR XML PATH(''Transaction''),ELEMENTS,ROOT(''ArrayOfTransaction'')'  
    END  
  
    IF @debug=1  
    BEGIN  
        PRINT(@SQL);  
    END  
      
    EXEC sp_executesql @SQL, @paramList,   
              @User_ID  
              ,@User_MUID  
              ,@User_Name  
              ,@Model_ID  
              ,@Model_MUID  
              ,@Model_Name  
              ,@Version_ID  
              ,@Version_MUID  
              ,@Version_Name  
              ,@Entity_ID  
              ,@Entity_MUID  
              ,@Entity_Name  
              ,@Attribute_ID  
              ,@Attribute_MUID  
              ,@Attribute_Name  
              ,@ExplicitHierarchy_MUID  
              ,@ExplicitHierarchy_Name  
              ,@Member_ID  
              ,@MemberType  
              ,@NewValue  
              ,@PriorValue  
              ,@MemberCode  
              ,@Transaction_ID  
              ,@TransactionType_ID  
              ,@DateTimeBeginRange  
              ,@DateTimeEndRange  
      
    SET NOCOUNT OFF  
  
END --proc
GO
