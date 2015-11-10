SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Date:      : Monday, June 12, 2006  
Function   : mdm.udfItemReservedWordCheck  
Component  : All  
Description: mdm.udfItemReservedWordCheck verifies an input value against a list of reserved MDS words for a specific object type  
Parameters : Object type; Value (to be verified)   
Return     : Boolean (0 = passes verification; 1 = fails verification)  
Example 1  : SELECT mdm.udfItemReservedWordCheck(3, 'Code')   --1 = Fails verification (reserved word)  
Example 2  : SELECT mdm.udfItemReservedWordCheck(4, 'Status') --1 = Fails verification (reserved word)  
Example 3  : SELECT mdm.udfItemReservedWordCheck(3, 'Test')   --0 = Passes verification (not a reserved word)  
Example 4  : SELECT mdm.udfItemReservedWordCheck(12, 'Root')  --1 = Fails verification (reserved word)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfItemReservedWordCheck] (@ObjectType_ID INT, @Code NVARCHAR(250))   
RETURNS BIT  
/*WITH SCHEMABINDING*/  
AS BEGIN   
    -- First check for TABS , CR and LF characters  
    SET @Code = REPLACE(REPLACE(REPLACE(@Code, CHAR(9),''), CHAR(13), '') , CHAR(10), '')  
      
    -- Trim all leading and trailing spaces  
   SET @Code = LTRIM(RTRIM(@Code))     
   RETURN  
      CASE  
         WHEN   
            @ObjectType_ID IN (3, 4) AND @Code IN --3=Entity; 4=Attribute  
               (  
                N'ID',   
                N'Code',   
                N'Name',   
                N'EnterDTM',   
                N'EnterUserID',   
                N'LastChgDTM',   
                N'LastChgUserID',  
                N'LastChgVersionID',  
                N'Status',   
                N'Status_ID',   
                N'ValidationStatus_ID',  
                N'Version_ID',  
                N'MDMMemberStatus',  
                N'VersionName',  
                N'VersionNumber',  
                N'VersionFlag',  
                N'ValidationStatus',  
                N'EnterDateTime',  
                N'EnterUserName',  
                N'EnterVersionNumber',  
                N'LastChgDateTime',  
                N'LastChgUserName',  
                N'LastChgVersionNumber'  
               )   
            THEN 1  
         WHEN   
            @ObjectType_ID IN (12, 13, 14) AND @Code IN --12=Leaf member; 13=Consolidated member; 14=Collection member  
               (  
               N'ROOT',   
               N'MDMUNUSED',   
               N'MDMMemberStatus'   
               )   
            THEN 1  
         ELSE 0  
      END   
END --fn
GO
