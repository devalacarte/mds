SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    SELECT mdm.udfSystemSettingGetXML(NULL, NULL, NULL)  
    SELECT mdm.udfSystemSettingGetXML(1, NULL, NULL)  
    SELECT mdm.udfSystemSettingGetXML(2, NULL, NULL)  
    SELECT mdm.udfSystemSettingGetXML(3, NULL, NULL)  
  
   SELECT * FROM mdm.tblList  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfSystemSettingGetXML]  
(  
     @Group_ID   INT  
    ,@Group_MUID UNIQUEIDENTIFIER  
    ,@Group_Name NVARCHAR(50)  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
    DECLARE @return XML  
  
    -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
    -- may fail (sometimes silently) to deserialize out-of-order columns.  
    SELECT @return = CONVERT(XML, (  
        SELECT  
            -- Members inherited from Core.BusinessEntities.BusinessEntity   
             [Identifier/Id] = sys.ID  
            ,[Identifier/Muid] = sys.MUID  
            ,[Identifier/Name] = sys.SettingName  
              
            -- Core.BusinessEntities.SystemSetting members              
            ,[DataType] = sys.DataType_Name   
            ,[Description] = sys.Description  
            ,[DisplayName] = sys.DisplayName  
            ,[DisplaySequence] = sys.DisplaySequence  
            ,[IsVisible] = sys.IsVisible  
            ,[MaxValue] = sys.MaxValue  
            ,[MinValue] = sys.MinValue  
            ,[SettingType] = Replace(sys.SettingType_Name, N'-', N'')  
            ,[SettingValue] = sys.SettingValue  
            ,mdm.udfSystemDomainListGetXML(ISNULL(sys.SettingValueDomainName, N''), NULL, NULL) -- [SystemDomainList]   
        FROM   
            mdm.viw_SYSTEM_SCHEMA_SYSTEMSETTINGS sys  
        INNER JOIN  
            mdm.tblSystemSettingGroup grp  
                ON sys.SystemSettingGroup_ID = grp.ID  
                AND ((@Group_ID IS NULL) OR (grp.ID = @Group_ID))  
                AND ((@Group_MUID IS NULL) OR (grp.MUID = @Group_MUID))  
                AND ((@Group_Name IS NULL) OR (grp.GroupName = @Group_Name))  
        ORDER BY sys.SystemSettingGroup_ID, sys.DisplaySequence  
        FOR XML PATH('SystemSetting'), ELEMENTS XSINIL  
    ))  
  
    RETURN COALESCE(@return, N'');  
END;
GO
