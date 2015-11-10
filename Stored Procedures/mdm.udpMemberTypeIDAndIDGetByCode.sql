SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
    --Type 1  
    DECLARE @TempMemberType_ID INT  
    DECLARE @TempMember_ID INT  
    EXEC mdm.udpMemberTypeIDAndIDGetByCode 2,7,'1150',@TempMemberType_ID OUTPUT,@TempMember_ID OUTPUT  
    SELECT @TempMember_ID, @TempMemberType_ID  
  
    --Type 2  
    DECLARE @TempMemberType_ID INT;  
    DECLARE @TempMember_ID INT;  
    EXEC mdm.udpMemberTypeIDAndIDGetByCode 2,7,'10',@TempMemberType_ID OUTPUT,@TempMember_ID OUTPUT  
    SELECT @TempMember_ID, @TempMemberType_ID  
  
    --Error  
    DECLARE @TempMemberType_ID INT  
    DECLARE @TempMember_ID INT  
    EXEC mdm.udpMemberTypeIDAndIDGetByCode 2,8,'KABOOM',@TempMemberType_ID OUTPUT,@TempMember_ID OUTPUT  
    SELECT @TempMember_ID, @TempMemberType_ID;  
*/  
CREATE PROCEDURE [mdm].[udpMemberTypeIDAndIDGetByCode]  
(  
    @Version_ID     INTEGER,  
    @Entity_ID      INTEGER,  
    @MemberCode     NVARCHAR(250),  
    @MemberType_ID  TINYINT = NULL OUTPUT,  
    @Member_ID      INTEGER = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
    
    DECLARE @sql            NVARCHAR(MAX);  
    DECLARE @TempTableName  sysname;  
    DECLARE @TempID         INTEGER;   
      
    --Initialize output variables  
    SELECT @MemberType_ID = NULL, @Member_ID = NULL;  
  
    -- Trim MemberCode  
    SET @MemberCode = NULLIF(LTRIM(RTRIM(@MemberCode)), N'');  
  
    --Check from ROOT  
    IF @MemberCode IS NULL OR LEN(@MemberCode) = 0 OR UPPER(@MemberCode) = N'ROOT' BEGIN              
        SELECT @MemberType_ID = 2, @Member_ID = 0;  
        RETURN(0);  
    END; --if  
  
    --Check from UnUsed(Non mandatory hierarchies)  
    IF UPPER(@MemberCode) = N'MDMUNUSED' BEGIN              
        SELECT @MemberType_ID = 2, @Member_ID = -1;  
        RETURN(0);  
    END; --if  
  
    --Type 1 (EntityTable)  
    BEGIN  
        SELECT @TempTableName = mdm.udfTableNameGetByID(@Entity_ID, 1);  
        SET @sql = N'  
            SELECT TOP 1 @TempID = ID FROM mdm.' + quotename(@TempTableName) + N'   
            WHERE Version_ID = @Version_ID AND Code = @Code ORDER BY ID;';  
        EXEC sp_executesql @sql, N'@Code NVARCHAR(250), @Version_ID INT, @TempID INT OUTPUT', @MemberCode, @Version_ID, @TempID OUTPUT;  
  
        IF ISNULL(@TempID, 0) <> 0 BEGIN  
            SELECT @MemberType_ID = 1, @Member_ID = @TempID;  
            RETURN(0);  
        END; --if  
    END; ---begin  
      
    IF mdm.udfEntityHasHierarchy(@Entity_ID) = 1 BEGIN  
        --Type 2 (HierarchyParentTable)  
        SELECT @TempTableName = mdm.udfTableNameGetByID(@Entity_ID, 2);  
        SET @sql = N'  
            SELECT TOP 1 @TempID=ID FROM mdm.' + quotename(@TempTableName) + N'   
            WHERE Version_ID = @Version_ID AND Code = @Code ORDER BY ID;';  
        EXEC sp_executesql @sql, N'@Code NVARCHAR(250), @Version_ID INT, @TempID INT OUTPUT', @MemberCode, @Version_ID, @TempID OUTPUT;  
          
        IF ISNULL(@TempID, 0) <> 0 BEGIN  
            SELECT @MemberType_ID = 2, @Member_ID = @TempID;  
            RETURN(0);  
        END; --if  
  
        --Type 3 (CollectionTable)  
        SELECT @TempTableName = mdm.udfTableNameGetByID(@Entity_ID, 3);  
        SELECT @sql = N'  
            SELECT TOP 1 @TempID=ID FROM mdm.' + quotename(@TempTableName) + N'   
            WHERE Version_ID = @Version_ID AND Code = @Code ORDER BY ID;';  
        EXEC sp_executesql @sql, N'@Code NVARCHAR(250), @Version_ID INT, @TempID INT OUTPUT', @MemberCode, @Version_ID, @TempID OUTPUT;  
          
        IF ISNULL(@TempID, 0) <> 0 BEGIN  
            SELECT @MemberType_ID = 3, @Member_ID = @TempID;  
            RETURN(0);  
        END; --if  
          
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
