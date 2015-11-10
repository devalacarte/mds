SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Looks up the model muids for the given collection of business rule muids.  
  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRulesGetModelMuids]  
(  
    @Muids              XML = NULL  
)  
/*WITH*/  
AS BEGIN  
    IF @Muids IS NOT NULL BEGIN  
        SELECT DISTINCT   
            b.BusinessRule_MUID ItemMuid,  
            b.Model_MUID  ModelMuid             
        FROM   
            @Muids.nodes(N'//guid') m(MUID)  
            INNER JOIN  
            mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES b  
                ON   
                    m.MUID.value(N'.', N'UNIQUEIDENTIFIER') = b.BusinessRule_MUID  
    END  
END --proc
GO
