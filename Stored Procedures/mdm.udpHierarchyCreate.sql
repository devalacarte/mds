SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpHierarchyCreate 1, 15, 8, 0, 50, 2;  
*/  
CREATE PROCEDURE [mdm].[udpHierarchyCreate]  
(  
   @User_ID       INT,  
   @Version_ID    INT,  
   @Entity_ID     INT,  
   @Hierarchy_ID  INT,  
   @Parent_ID     INT,  
   @Child_ID      INT,  
   @ChildType_ID  INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
        @HierarchyTable		sysname,  
        @SQL				NVARCHAR(MAX),  
        @Member_ID			INT;  
  
    --Invalid @ChildType_ID  
    IF @ChildType_ID NOT IN (1, 2) BEGIN --1=EN, 2=HP  
        --On error, return NULL results  
        SELECT @Member_ID = NULL;  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
      
    --Get the Entity Hierarchy Table Name  
    SET @HierarchyTable = mdm.udfTableNameGetByID(@Entity_ID, 4);  
  
    --Insert into the Correct Hierarchy Relationship table  
    SELECT @SQL = N'  
        DECLARE @SortOrder INT;   
        SELECT @SortOrder = MAX(ID) FROM mdm.' + quotename(@HierarchyTable) + N'  
        WHERE Version_ID = @Version_ID;  
          
        INSERT INTO mdm.' + quotename(@HierarchyTable) + N'  
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
        VALUES  
        (  
             @Version_ID  
            ,1  
            ,@Hierarchy_ID  
            ,NULLIF(@Parent_ID, 0) --Parent_HP_ID  
            ,@ChildType_ID --ChildType_ID  
            ,CASE @ChildType_ID WHEN 1 THEN @Child_ID ELSE NULL END --Child_EN_ID  
            ,CASE @ChildType_ID WHEN 2 THEN @Child_ID ELSE NULL END --Child_HP_ID  
            ,ISNULL(@SortOrder, 0) + 1  
            ,-1  
            ,GETUTCDATE()  
            ,@User_ID  
            ,@Version_ID  
            ,GETUTCDATE()  
            ,@User_ID  
            ,@Version_ID		  
        );  
          
        SET @Member_ID = SCOPE_IDENTITY();';  
  
    --PRINT(@SQL);  
    EXEC sp_executesql @SQL,   
        N'@User_ID INT, @Version_ID INT, @Hierarchy_ID INT, @Parent_ID INT, @Child_ID INT, @ChildType_ID INT, @Member_ID INT OUTPUT',   
        @User_ID, @Version_ID, @Hierarchy_ID, @Parent_ID, @Child_ID, @ChildType_ID, @Member_ID OUTPUT;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
