SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    SELECT * FROM mdm.viw_SYSTEM_STAGING_MEMBER_ATTRIBUTE;  
    SELECT * FROM mdm.viw_SYSTEM_STAGING_MEMBER_ATTRIBUTE WHERE Status_ID = 2;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE VIEW [mdm].[viw_SYSTEM_STAGING_MEMBER_ATTRIBUTE]  
/*WITH SCHEMABINDING*/  
AS SELECT   
    --TOP 100 PERCENT  
    tStage.Batch_ID						Batch_ID,  
    tStage.ID                           Stage_ID,  
    tUser.ID                            [User_ID],  
    LTRIM(RTRIM(tStage.UserName))       [User_Name],  
    tMod.ID                             Model_ID,  
    LTRIM(RTRIM(tStage.ModelName))		Model_Name,  
    tSec.IsAdministrator                IsAdministrator,  
    tEnt.ID                             Entity_ID,  
    LTRIM(RTRIM(tStage.EntityName))     Entity_Name,  
    N'mdm.' + quotename(mdm.udfTableNameGetByID(tEnt.ID, tStage.MemberType_ID)) Entity_Table,  
    CASE  
        WHEN tEnt.HierarchyTable = '' THEN ''  
        ELSE 'mdm.' + quotename(tEnt.HierarchyTable)  
    END                                 Hierarchy_Table,  
    tStage.MemberType_ID                MemberType_ID,  
    NULL                                Member_ID,  
    LTRIM(RTRIM(tStage.MemberCode))     Member_Code,  
    tAtt.ID                             Attribute_ID,  
    tAtt.ChangeTrackingGroup			Attribute_ChangeTrackingGroup,  
    CASE  
        WHEN tAtt.ID IS NULL AND UPPER(LTRIM(RTRIM(tStage.AttributeName))) = N'MDMMEMBERSTATUS' THEN 3 --mdmMemberStatus is used to effect a member delete or restore (EDM-1391)  
        ELSE tAtt.AttributeType_ID  
    END                                 AttributeType_ID, --case  
    CASE  
        WHEN tAtt.ID IS NULL AND UPPER(LTRIM(RTRIM(tStage.AttributeName))) = N'MDMMEMBERSTATUS' THEN N'mdm.udfTransactionGetByTransactionType(2)'  
        ELSE 'mdm.[' + tDBA.EntityTable + ']'  
    END                                 Attribute_Entity_Table, --case  
    CASE  
        WHEN tAtt.ID IS NULL AND UPPER(LTRIM(RTRIM(tStage.AttributeName))) = N'MDMMEMBERSTATUS' THEN N'Status_ID'  
        ELSE tAtt.Name  
    END                                 Attribute_Name, --case  
    CASE  
        WHEN tAtt.ID IS NULL AND UPPER(LTRIM(RTRIM(tStage.AttributeName))) = N'MDMMEMBERSTATUS' THEN N'Status_ID'  
        ELSE tAtt.TableColumn  
    END                                 Attribute_Column, --case  
    CASE  
        WHEN LEN(LTRIM(RTRIM(tStage.AttributeValue))) = 0 THEN NULL   
        ELSE LTRIM(RTRIM(tStage.AttributeValue))     
    END                                 Attribute_Value, --case	  
    CASE  
        WHEN tStage.Status_ID = 1 THEN 1  
        WHEN tUser.ID IS NULL AND LEN(LTRIM(RTRIM(tStage.UserName))) > 0 THEN 2   
        WHEN tMod.ID IS NULL THEN 2  
        WHEN tSec.IsAdministrator = 0 THEN 2 --Model administrator privileges are required to stage into the selected Model  
        WHEN tEnt.ID IS NULL THEN 2  
        WHEN tEnt.IsSystem = 1 AND UPPER(LTRIM(RTRIM(tStage.AttributeName))) = N'MDMMEMBERSTATUS' THEN 2 -- cannot de/re-active system entity members  
        WHEN (tStage.MemberType_ID <> 1 AND tStage.MemberType_ID <> 2 AND tStage.MemberType_ID <> 3 AND tStage.MemberType_ID <> 5) THEN 2  
        WHEN (tAtt.AttributeType_ID = 3 OR tAtt.AttributeType_ID = 4) THEN 2  
        WHEN tAtt.DomainEntity_ID = 0 AND tAtt.DataType_ID = 1 AND tStage.AttributeValue IS NOT NULL AND LEN(tStage.AttributeValue) > tAtt.DataTypeInformation THEN 2  
        WHEN tAtt.DomainEntity_ID = 0 AND tAtt.DataType_ID = 2 AND tStage.AttributeValue IS NOT NULL AND ISNUMERIC(tStage.AttributeValue) = 0 THEN 2  
        WHEN tAtt.DomainEntity_ID = 0 AND tAtt.DataType_ID = 3 AND tStage.AttributeValue IS NOT NULL AND mdq.IsDateTime2(tStage.AttributeValue) = 0 THEN 2  
        WHEN tAtt.DomainEntity_ID = 0 AND tAtt.DataType_ID = 7 AND tStage.AttributeValue IS NOT NULL AND ISNUMERIC(tStage.AttributeValue) = 0 THEN 2  
        ----Validate attribute name - restrict reserved values but allow mdmMemberStatus, for it is used to effect a member delete or restore (EDM-1391)  
        WHEN tAtt.ID IS NULL AND UPPER(LTRIM(RTRIM(tStage.AttributeName))) <> N'MDMMEMBERSTATUS' THEN 2  
        ----Require that the attribute value be entered for Code and mdmMemberStatus; otherwise, allow Null or empty values (EDM-1060)  
        WHEN (LEN(LTRIM(RTRIM(tStage.AttributeValue))) = 0 OR tStage.AttributeValue IS NULL) AND LTRIM(RTRIM(tStage.AttributeName)) IN (N'Code') THEN 2  
        WHEN UPPER(LTRIM(RTRIM(tStage.AttributeName))) = N'MDMMEMBERSTATUS' AND LTRIM(RTRIM(tStage.AttributeValue)) NOT IN (SELECT Code From mdm.udfTransactionGetByTransactionType(2)) THEN 2  
        WHEN tStage.Status_ID = 2 THEN 2   
        ELSE 0  
    END                                 Status_ID, --case  
    CASE  
        WHEN tUser.ID IS NULL AND LEN(LTRIM(RTRIM(tStage.UserName))) > 0 THEN N'210017'  -- Error - user name is invalid  
        WHEN tMod.ID IS NULL THEN N'210018' -- Error - invalid model name  
        WHEN tSec.IsAdministrator = 0 THEN N'210019' -- Error - model administrator privileges are required to stage into the selected model  
        WHEN tEnt.ID IS NULL THEN N'210020' -- Error - invalid entity name  
        WHEN tEnt.IsSystem = 1 AND UPPER(LTRIM(RTRIM(tStage.AttributeName))) = N'MDMMEMBERSTATUS' THEN N'210057' -- Error - You cannot deactivate or reactivate system entity members.  
        WHEN (tStage.MemberType_ID <> 1 AND tStage.MemberType_ID <> 2 AND tStage.MemberType_ID <> 3 AND tStage.MemberType_ID <> 5) THEN N'210021' -- Error - member type ID must be 1 (leaf member), 2 (parent member), 3 (collection), or 5 (collection member)  
        WHEN tAtt.AttributeType_ID = 3 THEN N'210022' -- Error - system attributes may not be updated via staging  
        WHEN tAtt.AttributeType_ID = 4 THEN N'210023' -- Error - file attributes may not be updated via staging  
        WHEN tAtt.DomainEntity_ID = 0 AND tAtt.DataType_ID = 1 AND tStage.AttributeValue IS NOT NULL AND LEN(tStage.AttributeValue) > tAtt.DataTypeInformation THEN N'210024' -- Error - attribute value exceeds allowed length  
        WHEN tAtt.DomainEntity_ID = 0 AND tAtt.DataType_ID = 2 AND tStage.AttributeValue IS NOT NULL AND ISNUMERIC(tStage.AttributeValue) = 0 THEN N'210025' -- Error - data is the incorrect datatype for requested attribute (must be Numeric)  
        WHEN tAtt.DomainEntity_ID = 0 AND tAtt.DataType_ID = 3 AND tStage.AttributeValue IS NOT NULL AND mdq.IsDateTime2(tStage.AttributeValue) = 0 THEN N'210026' -- Error - data is the incorrect datatype for requested attribute (must be DateTime)  
        WHEN tAtt.DomainEntity_ID = 0 AND tAtt.DataType_ID = 7 AND tStage.AttributeValue IS NOT NULL AND ISNUMERIC(tStage.AttributeValue) = 0 THEN N'210027' -- Error - data is the incorrect datatype for requested attribute (must be Integer)  
        ----Validate attribute name - restrict reserved values but allow mdmMemberStatus, for it is used to effect a member delete or restore (EDM-1391)  
        WHEN tAtt.ID IS NULL AND UPPER(LTRIM(RTRIM(tStage.AttributeName))) <> N'MDMMEMBERSTATUS' THEN N'210028'   -- Error - invalid attribute name  
        ----Require that the attribute value be entered for Code and mdmMemberStatus; otherwise, allow Null or empty values (EDM-1060)  
        WHEN (LEN(LTRIM(RTRIM(tStage.AttributeValue))) = 0 OR tStage.AttributeValue IS NULL) AND LTRIM(RTRIM(tStage.AttributeName)) IN (N'Code') THEN N'210029' -- Error - attribute value is required  
        ----If unassigning a value warn the user (EDM-1060)       
        WHEN LEN(LTRIM(RTRIM(tStage.AttributeValue))) = 0 OR tStage.AttributeValue IS NULL THEN N'210030' -- Warning - attribute value will be unassigned  
        WHEN UPPER(LTRIM(RTRIM(tStage.AttributeName))) = N'MDMMEMBERSTATUS' AND LTRIM(RTRIM(tStage.AttributeValue)) NOT IN (SELECT Code From mdm.udfTransactionGetByTransactionType(2)) THEN N'210031' -- Error - Attribute_Value must be either ''Active'' or ''De-Activated'' when attempting to change the member status  
        WHEN tStage.Status_ID = 2 THEN tStage.ErrorCode  
        ELSE N''  
    END                                 Status_ErrorCode--case  
