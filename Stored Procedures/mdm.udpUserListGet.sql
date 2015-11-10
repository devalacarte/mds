SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
EXEC mdm.udpUserListGet  
EXEC mdm.udpUserListGet 'EmailAddress', 'DESC'  
  
select * from mdm.tblUser  
update mdm.tblUser set Status_ID = 1  
update mdm.tblUser set LastChgUserID = 1  
*/  
CREATE PROCEDURE [mdm].[udpUserListGet]  
   (  
    @SortColumn		    sysname =   NULL,  
    @SortDirection		NCHAR(4)   
   )  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
    DECLARE	@ErrorMessage NVARCHAR(100),  
            @SQL	NVARCHAR(MAX),  
            @QuotedSortColumn nvarchar(258);  
      
    IF @SortColumn IS NOT NULL  
    BEGIN  
        IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS  
            WHERE COLUMN_NAME = @SortColumn  
            AND TABLE_NAME = N'tblUser'  
            AND TABLE_SCHEMA = N'mdm')  
            BEGIN  
                RAISERROR('MDSERR200087|Sort Column not found in target table.', 16, 1);  
                RETURN;  
            END  
    END  
    ELSE  
    BEGIN  
        SET @SortColumn = CAST(N'UserName' AS sysname)  
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
            SET @SortDirection= N'ASC'  
        END   
        SELECT @SQL = N'  
                SELECT   
                    U.ID,  
                    U.MUID,  
                    U.Status_ID,  
                    U.SID,  
                    U.UserName,  
                    U.DisplayName,  
                    U.Description,  
                    U.EmailAddress,  
                    LastLoginDTM,  
                    pref. PreferenceValue AS EmailType   
                FROM  
                    mdm.tblUser U  
                    LEFT OUTER JOIN mdm.tblUserPreference pref on U.ID = pref.User_ID AND PreferenceName=''lstEmail''  
                Where  
                    U.Status_ID = 1  
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
