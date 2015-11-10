SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Description: Bulk creates hierarchy member records.  
  
    EXEC mdm.udpHierarchyMembersCreate 1, 15, 8, 0, 50, 2;  
*/  
CREATE PROCEDURE [mdm].[udpHierarchyMembersCreate]  
(	  
   @User_ID				INT,  
   @Version_ID			INT,  
   @Entity_ID			INT,  
   @HierarchyMembers	mdm.HierarchyMembers READONLY  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
         @HierarchyTable	sysname  
        ,@IsFlat			BIT  
        ,@SQL				NVARCHAR(MAX)  
    ;  
  
    CREATE TABLE #NewMembers   
        (ID	INT);  
              
    --Get the Entity Hierarchy Table Name  
    SELECT  
         @HierarchyTable = Quotename(HierarchyTable)  
        ,@IsFlat = IsFlat  
    FROM 	  
        mdm.tblEntity WHERE ID = @Entity_ID;  
  
    IF @IsFlat = 1 BEGIN  
        RAISERROR('MDSERR310021|For consolidated members, the entity must be enabled for hierarchies and collections.', 16, 1);  
        RETURN;  
    END  
      
    --Insert into the Correct Hierarchy Relationship table  
    SELECT @SQL = N'  
        INSERT INTO mdm.' + @HierarchyTable + N'  
        (  
            Version_ID,  
            Status_ID,  
            Hierarchy_ID,  
            Parent_HP_ID,  
            ChildType_ID,			  
            Child_EN_ID,  
            Child_HP_ID,  
            SortOrder,  
            LevelNumber,  
            EnterDTM,   
            EnterUserID,  
            EnterVersionID,  
            LastChgDTM,  
            LastChgUserID,  
            LastChgVersionID  
        )   
        OUTPUT inserted.ID INTO #NewMembers  
        SELECT  
             @Version_ID  
            ,1  
            ,hm.Hierarchy_ID  
            ,NULLIF(hm.Parent_ID, 0) --Parent_HP_ID  
            ,hm.ChildMemberType_ID  
            ,CASE hm.ChildMemberType_ID WHEN 1 THEN hm.Child_ID ELSE NULL END --Child_EN_ID  
            ,CASE hm.ChildMemberType_ID WHEN 2 THEN hm.Child_ID ELSE NULL END --Child_HP_ID  
            ,1  
            ,-1  
            ,GETUTCDATE()  
            ,@User_ID  
            ,@Version_ID  
            ,GETUTCDATE()  
            ,@User_ID  
            ,@Version_ID  
        FROM @HierarchyMembers hm;  
          
        UPDATE mdm.' + @HierarchyTable + N'  
        SET SortOrder = nm.ID  
        FROM mdm.' + @HierarchyTable + N' hr INNER JOIN #NewMembers	nm   
            ON hr.ID = nm.ID AND Version_ID = @Version_ID;  
        ';  
  
    --PRINT(@SQL);  
    EXEC sp_executesql @SQL,   
        N'@User_ID INT, @Version_ID INT, @HierarchyMembers mdm.HierarchyMembers READONLY',   
        @User_ID, @Version_ID, @HierarchyMembers;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
