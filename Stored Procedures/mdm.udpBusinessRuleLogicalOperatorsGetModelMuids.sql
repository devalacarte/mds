SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Looks up the model muids for the given collection of logical operator group muids.  
  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleLogicalOperatorsGetModelMuids]  
(  
    @Muids              XML = NULL  
)  
/*WITH*/  
AS BEGIN  
    IF @Muids IS NOT NULL BEGIN  
        SELECT DISTINCT   
            lg.MUID ItemMuid,  
            b.Model_MUID  ModelMuid             
        FROM   
            @Muids.nodes(N'//guid') m(MUID)  
            INNER JOIN  
            mdm.tblBRLogicalOperatorGroup lg  
                ON m.MUID.value(N'.', N'UNIQUEIDENTIFIER') = lg.MUID  
            INNER JOIN  
            mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES b  
                ON   
                    lg.BusinessRule_ID = b.BusinessRule_ID  
    END  
  
END --proc
GO
