SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	EXEC mdm.udpSystemDomainListGetXML NULL, NULL, NULL  
	EXEC mdm.udpSystemDomainListGetXML 'lstBRItemTypeSubCategory'  
	EXEC mdm.udpSystemDomainListGetXML 'lstInputMask', null  
	EXEC mdm.udpSystemDomainListGetXML 'lstInputMask', 1  
	EXEC mdm.udpSystemDomainListGetXML '',null  
  
   SELECT * FROM mdm.tblList  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSystemDomainListGetXML]   
(  
    @ListCode       NVARCHAR(50) = NULL,  
    @ListGroup_ID   INT = NULL,  
    @ListOption     NVARCHAR(250) = NULL  
)  
/*WITH*/  
AS BEGIN  
  
SET NOCOUNT ON  
  
SELECT mdm.udfSystemDomainListGetXML (@ListCode, @ListGroup_ID, @ListOption)  
FOR XML PATH('ArrayOfSystemDomainList')  
  
SET NOCOUNT OFF  
END --proc
GO
