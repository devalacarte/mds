SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT * FROM mdm.viw_SYSTEM_SCHEMA_SYSTEMSETTINGS  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_SCHEMA_SYSTEMSETTINGS]  
/*WITH SCHEMABINDING*/  
AS  
SELECT  
    sys.ID  
    ,sys.MUID  
    ,sys.SettingName  
    ,sys.DisplayName  
    ,sys.Description  
    ,sys.SettingType_ID  
    ,[SettingType_Name] = sysType.ListOption   
    ,sys.DataType_ID  
    ,[DataType_Name] = dataType.ListOption  
    ,[SettingValue] = sys.SettingValue  
    ,[SettingValueDomainName] = sys.ListCode  
    ,[MinValue] = sys.MinValue  
    ,[MaxValue] = sys.MaxValue  
    ,sys.IsVisible  
    ,sys.DisplaySequence  
    ,sys.SystemSettingGroup_ID  
  
   FROM   
        mdm.tblSystemSetting sys  
        INNER JOIN mdm.tblList sysType  
            ON sys.SettingType_ID = sysType.OptionID AND sysType.ListCode = 'lstAttributeType'  
        INNER JOIN mdm.tblList dataType  
            ON sys.DataType_ID = dataType.OptionID AND dataType.ListCode = 'lstDataType'
GO
