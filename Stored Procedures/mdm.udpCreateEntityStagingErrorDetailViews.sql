SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Creates all the needed entity staging views to view error detail information  
    EXEC mdm.udpCreateEntityStagingErrorDetailViews 21  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpCreateEntityStagingErrorDetailViews]  
    @Entity_ID       INT  
AS  
BEGIN  
    DECLARE  
        @StagingBase            sysname,  
        @IsFlat                 BIT,  
        @SQL                    NVARCHAR(MAX),  
        @SQLMemberView          NVARCHAR(MAX),  
        @SQLRelationView        NVARCHAR(MAX),  
        @MemberErrorViewName    NVARCHAR(MAX),  
        @RelationErrorViewName  NVARCHAR(MAX);  
  
    SELECT @StagingBase = StagingBase,  
           @IsFlat = IsFlat  
        FROM mdm.tblEntity  
        WHERE ID = @Entity_ID;  
           
    -- In case when the entity is a system entity (@StagingBase is not specified) simply don't create the error view (don't raise an error).   
    IF COALESCE(@StagingBase, N'') = N''   
    BEGIN   
        RETURN;  
    END;  
    
    SET @MemberErrorViewName = N'stg.' + QUOTENAME(N'viw_' + @StagingBase + N'_MemberErrorDetails');  
    SET @RelationErrorViewName = N'stg.' + QUOTENAME(N'viw_' + @StagingBase + N'_RelationshipErrorDetails');  
  
    -- Drop existing view if it already exists.  
    SET @SQL = N'  
        IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N''' + @MemberErrorViewName + N'''))  
            DROP VIEW ' + @MemberErrorViewName + N'  
        IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N''' + @RelationErrorViewName + N'''))  
            DROP VIEW ' + @RelationErrorViewName;  
  
    EXEC(@SQL);  
  
    SET @SQLMemberView = N'  
      CREATE VIEW ' + @MemberErrorViewName + N'  
      AS  
  
        WITH Members  
        AS  
        (  
            SELECT  
                    ID,  
                    ImportType,  
                    ImportStatus_ID,  
                    Batch_ID,  
                    BatchTag,  
                    ErrorCode,  
                    Code,  
                    Name,  
                    NewCode,  
                    1 AS MemberType -- Leaf member  
                FROM stg.' + QUOTENAME(@StagingBase + N'_Leaf') + N'  
                WHERE ImportStatus_ID = 2';  
  
    IF (@IsFlat = 0)  
    BEGIN  
        SET @SQLMemberView = @SQLMemberView + N'  
  
            UNION ALL  
  
            SELECT  
                    ID,  
                    ImportType,  
                    ImportStatus_ID,  
                    Batch_ID,  
                    BatchTag,  
                    ErrorCode,  
                    Code,  
                    Name,  
                    NewCode,  
                    2 AS MemberType -- Consolidated membery  
                FROM stg.' + QUOTENAME(@StagingBase + N'_Consolidated') + N'  
                WHERE ImportStatus_ID = 2';  
  
        SET @SQLRelationView = N'  
        CREATE VIEW '+ @RelationErrorViewName + N'  
        AS  
            SELECT   
                r.ID,  
                r.RelationshipType,   
                r.ImportStatus_ID,  
                r.Batch_ID,  
                r.BatchTag,  
                r.HierarchyName,  
                r.ParentCode,  
                r.ChildCode,  
                ecm.UniqueErrorCode,  
                dbe.Text AS ErrorDescription  
            FROM stg.' + QUOTENAME(@StagingBase + N'_Relationship') + N' r  
                LEFT OUTER JOIN mdm.tblErrorCodesMapping ecm ON (ecm.Bitmask & r.ErrorCode) <> 0  
                LEFT OUTER JOIN mdm.tblDBErrors dbe ON dbe.ID = ecm.UniqueErrorCode  
                LEFT OUTER JOIN sys.syslanguages sl ON sl.langid = @@LANGID AND sl.lcid = dbe.Language_ID  
            WHERE r.ImportStatus_ID = 2;';  
  
        EXEC(@SQLRelationView);  
    END -- IF  
  
    SET @SQLMemberView = @SQLMemberView + N'  
        )  
        SELECT  
                m.ID,  
                m.ImportType,  
                m.ImportStatus_ID,  
                m.Batch_ID,  
                m.BatchTag,  
                m.Code,  
                m.Name,  
                m.NewCode,  
                m.MemberType,  
                ecm.UniqueErrorCode,  
                dbe.Text AS ErrorDescription,  
                sed.AttributeName,  
                sed.AttributeValue  
            FROM  
                Members m  
                LEFT OUTER JOIN mdm.tblErrorCodesMapping ecm ON (ecm.Bitmask & m.ErrorCode) <> 0  
                LEFT OUTER JOIN mdm.tblStgErrorDetail sed ON sed.Batch_ID = m.Batch_ID AND sed.Code = m.Code AND ecm.UniqueErrorCode = sed.UniqueErrorCode  
                LEFT OUTER JOIN mdm.tblDBErrors dbe ON dbe.ID = ecm.UniqueErrorCode  
                LEFT OUTER JOIN sys.syslanguages sl ON sl.langid = @@LANGID AND sl.lcid = dbe.Language_ID;';  
  
    EXEC(@SQLMemberView);  
  
END; -- PROC
GO
