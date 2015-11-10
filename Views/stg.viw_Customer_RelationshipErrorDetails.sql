SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
  
        CREATE VIEW [stg].[viw_Customer_RelationshipErrorDetails]  
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
            FROM stg.[Customer_Relationship] r  
                LEFT OUTER JOIN mdm.tblErrorCodesMapping ecm ON (ecm.Bitmask & r.ErrorCode) <> 0  
                LEFT OUTER JOIN mdm.tblDBErrors dbe ON dbe.ID = ecm.UniqueErrorCode  
                LEFT OUTER JOIN sys.syslanguages sl ON sl.langid = @@LANGID AND sl.lcid = dbe.Language_ID  
            WHERE r.ImportStatus_ID = 2;
GO
