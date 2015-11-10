SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Performs operations common to the BRItemProperty Add and Update operations  
  
The meaning of @Value's input value depends on @PropertyType_ID,  
as given in the below table:  
  
   @PropertyType_ID         @Value (input)      @Value (output)  
  ******************       ****************    *****************  
    1 (Constant)            freeform string        unchanged  
    2 (Attribute)           Attribute MUID         int ID  
    3 (ParentAttribute)     Hierarchy MUID         int ID        
    4 (DBAAttribute)        Attribute MUID         int ID  
    5 (AttributeValue)      Code (i.e. 'Blue')     unchanged  
    6 (Blank)               doesn't matter         'Blank'  
  
@Value's output value will contain the correct value for writing to   
tblBRItemProperties.Value.  
For @PropertyType_ID values 2 and 4, if @Value's input value is null or invalid,   
then the Attribute's int ID will be looked up from the given @AttributeName.   
In all other cases, @AttributeName is ignored.  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleItemPropertyAddHelper]  
(  
    @BRItem_ID              INT = NULL,  
    @PropertyType_ID        INT = NULL,  
    @AttributeName          NVARCHAR(128) = NULL, -- optional  
    @Value                  NVARCHAR(999) = NULL OUTPUT, -- input and output  
    @Failed                 BIT OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET @Failed = 1  
      
    IF @PropertyType_ID IN (2,3,4) BEGIN  
        -- try to convert @Value to a GUID  
        DECLARE @ValueMuid UNIQUEIDENTIFIER  
        BEGIN TRY  
            SET @ValueMuid = CONVERT(UNIQUEIDENTIFIER, @Value)  
        END TRY  
        BEGIN CATCH  
            SET @ValueMuid = NULL  
        END CATCH  
    END  
  
    IF @PropertyType_ID IN (2,4) BEGIN -- 2 = Attribute, 4 = DBAAttribute  
        IF @ValueMuid IS NOT NULL BEGIN  
            -- lookup the Attribute's ID from its MUID  
            SET @Value = CONVERT(NVARCHAR(999), (SELECT TOP 1 ID FROM mdm.tblAttribute WHERE MUID = @ValueMuid));  
        END  
        IF @Value IS NULL AND @AttributeName IS NOT NULL BEGIN  
            -- lookup the Attribute ID from the given @AttributeName  
            SET @Value = CONVERT(NVARCHAR(999),   
                (SELECT TOP 1 a.Attribute_ID  
                 FROM   
                    mdm.tblBRItem it  
                    INNER JOIN  
                    mdm.tblBRLogicalOperatorGroup lg  
                        ON  
                            it.ID = @BRItem_ID AND  
                            it.BRLogicalOperatorGroup_ID = lg.ID  
                    INNER JOIN  
                    mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES b  
                        ON  
                            lg.BusinessRule_ID = b.BusinessRule_ID  
                    INNER JOIN   
                    mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES a  
                        ON  
                            a.Attribute_Name = @AttributeName AND  
                            b.Entity_ID = a.Entity_ID  
                    ORDER BY it.ID ));  
        END              
        IF @Value IS NULL BEGIN  
            RAISERROR('MDSERR400003|The attribute reference is not valid. The attribute was not found.', 16, 1);  
            RETURN;  
        END  
    END ELSE IF @PropertyType_ID = 3 BEGIN -- 3 = ParentAttribute  
        -- lookup the Hierarchy's ID from its MUID  
        SET @Value = CONVERT(NVARCHAR(999), (SELECT TOP 1 ID FROM mdm.tblHierarchy WHERE MUID = @ValueMuid));  
        IF @Value IS NULL BEGIN  
            SET @Value = NULL;  
            RAISERROR('MDSERR400021|The hierarchy identifier is not valid. The MUID was not found.', 16, 1);  
            RETURN;  
        END  
    END ELSE IF @PropertyType_ID = 5 BEGIN -- 5 = AttributeValue  
        -- @Value is a member code, so trim its whitespace. Note that the member code should not be validated (i.e. checked to make sure   
        -- there exists a member with the specified code) here, so that it is possible for Model Deployment to deploy business rules with metadata, but  
        -- without master data.   
        SET @Value = LTRIM(RTRIM(@Value));  
    END ELSE IF @PropertyType_ID = 6 BEGIN -- 6 = Blank  
        SET @Value = CONVERT(NVARCHAR(999), N'Blank')  
    END  
  
    SET @Failed = 0  
END --proc
GO
