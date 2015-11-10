SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
/*  
    We call the [udpCircularReferenceMemberCodesGet] SPROC to figure out whether the provided member codes being updated are  
    part of a circular reference. The member codes to check for are provided in the @MemberAttributes param and the view  
    that defines the hierarchy (derived only) to check is provided in the @RecursiveDerivedView param.  
  
    It is also possible to use this SPROC to check the whole hierarchy for circular/cyclical references. To do that, do  
    not pass in anything for @MemberAttributes  
  
    DECLARE @MemberAttributes mdm.MemberAttributes;  
    INSERT INTO @MemberAttributes (MemberCode, AttributeName, AttributeValue)  
    VALUES  
         (N'A', N'ModelName', N'DEF')  
        ,(N'B', N'ModelName', N'DEF')  
    ;  
    --Validate the supplied member codes for circular references  
    EXEC mdm.udfCircularReferenceMemberCodesGet N'mdm.viw_SYSTEM_10_12_PARENTCHILD_DERIVED', @MemberAttributes;  
      
    OR  
  
    --Validate the whole entity/hierarchy for circular references  
    EXEC mdm.udfCircularReferenceMemberCodesGet N'mdm.viw_SYSTEM_10_12_PARENTCHILD_DERIVED';  
  
*/  
CREATE PROCEDURE [mdm].[udpCircularReferenceMemberCodesGet]  
(  
    @RecursiveDerivedView    sysname,  
    @MemberAttributes        mdm.MemberAttributes READONLY  
)   
AS   
BEGIN  
    CREATE TABLE #CircularReferenceCodes  
    (            
         MemberCode            NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL  
    );  
    DECLARE @SQL    NVARCHAR(MAX) = N'';  
    DECLARE @CircularReferencedMemberCodes INT;  
    DECLARE @MemberJoinSQL NVARCHAR(MAX) = N'';  
      
    --To check for circular references, we run a recursive CTE. Here's the algorithm of that describes what is going on below:  
    --1. Retrieve the immediate child of every member code in scope (this is all of them if the user does not supply a value for @MemberAttributes)  
    --2. Recurse down the list also retrieving the children of every child found in 1, i.e., find all the descendants of every member in scope  
    --3. Stop (that is what the CASE that sets the MemberCode to NULL is about) the moment you find a member in its own list of descendants. This  
    --     means we have located a circular reference  
    --4. Put a list of all the members that are part of circular references in #CircularReferenceCodes  
  
    IF EXISTS(SELECT 1 FROM @MemberAttributes)  
    BEGIN  
        -- Load the provided member codes into an indexed temp table. Joining against this table is much faster   
        -- than joining directly against the @MemberAttributes parameter (e.g. 4 seconds versus 117 seconds on a test db   
        -- where the derived view contained 67K members and @MemberAttributes contained 2 rows).  
        CREATE TABLE #MemberCodes   
        (  
            MemberCode NVARCHAR(250) COLLATE DATABASE_DEFAULT PRIMARY KEY  
        )  
        INSERT INTO #MemberCodes  
        SELECT   
            DISTINCT MemberCode  
        FROM @MemberAttributes  
        SET @MemberJoinSQL = N'  
        INNER JOIN #MemberCodes m  
            ON member.ParentCode = m.MemberCode';  
    END;  
  
    SET @SQL = N'  
SELECT  
     Parent_ID          AS Parent_ID  
    ,ParentCode         AS ParentCode  
    ,ParentEntity_ID    AS ParentEntity_ID  
    ,Child_ID           AS Child_ID  
    ,Entity_ID          AS ChildEntity_ID  
INTO #ParentChildWorkingSet   
FROM ' + @RecursiveDerivedView + N' viw  
WHERE viw.Parent_ID > 0; -- Exclude ROOT parent  
  
;WITH cteMemberChildren AS  
(  
    SELECT   member.Parent_ID       AS Member_ID  
            ,member.ParentCode      AS MemberCode   
            ,member.ParentEntity_ID AS MemberEntity_ID    
            ,member.Parent_ID   
            ,member.ParentEntity_ID  
            ,member.Child_ID  
            ,member.ChildEntity_ID  
            ,0 Recursion_Level  
        FROM #ParentChildWorkingSet member' +  
        @MemberJoinSQL + N'  
                   
    UNION ALL  
  
    SELECT   cte.Member_ID  
            ,cte.MemberCode  
            ,cte.MemberEntity_ID  
            ,child.Parent_ID     
            ,child.ParentEntity_ID  
            ,CASE WHEN child.Child_ID = cte.Member_ID AND child.ChildEntity_ID = cte.MemberEntity_ID THEN NULL ELSE child.Child_ID END AS Child_ID  
            ,child.ChildEntity_ID  
            ,cte.Recursion_Level + 1  
        FROM #ParentChildWorkingSet child  
        INNER JOIN cteMemberChildren cte  
            ON   
                child.Parent_ID         = cte.Child_ID  
            AND child.ParentEntity_ID   = cte.ChildEntity_ID   
            AND cte.Recursion_Level < 99 -- Protects against "The statement terminated. The maximum recursion 100 has been exhausted before statement completion" error.  
)  
INSERT INTO #CircularReferenceCodes  
SELECT MemberCode FROM cteMemberChildren WHERE Child_ID IS NULL';  
  
    --PRINT @SQL;  
    EXEC sp_executesql @SQL;  
  
    --Put out the set of member codes that are part of circular references  
    SELECT * FROM #CircularReferenceCodes;  
  
    --Return the total number of members with problems  
    SET @CircularReferencedMemberCodes=(SELECT COUNT(MemberCode) FROM #CircularReferenceCodes);  
    RETURN @CircularReferencedMemberCodes;  
END;
GO
