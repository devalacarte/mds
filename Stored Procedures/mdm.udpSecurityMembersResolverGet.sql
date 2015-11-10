SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
*** NOTE: ANY CHANGES TO THE COLUMNS RETURNED IN THIS PROCEDURE MUST BE MADE IN THE COMPANION STORED PROCEDURES: udpValidationsGet, udpEntityMembersUpdate, udpHierarchyMembersUpdate.    
  
Procedure  : mdm.udpSecurityMembersResolverGet  
Component  : Security  
Description: mdm.udpSecurityMembersResolverGet returns a list of members and privileges available for a user.  
Parameters : User ID, Version ID, Entity ID, Member Ids, ExplicitHierarchy_ID  
Return     : Table: ID, MemberType_ID, Privilege_ID  
  
Dependency : NA  
Called By  : udpValidationsGet, udpEntityMembersUpdate, udpHierarchyMembersUpdate  
Example    :   
            DECLARE @MemberIDs AS mdm.MemberId  
            INSERT INTO @MemberIDs (ID, MemberType_ID)  
            VALUES (880, 1), (881, 1), (901, 1)  
      
            EXEC mdm.udpSecurityMemberResolverGet @User_ID = 1, @Version_ID = 20, @MemberIds = @MemberIDs, @ExplicitHierarchy_ID = 10  
