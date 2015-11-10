SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
--Either active or inactive  
DECLARE @Tempvar NVARCHAR(250)  
EXEC mdm.udpMemberIDGetByCode 2,13,'01-A7150',1,@TempVar OUTPUT  
select @Tempvar  
  
  
  
--Active Only  
DECLARE @Tempvar NVARCHAR(250)  
EXEC mdm.udpMemberIDGetByCode 2,13,'01-A7150',1,@TempVar OUTPUT,1  
select @Tempvar  
  
*/  
CREATE PROCEDURE [mdm].[udpMemberIDGetByCode]  
(  
    @Version_ID     INTEGER,  
    @Entity_ID      INTEGER,  
    @MemberCode     NVARCHAR(250),  
    @MemberType_ID  TINYINT,  
    @ReturnID       INTEGER OUTPUT,  
    @IsActive       BIT = 1  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @SQL            NVARCHAR(MAX),  
            @TempTableName     sysname,  
            @TempCount         INTEGER,  
            @TempID            INTEGER;  
  
    -- Trim MemberCode  
    SET @MemberCode = NULLIF(LTRIM(RTRIM(@MemberCode)), N'');  
  
    SET @TempTableName = mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID);  
  
    IF @IsActive = 1   
        -- Return the ID only if the member is still active.  
        SET @SQL = N'  
            SELECT @TempID = ID FROM mdm.' + quotename(@TempTableName) + N'   
            WHERE Status_ID=1 AND Version_ID = @Version_ID  
            AND Code = @Code;';  
    ELSE  
        -- Return the ID if the member is active or inactive  
        SELECT @SQL = N'  
            SELECT @TempID = ID FROM mdm.' + quotename(@TempTableName) + N'   
            WHERE Version_ID = @Version_ID  
            AND Code = @Code;';  
  
    EXEC sp_executesql @SQL, N'@Version_ID INT, @Code NVARCHAR(250), @TempID int OUTPUT', @Version_ID, @MemberCode, @TempID OUTPUT;  
  
    SET @ReturnID = ISNULL(@TempID, 0);  
  
    SET NOCOUNT OFF;  
END; --proc
GO
