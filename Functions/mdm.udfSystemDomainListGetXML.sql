SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    SELECT mdm.udfSystemDomainListGetXML(NULL, NULL, NULL)  
    SELECT mdm.udfSystemDomainListGetXML('lstBRItemTypeSubCategory', null, null)  
    SELECT mdm.udfSystemDomainListGetXML('lstBRItemTypeSubCategory', null, 'Change value')  
    SELECT mdm.udfSystemDomainListGetXML('lstInputMask', null, null)  
    SELECT mdm.udfSystemDomainListGetXML('lstInputMask', null, 2)  
  
   SELECT * FROM mdm.tblList  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSystemDomainListGetXML]  
(  
    @ListCode       NVARCHAR(50) = NULL,  
    @ListGroup_ID   INT = NULL,  
    @ListOption     NVARCHAR(250) = NULL  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
    DECLARE @return XML  
  
    -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
    -- may fail (sometimes silently) to deserialize out-of-order columns.  
    SELECT @return = CONVERT(XML, (  
       SELECT  
        -- Core.BusinessEntities.SystemDomainList members                 
         [Code] = Domains.ListCode  
        ,[Items] =   
              CONVERT(XML,  
                 (  
                   SELECT   
                      -- Core.BusinessEntities.SystemDomainListItem members                 
                       [ListGroup] = domainItems.Group_ID  
                      ,[Name] = domainItems.ListOption  
                      ,[Value] = domainItems.OptionID  
                   FROM   
                      mdm.tblList domainItems  
                   WHERE   
                      domainItems.ListCode = Domains.ListCode  
                      AND ((@ListGroup_ID IS NULL) OR (domainItems.Group_ID =@ListGroup_ID))  
                      AND ((@ListOption IS NULL) OR (domainItems.ListOption = @ListOption))  
                      AND IsVisible = 1  
                   ORDER BY  
                      Seq  
                  FOR XML PATH('SystemDomainListItem')  
                  )   
              )  
        ,[Name] = Domains.ListName  
      FROM (SELECT DISTINCT ListCode, ListName FROM mdm.tblList WHERE   
        ((@ListCode IS NULL ) OR (ListCode = @ListCode))) Domains  
       FOR XML PATH('SystemDomainList'), ELEMENTS XSINIL  
    ))  
  
    RETURN COALESCE(@return, N'');  
END;
GO