*/  
CREATE PROCEDURE [mdm].[udpSecurityMembersResolverGet]  
(  
    @User_ID    INT,  
    @Version_ID INT,  
    @Entity_ID  INT,  
    @MemberIds  mdm.MemberId READONLY,  
    @ExplicitHierarchy_ID INT = NULL -- Pass a non-NULL value when determining a user's permission for changing explicit hierarchy relationships, in which   
                                     -- case special node types (ROOT, MDMUNUSED) are treated differently. That it, the result set of this sproc will indicate  
                                     -- whether the given user has permission to move members to and from ROOT/MDMUNUSED.  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
  
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED   
  
    DECLARE @SecurityTable sysname;  
    DECLARE @SQL NVARCHAR(MAX);  
    SELECT  @SecurityTable = SecurityTable FROM mdm.tblEntity WHERE ID = @Entity_ID;  
  
    -- This pseudo-constant is for use in string concatenation operations to prevent string truncation. When concatenating two or more strings,  
    -- if none of the strings is an NVARCHAR(MAX) or an NVARCHAR constant that is longer than 4,000 characters, then the resulting string   
    -- will be silently truncated to 4,000 characters. Concatenating with this empty NVARCHAR(MAX), is sufficient to prevent truncation.  
    -- See http://connect.microsoft.com/SQLServer/feedback/details/283368/nvarchar-max-concatenation-yields-silent-truncation.  
    DECLARE @TruncationGuard NVARCHAR(MAX) = N'';  
  
    -- Preloading the members into an indexed temp table is better for perf than directly joining with un-indexed @MemberIds. A temp table is  
    -- used instead of a table var so that a multi-column index may be used.  
    CREATE TABLE #MemberIds   
    (  
        Member_ID INT NOT NULL,  
        MemberType_ID INT NOT NULL,  
        Privilege_ID INT  
    );  
    CREATE UNIQUE CLUSTERED INDEX #ix_MemberIds_Member_ID_MemberType_ID ON #MemberIds (Member_ID, MemberType_ID);  
    INSERT INTO #MemberIds (Member_ID, MemberType_ID)  
    SELECT DISTINCT  
         ID  
        ,MemberType_ID  
    FROM @MemberIds  
    WHERE  
            ID IS NOT NULL  
        AND MemberType_ID IS NOT NULL;  
  
        --!!DO NOT CHANGE!! the order or names of columns returned by this without updating udpValidationsGet, udpEntityMembersUpdate, udpHierarchyMembersUpdate  
        SET @SQL = @TruncationGuard + N'  
    -- Preloading the user''s roles into a table var is better for perf than directly joining with viw_SYSTEM_SECURITY_USER_ROLE.   
    -- Testing on large (~1M members) data sets showed that using a table var is slightly (10-20%) faster than using a temp table.  
    DECLARE @SecurityRoles TABLE(Role_ID INT PRIMARY KEY);  
    INSERT INTO @SecurityRoles  
    SELECT Role_ID FROM mdm.[viw_SYSTEM_SECURITY_USER_ROLE] WHERE User_ID = @User_ID;  
      
    DECLARE   
         @Root_ID                   INT = 0  
        ,@Unused_ID                 INT = -1  
        ,@MemberType_Consolidated   INT = 2  
        ,@Permission_Deny           INT = 1  
        ,@Permission_Update         INT = 2  
        ,@Permission_ReadOnly       INT = 3  
        ,@Permission_Inferred       INT = 99;  
  
    -- If an Explicit Hierarchy was specified then get permissions to see if nodes can be moved to/from special node types ROOT and   
    -- MDMUNUSED (if those special nodes were included in the input list of members)  
    IF @ExplicitHierarchy_ID IS NOT NULL  
    BEGIN  
        -- See if the user has explicit permission on the ROOT node of the specified hierarchy.  
        -- Note that if it doesn''t, a query further down (the one that handles regular members) will check for inferred permission on ROOT.  
        DECLARE @Root_Permission INT = NULL;  
        SELECT  
            @Root_Permission = MIN(X.Privilege_ID)  
        FROM mdm.tblSecurityRoleAccessMember X  
        INNER JOIN @SecurityRoles R  
            ON X.Role_ID = R.Role_ID  
        WHERE  
                X.Version_ID = @Version_ID  
            AND X.Entity_ID = @Entity_ID  
            AND X.Member_ID = @Root_ID  
            AND X.MemberType_ID = @MemberType_Consolidated  
            AND X.ExplicitHierarchy_ID = @ExplicitHierarchy_ID;  
  
        UPDATE m  
        SET Privilege_ID = @Root_Permission  
        FROM #MemberIds m  
        WHERE  
                m.Member_ID = @Root_ID  
            AND m.MemberType_ID = @MemberType_Consolidated;  
  
        -- Explicit permissions cannot be assigned to MDMUNUSED. It has an assumed Update permission.  
        UPDATE m  
        SET Privilege_ID = @Permission_Update  
        FROM #MemberIds m  
        WHERE  
                m.Member_ID = @Unused_ID  
            AND m.MemberType_ID = @MemberType_Consolidated;  
    END;  
  
    WITH membersresolved AS  
    (  
        SELECT  
            COALESCE(X.EN_ID, X.HP_ID) AS Member_ID,  
            X.MemberType_ID,  
            MIN(X.Privilege_ID) AS Privilege_ID  
        FROM mdm.' + QUOTENAME(@SecurityTable) + N' X  
        INNER JOIN @SecurityRoles R  
            ON X.SecurityRole_ID = R.Role_ID  
        WHERE  
            X.Version_ID = @Version_ID  
        GROUP BY  
            COALESCE(X.EN_ID, X.HP_ID),  
            X.MemberType_ID  
    )  
    UPDATE m  
    SET Privilege_ID = CASE WHEN  
            res.Privilege_ID IS NULL THEN   
                CASE WHEN  m.MemberType_ID = @MemberType_Consolidated Then @Permission_Inferred ELSE @Permission_Deny END  
            ELSE COALESCE(NULLIF(res.Privilege_ID, 0), @Permission_Deny) END --Absence of record is effective deny  
    FROM #MemberIds m  
    LEFT JOIN membersresolved res  
    ON      m.Member_ID     = res.Member_ID  
        AND m.MemberType_ID = res.MemberType_ID  
    WHERE m.Privilege_ID IS NULL;  
  
    SELECT  
         Member_ID      AS ID  
        ,MemberType_ID  AS MemberType_ID  
        ,Privilege_ID   AS Privilege_ID  
    FROM #MemberIds;  
    ';  
    EXEC sp_executesql @SQL,  
        N'@User_ID INT, @Version_ID INT, @Entity_ID INT, @ExplicitHierarchy_ID INT',  
        @User_ID, @Version_ID, @Entity_ID, @ExplicitHierarchy_ID;  
                      
    SET NOCOUNT OFF  
      
END --proc
GO
