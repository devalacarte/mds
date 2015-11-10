SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
EXEC mdm.udpBusinessRule_AttributeMemberController 1,2,3,'9876',10000,1,7  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRule_AttributeMemberController]  
    (  
    @User_ID INT,   
    @Version_ID INT,   
    @Entity_ID INT,   
    @MemberIdList mdm.IdList READONLY,   
    @MemberType_ID TINYINT,   
    @ProcessOptions INT  
    )  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @BRControllerName NVARCHAR(250)  
    DECLARE @ValidationStatus_Succeeded INT = 3;  
  
    SELECT @BRControllerName = mdm.udfBusinessRuleAttributeMemberControllerNameGetByID(@Entity_ID, @MemberType_ID)  
  
    --Check to see if the Business Rule Controller exists for this entity/member type.  
    IF mdm.udfDBObjectExist(@BRControllerName, N'P') = 1 BEGIN  
  
        --Call the Business Rule Controller to validate the members  
        DECLARE @SQLString NVARCHAR(MAX);  
  
        SELECT @SQLString = N'EXEC mdm.' + @BRControllerName +   
            N' @User_ID,@Version_ID, @Entity_ID, @MemberIdList,@MemberType_ID,@ProcessOptions;'  
  
        EXEC sp_executesql @SQLString,   
            N'@User_ID INT, @Version_ID INT, @Entity_ID INT, @MemberIdList mdm.IdList READONLY, @MemberType_ID TINYINT, @ProcessOptions INT',   
            @User_ID, @Version_ID, @Entity_ID, @MemberIdList, @MemberType_ID, @ProcessOptions;  
      END ELSE BEGIN  
            IF EXISTS (SELECT * from mdm.tblBRBusinessRule WHERE Status_ID = 1 AND Foreign_ID = @Entity_ID AND ForeignType_ID = @MemberType_ID) BEGIN  
                --We have a problem because the ProcessRules sproc doesn't exists.  Return error stating the  
                --user needs to publish business rules to generate the sproc.  
                RAISERROR('MDSERR400038|Unpublished business rules exist. Apply the business rules before running Business Rules or Validation again.', 16, 1);  
                RETURN;  
            END ELSE BEGIN  
                  --No rules exists.  Update members validation status to 3 - succeeded  
                exec mdm.udpMembersValidationStatusUpdate @Entity_ID, @MemberType_ID, @ValidationStatus_Succeeded, @Version_ID, @MemberIdList;  
            END  
    END  
  
    SET NOCOUNT OFF  
END --proc
GO