FROM   
    mdm.tblStgMemberAttribute tStage  
    LEFT OUTER JOIN mdm.tblUser tUser   
        ON LTRIM(RTRIM(tStage.UserName)) = tUser.UserName AND tUser.Status_ID=1  
    LEFT OUTER JOIN mdm.tblModel tMod   
        ON LTRIM(RTRIM(tStage.ModelName)) = tMod.Name   
    LEFT OUTER JOIN mdm.viw_SYSTEM_SECURITY_USER_MODEL tSec   
        ON tUser.ID = tSec.User_ID   
        AND tMod.ID = tSec.ID  
    LEFT OUTER JOIN mdm.tblEntity tEnt   
        ON tMod.ID = tEnt.Model_ID   
        AND LTRIM(RTRIM(tStage.EntityName)) = tEnt.Name  
    LEFT OUTER JOIN mdm.tblAttribute tAtt   
        ON tAtt.Entity_ID = tEnt.ID   
        AND tStage.MemberType_ID = tAtt.MemberType_ID   
        AND (tStage.AttributeName = tAtt.Name OR tStage.AttributeName + '_ID' = tAtt.Name)  
    LEFT OUTER JOIN mdm.tblEntity tDBA   
        ON tAtt.DomainEntity_ID = tDBA.ID;
GO
