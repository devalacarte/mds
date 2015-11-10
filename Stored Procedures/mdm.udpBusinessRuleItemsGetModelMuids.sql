SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Looks up the model muids for the given collection of business rule items.  
  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleItemsGetModelMuids]  
(  
    @Muids              XML = NULL  
)  
/*WITH*/  
AS BEGIN  
    IF @Muids IS NOT NULL BEGIN  
        SELECT DISTINCT   
            it.MUID ItemMuid,  
            b.Model_MUID  ModelMuid             
        FROM   
            @Muids.nodes(N'//guid') m(MUID)  
            INNER JOIN  
            mdm.tblBRItem it  
                ON m.MUID.value(N'.', N'UNIQUEIDENTIFIER') = it.MUID  
            INNER JOIN  
            mdm.tblBRLogicalOperatorGroup lg  
                ON it.BRLogicalOperatorGroup_ID = lg.ID  
            INNER JOIN  
            mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES b  
                ON   
                    lg.BusinessRule_ID = b.BusinessRule_ID  
    END  
END --proc
GO
