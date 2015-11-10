SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Looks up the IDs and MemberTypes of the given list of member codes for the given entity and version. If the code   
cannot be found, it is omitted from the result set. This is the set-based version of the udpMemberTypeIDAndIDGetByCode  
sproc that only operates on a single member.  
  
DECLARE    @MemberIds      mdm.MemberId;  
INSERT INTO @MemberIds (Code) VALUES (N'MyMemberCode')  
EXEC mdm.udpMembersTypeIDAndIDGetByCode  
     @Version_ID =    3  
    ,@Entity_ID =     6  
    ,@ActiveMembersOnly = 1  
    ,@MemberIds = @MemberIds;  
*/  
CREATE PROCEDURE [mdm].[udpMembersTypeIDAndIDGetByCode]  
(  
     @Version_ID         INT  
    ,@Entity_ID          INT  
    ,@ActiveMembersOnly  BIT = 1 -- When 1, inactive (soft-deleted) members are ignored.  
    ,@MemberIds      mdm.MemberId READONLY  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
    DECLARE   
         @SQL                       NVARCHAR(MAX)  
        ,@Criteria                  NVARCHAR(MAX)  
        ,@TableName                 SYSNAME  
  
        -- Member types  
        ,@MemberType_NotSpecified   INT = 0  
        ,@MemberType_Leaf           NVARCHAR(1) = N'1'  
        ,@MemberType_Consolidated   NVARCHAR(1) = N'2'  
        ,@MemberType_Collection     NVARCHAR(1) = N'3'  
  
        -- IDs of special hierarchy parent node members  
        ,@MemberId_RootNode         INT = 0  
        ,@MemberId_UnusedNode       INT = -1;  
  
    -- Create a table to store member info. Use a temp table rather than a table var so that it can be used by dynamic SQL (can't pass a table var as a parameter)  
    CREATE TABLE #MemberIdsWorkingSet   
    (  
         Code NVARCHAR(250) COLLATE DATABASE_DEFAULT PRIMARY KEY NOT NULL  
        ,ID INT   
        ,MemberType_ID INT   
    );  
  
    INSERT INTO #MemberIdsWorkingSet (Code)  
    SELECT DISTINCT  
        LTRIM(RTRIM(Code)) -- Trim member code  
    FROM  
        @MemberIds  
    WHERE NULLIF(LTRIM(RTRIM(Code)), N'') IS NOT NULL; -- strip out invalid blank codes.  
  
    -- Check for special hierarchy root node members  
    UPDATE #MemberIdsWorkingSet  
    SET  
        ID = @MemberId_RootNode,  
        MemberType_ID = @MemberType_NotSpecified  
    WHERE UPPER(Code) = N'ROOT'  
  
    UPDATE #MemberIdsWorkingSet  
    SET  
        ID = @MemberId_UnusedNode,  
        MemberType_ID = @MemberType_Consolidated  
    WHERE UPPER(Code) = N'MDMUNUSED'  
  
    SET @Criteria = N'  
            ON ws.Code = mem.Code  
        WHERE  
                mem.Version_ID = @Version_ID  
            AND ws.ID IS NULL -- Skip rows that have already been looked up.';  
    IF @ActiveMembersOnly = 1  
    BEGIN  
        SET @Criteria += N'  
            AND mem.Status_ID = 1 -- Skip rows that have been soft-deleted.';  
    END;  
  
    --Type 1 (EntityTable)  
    SELECT @TableName = mdm.udfTableNameGetByID(@Entity_ID, 1 /*EntityTable*/);  
    SET @SQL = N'  
        UPDATE ws  
        SET  
             ws.ID              = mem.ID  
            ,ws.MemberType_ID   = ' + @MemberType_Leaf + N'  
        FROM #MemberIdsWorkingSet ws  
        INNER JOIN mdm.' + QUOTENAME(@TableName) + N' mem' +  
            @Criteria;  
  
    EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;  
  
    IF EXISTS(SELECT 1 FROM #MemberIdsWorkingSet WHERE MemberType_ID IS NULL) AND  
       mdm.udfEntityHasHierarchy(@Entity_ID) = 1  
    BEGIN  
        --Type 2 (HierarchyParentTable)  
        SELECT @TableName = mdm.udfTableNameGetByID(@Entity_ID, 2 /*HierarchyParentTable*/);  
        SET @SQL = N'  
            UPDATE ws  
            SET  
                 ws.ID              = mem.ID  
                ,ws.MemberType_ID   = ' + @MemberType_Consolidated + N'  
            FROM #MemberIdsWorkingSet ws  
            INNER JOIN mdm.' + QUOTENAME(@TableName) + N' mem' +  
                @Criteria;  
        EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;  
  
        --Type 3 (CollectionTable)  
        SELECT @TableName = mdm.udfTableNameGetByID(@Entity_ID, 3 /*CollectionTable*/);  
        SET @SQL = N'  
            UPDATE ws  
            SET  
                 ws.ID              = mem.ID  
                ,ws.MemberType_ID   = ' + @MemberType_Collection + N'  
            FROM #MemberIdsWorkingSet ws  
            INNER JOIN mdm.' + QUOTENAME(@TableName) + N' mem' +  
                @Criteria;  
        EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;  
    END; --if  
  
    -- Return member info  
    SELECT  
        ID,  
        MemberType_ID,  
        Code  
    FROM #MemberIdsWorkingSet  
    WHERE ID IS NOT NULL; -- Do not include invalid member codes in the result set   
  
    SET NOCOUNT OFF;  
END; --proc
GO
