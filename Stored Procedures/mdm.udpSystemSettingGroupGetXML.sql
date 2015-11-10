SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpSystemSettingGroupGetXML   
EXEC mdm.udpSystemSettingGroupGetXML @Group_Name = 'Email'  
exec mdm.udpSystemSettingGroupGetXML @Group_ID=NULL,@Group_MUID=0x0,@Group_Name=N'Email'  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSystemSettingGroupGetXML]   
(  
     @Group_ID   INT = NULL  
    ,@Group_MUID UNIQUEIDENTIFIER = NULL  
    ,@Group_Name NVARCHAR(50) = NULL  
)  
  
WITH EXECUTE AS N'mds_schema_user'   
AS BEGIN  
  
    SET NOCOUNT ON  
  
    SET @Group_MUID = NULLIF(@Group_MUID, 0x0);  
    SET @Group_ID = NULLIF(@Group_ID, 0);   
    SET @Group_Name = NULLIF(@Group_Name, N'');   
  
    -- The returned columns must be in the correct order (see http://msdn.microsoft.com/en-us/library/ms729813.aspx) or DataContractSerializer  
    -- may fail (sometimes silently) to deserialize out-of-order columns.  
    SELECT  
        -- Members inherited from Core.BusinessEntities.BusinessEntity   
         [Identifier/Id] = grp.ID    
        ,[Identifier/Muid] = grp.MUID    
        ,[Identifier/Name] = grp.GroupName  
          
        -- Core.BusinessEntities.SystemSettingGroup members  
        ,[Description] = grp.Description  
        ,[DisplayName] = grp.DisplayName  
        ,[DisplaySequence] = grp.DisplaySequence  
        ,[SystemSettings] = mdm.udfSystemSettingGetXML(grp.ID, NULL, NULL)  
    FROM   
        mdm.tblSystemSettingGroup grp  
    WHERE  
        ((@Group_ID IS NULL) OR (grp.ID = @Group_ID))  
        AND ((@Group_MUID IS NULL) OR (grp.MUID = @Group_MUID))  
        AND ((@Group_Name IS NULL) OR (grp.GroupName = @Group_Name))  
    ORDER BY grp.DisplaySequence  
    FOR XML PATH('SystemSettingGroup'), ELEMENTS XSINIL, ROOT('ArrayOfSystemSettingGroup')  
  
    SET NOCOUNT OFF  
END --proc
GO
