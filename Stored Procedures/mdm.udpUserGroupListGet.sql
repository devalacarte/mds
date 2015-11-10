SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
EXEC mdm.udpUserGroupListGet  
EXEC mdm.udpUserGroupListGet 'Name', 'DESC'  
*/  
CREATE PROCEDURE [mdm].[udpUserGroupListGet]  
   (  
    @SortColumn		sysname = NULL,  
    @SortDirection		NCHAR(4)    
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
    DECLARE	@QuotedSortColumn NVARCHAR(258);      
  
    IF @SortColumn IS NOT NULL  
    BEGIN  
        IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS  
            WHERE COLUMN_NAME = @SortColumn  
            AND TABLE_NAME = N'tblUserGroup'  
            AND TABLE_SCHEMA = N'mdm')  
            BEGIN  
                RAISERROR('MDSERR200087|Sort Column not found in target table.', 16, 1);  
                RETURN;  
            END  
    END  
    ELSE  
    BEGIN  
        SET @SortColumn = CAST(N'Name' AS sysname)  
    END  
      
    IF Left(@SortColumn,1) <> N'['  
        SET @QuotedSortColumn = QUOTENAME(@SortColumn)  
    ELSE  
        SET @QuotedSortColumn = @SortColumn  
      
    IF ((@SortDirection IS NOT NULL ) AND (UPPER(@SortDirection) <> N'ASC' AND UPPER(@SortDirection) <> N'DESC'))   
        BEGIN  
            RAISERROR('MDSERR200086|Invalid Sort Direction.  Supported Values are ''ASC'' and ''DESC''.', 16, 1);  
            RETURN;  
        END;  
    ELSE IF (@SortDirection IS NULL)  
    BEGIN  
        SET @SortDirection= CAST(N'ASC' AS NCHAR(4))  
    END   
      
    DECLARE @SQL	NVARCHAR(MAX)  
    SELECT @SQL = N'  
                SELECT  
                    S.ID,  
                    S.MUID,  
                    S.UserGroupType_ID,  
                    S.SID,  
                    S.Name,  
                    S.Description  
                FROM  
                    mdm.tblUserGroup S  
                WHERE  
                    Status_ID = 1  
                    ORDER BY   
                    ' + @QuotedSortColumn;  
      
    IF UPPER(@SortDirection) = N'ASC'        					  
        SET @SQL = @SQL + N' ASC'  
    ELSE  
        SET @SQL = @SQL + N' DESC'  
                  
  
    EXEC sp_executesql @SQL  
  
    SET NOCOUNT OFF  
END --proc
GO
