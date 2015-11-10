SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpDataQualityResultsGet]  
    @DatabaseName sysname,  
    @SchemaName sysname,  
    @TableName sysname,  
    @StartRow INT,  
    @PageSize INT  
AS BEGIN  
    SET NOCOUNT ON;  
      
    -- Constant identifier column name  
    DECLARE @IdentifierColumn NVARCHAR(MAX)  
    SET @IdentifierColumn = 'CCD284C6-39DA-4192-81C9-E1FBBCCFEBE5'  
  
    DECLARE @LastRow INT  
    DECLARE @SQL NVARCHAR(MAX) -- Used to dynamic sql  
  
    DECLARE @FullTableName SYSNAME  
    SET @FullTableName = QUOTENAME(@DatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)  
  
    SET @SQL = N'  
    IF NOT EXISTS (SELECT 1 FROM ' + QUOTENAME(@DatabaseName) + N'.sys.columns WHERE object_id = OBJECT_ID(''' + @FullTableName + N''') AND [name] = ''' + @IdentifierColumn + N''')  
    BEGIN  
        -- If this is the first run since DQS returned results, add an identifier column to assist  
        -- in batching  
            ALTER TABLE ' + @FullTableName + N'  
            ADD ' + QUOTENAME(@IdentifierColumn) + N' INT IDENTITY(1,1) PRIMARY KEY  
    END  
    '  
    EXEC sp_executesql @SQL  
  
    SET @LastRow = @StartRow + @PageSize  
  
    SET @SQL = N'  
        SELECT *  
        FROM ' + @FullTableName + N'  
        WHERE ' + QUOTENAME(@IdentifierColumn) + N' BETWEEN ' + CONVERT(NVARCHAR(MAX), @StartRow) + N' AND ' +  CONVERT(NVARCHAR(MAX), @LastRow)   
  
    EXEC sp_executesql @SQL  
  
    SET NOCOUNT OFF;  
END; --proc
GO
