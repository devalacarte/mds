SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Returns a table with two columns: EntityId and MemberType, with one row  
for each distinct Entity-MemberType combination that should be published  
as per the given critieria. The UserId is required and must pertain to a user  
with admin permission on the given model. The model and entity parameters  
must collectively allow for the model to be uniquely identified. Other than that, the   
criteria parameters are optional. Any that are given will be AND'ed together. If Entity and   
MemberType are null, then the Entity-MemberType pairs for all rules within the model will be returned.  
  
    exec mdm.udpBusinessRulesAPIGet   
        @UserId INT=1,  
        @ModelMuid=NULL,  
        @ModelName="Product",  
        @EntityMuid=NULL,  
        @EntityName=NULL,  
        @MemberType=NULL  
  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRulesGetPublishInfo]  
(  
    @UserId INT = NULL,  
    @ModelMuid UNIQUEIDENTIFIER = NULL,  
    @ModelName NVARCHAR(50) = NULL,  
    @EntityMuid UNIQUEIDENTIFIER = NULL,  
    @EntityName NVARCHAR(50) = NULL,  
    @MemberType INT = NULL /*1 = Leaf, 2 = Consolidated, 3 = Collection. If null, all MemberTypes will be included*/  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    -- change empty strings to null  
    IF LEN(@ModelName) = 0 BEGIN  
        SET @ModelName = NULL     
    END  
    IF LEN(@EntityName) = 0 BEGIN  
        SET @EntityName = NULL     
    END  
  
     -- Validate user model permission.  
    DECLARE @ModelId INT = NULL;  
    IF (@ModelMuid IS NOT NULL OR @ModelName IS NOT NULL OR @EntityMuid IS NOT NULL) BEGIN -- If no model info is provided, then entity MUID is required to determine the model.  
            SELECT   
                @ModelId = Model_ID  
            FROM   
                mdm.viw_SYSTEM_SCHEMA_ENTITY en  
            INNER JOIN  
                mdm.udfSecurityUserModelList(@UserId) acl  
            ON  
                acl.ID = en.Model_ID AND   
                acl.IsAdministrator = 1 AND                 
                (@ModelMuid IS NULL OR @ModelMuid = en.Model_MUID) AND  
                (@ModelName IS NULL OR @ModelName = en.Model_Name) AND  
                (@EntityMuid IS NULL OR @EntityMuid = en.MUID) AND  
                (@EntityName IS NULL OR @EntityName = en.Name);                
    END      
    IF (@ModelId IS NULL) BEGIN    
        RAISERROR('MDSERR120003|The user does not have permission or the object ID is not valid.', 16, 1);  
        RETURN;    
    END    
  
    SELECT  
        DISTINCT  
        br.Entity_ID EntityId,  
        br.BusinessRule_SubTypeID MemberType  
    FROM   
        mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES br  
        INNER JOIN   
        mdm.tblList ls  
        ON  
            (@MemberType IS NULL OR @MemberType = br.BusinessRule_SubTypeID) AND  
            @ModelId = br.Model_ID AND    
            ((@EntityMuid IS NULL AND @EntityName IS NULL) OR @EntityMuid = br.Entity_MUID OR @EntityName = br.Entity_Name) AND  
            br.BusinessRule_StatusID = ls.OptionID AND  
            ls.Group_ID > 0 AND -- Publishable and delete/exclude pending statuses  
            ls.ListCode = CAST(N'lstBRStatus' AS NVARCHAR(50))            
  
    SET NOCOUNT OFF  
END --proc
GO
