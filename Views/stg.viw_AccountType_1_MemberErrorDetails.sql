SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
  
      CREATE VIEW [stg].[viw_AccountType_1_MemberErrorDetails]  
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
                FROM stg.[AccountType_1_Leaf]  
                WHERE ImportStatus_ID = 2  
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
                LEFT OUTER JOIN sys.syslanguages sl ON sl.langid = @@LANGID AND sl.lcid = dbe.Language_ID;
GO
