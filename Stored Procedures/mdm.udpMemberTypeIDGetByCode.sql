SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
    DECLARE @Tempvar NVARCHAR(250)  
    EXEC mdm.udpMemberTypeIDGetByCode 5,12,'DZD',@TempVar OUTPUT  
    select @Tempvar  
*/  
CREATE PROCEDURE [mdm].[udpMemberTypeIDGetByCode]  
(  
    @Version_ID INTEGER,  
    @Entity_ID  INTEGER,  
    @MemberCode NVARCHAR(250),  
    @ReturnID   TINYINT = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @SQL            NVARCHAR(MAX)  
    DECLARE @TempCount      INTEGER  
    DECLARE @TempTableName  sysname  
    DECLARE @TempID         INTEGER  
  
    -- Trim MemberCode  
    SET @MemberCode = NULLIF(LTRIM(RTRIM(@MemberCode)), N'');  
  
    --Type 1  
    SET @TempTableName = mdm.udfTableNameGetByID(@Entity_ID,1);  
    SET @SQL = N'  
        SET @TempCount = CASE  
            WHEN EXISTS(SELECT 1 FROM mdm.' + quotename(@TempTableName) + N'   
                WHERE Version_ID = @Version_ID  
                AND Code = @Code) THEN 1  
            ELSE 0  
        END; --case';  
    EXEC sp_executesql @SQL, N'@Version_ID INT, @Code NVARCHAR(250), @TempCount INT OUTPUT', @Version_ID, @MemberCode, @TempCount OUTPUT;  
  
    IF @TempCount <> 0 BEGIN  
  
        SET @ReturnID = 1;  
  
    END ELSE IF mdm.udfEntityHasHierarchy(@Entity_ID) = 1 BEGIN  
        --Type 2  
  
        SET @TempTableName = mdm.udfTableNameGetByID(@Entity_ID,2);  
        SET @SQL = N'  
            SET @TempCount = CASE  
                WHEN EXISTS(SELECT 1 FROM mdm.' + quotename(@TempTableName) + N'   
                    WHERE Version_ID = @Version_ID   
                    AND Code = @Code) THEN 1  
                ELSE 0  
            END; --case';  
        EXEC sp_executesql @SQL, N'@Version_ID INT, @Code NVARCHAR(250), @TempCount INT OUTPUT', @Version_ID, @MemberCode, @TempCount OUTPUT;  
          
        IF @TempCount <> 0 BEGIN  
  
            SET @ReturnID = 2;  
  
        END ELSE BEGIN  
            --Type 3  
  
            SET @TempTableName = mdm.udfTableNameGetByID(@Entity_ID,3)  
            SET @SQL = N'  
                SET @TempCount = CASE  
                    WHEN EXISTS(SELECT 1 FROM mdm.' + quotename(@TempTableName) + N'   
                        WHERE Version_ID = @Version_ID   
                        AND Code = @Code) THEN 1  
                    ELSE 0  
                END; --case';  
            EXEC sp_executesql @SQL, N'@Version_ID INT, @Code NVARCHAR(250), @TempCount INT OUTPUT', @Version_ID, @MemberCode, @TempCount OUTPUT;  
              
            IF @TempCount <> 0 SET @ReturnID = 3;  
        END; --if  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
