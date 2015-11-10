SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Description:  
This procedure updates the validation status of a hierarchy tree starting at a given   
consolidated apex member node.  
  
Example:  
declare	@parentIdList mdm.IdList;   
INSERT INTO @parentIdList (ID) VALUES (390);  
  
EXEC mdm.udpHierarchyMembersValidationStatusUpdate  
     @Entity_ID = 31  
    ,@Version_ID = 20  
    ,@Hierarchy_ID = null  
    ,@ParentIdList = @parentIdList  
    ,@ValidationStatus_ID = 5  
    ,@MaxLevel = 0  
    ,@IncludeParent = 0;  
  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpHierarchyMembersValidationStatusUpdate]  
(  
	@Entity_ID				 INT,  
	@Version_ID				 INT,  
	@Hierarchy_ID			 INT = NULL,  
	@ParentIdList mdm.IdList READONLY,   
	@ValidationStatus_ID	 INT,  
	@MaxLevel				 INT = 0, -- 0 = Include all levels  
	@IncludeParent			 BIT = 1		  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON  
  
    DECLARE   
        @parentChildViewName sysname,  
        @entityTableName sysname,  
        @hierarchyParentTableName sysname,  
        @sql nvarchar(max);  
  
    -- Initialize any null parameters  
    SELECT  
         @ValidationStatus_ID = ISNULL(@ValidationStatus_ID, 0)  
        ,@MaxLevel = ISNULL(@MaxLevel, 0)  
        ,@IncludeParent = ISNULL(@IncludeParent, 0);  
          
    CREATE TABLE #descendentIDs (ID INT, ChildType_ID INT);  
  
    --Get the physical table names  
    SELECT  
         @entityTableName =  v.EntityTableName  
        ,@hierarchyParentTableName = v.HierarchyParentTableName  
    FROM mdm.viw_SYSTEM_TABLE_NAME v  
    WHERE ID = @Entity_ID;  
  
    --Get the name of the ParentChild view name  
    SELECT   
        @parentChildViewName = ViewName   
    FROM mdm.viw_SYSTEM_SCHEMA_VIEWS  
    WHERE Entity_ID = @Entity_ID  
    AND DisplayType_ID = 0  
    AND MemberType_ID = 4;  
  
     --Get Hierarchy IDs FROM Member.  All Parent Ids must be FROM the same Hierarchy.  Pick the first one    
    IF @Hierarchy_ID IS NULL   
    SET @sql = N'   
        SELECT TOP 1    
            @Hierarchy_ID = pc.Hierarchy_ID    
        FROM mdm.' + quotename(@parentChildViewName) + N' pc      
        WHERE    
                pc.Version_ID = @Version_ID    
            AND pc.Child_ID IN (SELECT ID FROM @ParentIdList)    
            AND pc.ChildType_ID = 2    
        ORDER BY pc.Hierarchy_ID';  
    EXEC sp_executesql @sql,     
        N'@Version_ID INT, @ParentIdList mdm.IdList READONLY, @Hierarchy_ID INT OUTPUT',     
        @Version_ID, @ParentIdList, @Hierarchy_ID OUTPUT;    
  
    --Use a recursive CTE to get all children for the ParentIdList, consolidated AND leaf  
    SELECT @sql = N'  
    WITH HierRecurse AS (  
        SELECT Child_ID, Parent_ID, 1 [Level]  
        FROM mdm.' + quotename(@parentChildViewName) + N'  
        WHERE Version_ID = @Version_ID  
        AND Hierarchy_ID = @Hierarchy_ID  
        AND Child_ID IN (SELECT ID FROM @ParentIdList)  
        AND ChildType_ID = 2  
  
        UNION ALL  
  
        SELECT c.Child_ID, c.Parent_ID, r.[Level] + 1  
        FROM mdm.' + quotename(@parentChildViewName) + N' AS c  
        INNER JOIN HierRecurse AS r  
            ON  c.Version_ID = @Version_ID  
            AND c.Hierarchy_ID = @Hierarchy_ID  
            AND c.ChildType_ID = 2  
            AND c.Parent_ID = r.Child_ID  
    )  
    INSERT INTO #descendentIDs (ID, ChildType_ID)  
    Select   
        pc.Child_ID, pc.ChildType_ID  
    From mdm.' + quotename(@parentChildViewName) + N' AS pc  
    INNER JOIN HierRecurse AS r  
        ON pc.Parent_ID = r.Child_ID  
    OPTION (MAXRECURSION ' + CAST(@MaxLevel AS NVARCHAR(30)) + N')  
    ';  
  
    EXEC sp_executesql @sql,   
        N'@Hierarchy_ID INT, @Version_ID INT, @ParentIdList mdm.IdList READONLY',   
        @Hierarchy_ID, @Version_ID, @ParentIdList;  
  
    IF @IncludeParent = 1  
        INSERT INTO #descendentIDs (ID, ChildType_ID)   
            SELECT ID, 2  
            FROM @ParentIdList;  
  
	-- Update the Hierarchy Parent table (consolidated)  
	SET @sql =   
		'UPDATE	mdm.' + quotename(@hierarchyParentTableName) + N'  
		   SET	ValidationStatus_ID = @ValidationStatus_ID   
		 FROM   mdm.' + quotename(@hierarchyParentTableName) + N' AS hp    
		 INNER JOIN #descendentIDs d   
            ON  hp.ID = d.ID   
            AND d.ChildType_ID = 2  
            AND hp.Hierarchy_ID = @Hierarchy_ID  
            AND hp.Version_ID = @Version_ID  
            AND hp.Status_ID = 1   
            AND hp.ValidationStatus_ID <> @ValidationStatus_ID;  
     ';  
  
    EXEC sp_executesql @sql,   
        N'@Version_ID INT, @ValidationStatus_ID INT, @Hierarchy_ID INT',   
          @Version_ID, @ValidationStatus_ID, @Hierarchy_ID;  
  
	-- Update the Entity table (leaf)  
	SET @sql =   
		N'UPDATE mdm.' + quotename(@entityTableName) + N'  
		    SET	 ValidationStatus_ID = @ValidationStatus_ID  
		  FROM   mdm.' + quotename(@entityTableName) + N' AS en  
		 INNER JOIN #descendentIDs d   
            ON  en.ID = d.ID   
            AND d.ChildType_ID = 1  
            AND en.Version_ID = @Version_ID  
            AND en.Status_ID = 1   
            AND en.ValidationStatus_ID <> @ValidationStatus_ID;  
     ';  
  
                 
    EXEC sp_executesql @sql,   
        N'@Version_ID INT, @ValidationStatus_ID INT',   
          @Version_ID, @ValidationStatus_ID;  
  
	SET NOCOUNT OFF  
END --proc
GO
