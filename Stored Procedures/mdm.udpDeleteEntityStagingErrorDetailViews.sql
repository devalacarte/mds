SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Drops all the entity staging views to view an error  
    EXEC mdm.udpDeleteEntityStagingErrorDetailViews 21  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpDeleteEntityStagingErrorDetailViews]  
    @Entity_ID  INT  
AS  
BEGIN  
    DECLARE  
        @StagingBase            sysname,  
        @SQLDropView            NVARCHAR(MAX),  
        @MemberErrorViewName    NVARCHAR(MAX),  
        @RelationErrorViewName  NVARCHAR(MAX);  
  
    SELECT  
        @StagingBase = StagingBase  
        FROM  
            mdm.tblEntity  
        WHERE  
            ID = @Entity_ID;  
      
    -- In case when the entity is a system entity (@StagingBase is not specified) simply don't drop the error view (don't raise an error).   
    IF COALESCE(@StagingBase, N'') = N''    
    BEGIN   
        RETURN;  
    END;  
     
    SET @MemberErrorViewName = N'stg.' + QUOTENAME('viw_' + @StagingBase + '_MemberErrorDetails');  
    SET @RelationErrorViewName = N'stg.' + QUOTENAME('viw_' + @StagingBase + '_RelationshipErrorDetails');  
  
    SET @SQLDropView = N'  
        IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(''' + @MemberErrorViewName + N'''))  
          DROP VIEW ' + @MemberErrorViewName + N'  
        IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(''' + @RelationErrorViewName + N'''))  
          DROP VIEW ' + @RelationErrorViewName;  
  
    EXEC(@SQLDropView);  
  
  
END;
GO
