SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    Wrapper for mdm.udpAttributeGroupDetailSave sproc.  
*/  
CREATE PROCEDURE [mdm].[udpAttributeGroupDetailSaveByMUID]  
(  
    @User_ID				INT,  
    @AttributeGroup_MUID	UNIQUEIDENTIFIER,  
    @MUID					UNIQUEIDENTIFIER,  
    @Name					NVARCHAR(100),  
    @Type_ID				INT, --Attributes = 1,Users = 2,UserGroups = 3  
    @Return_ID				INT = NULL OUTPUT,  
    @Return_MUID			UNIQUEIDENTIFIER = NULL OUTPUT -- Not currently used.  Here to maintain consistent Save return signature.  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @AttributeGroup_ID INT,  
            @ID INT,  
            @Entity_ID INT,  
            @MemberType_ID INT;  
  
    IF @Name IS NULL AND @MUID IS NULL --Missing identifier  
    BEGIN  
        RAISERROR('MDSERR200047|The attribute group detail cannot be saved. The attribute group, user, or user group ID is not valid.', 16, 1);  
        RETURN;  
    END;        
        
    SELECT  
         @AttributeGroup_ID = ID  
        ,@Entity_ID = Entity_ID  
        ,@MemberType_ID = MemberType_ID  
    FROM mdm.tblAttributeGroup WHERE MUID = @AttributeGroup_MUID;  
      
    SELECT  @ID = CASE @Type_ID  
        WHEN 1 THEN (SELECT ID FROM mdm.tblAttribute   
                WHERE Entity_ID = @Entity_ID AND MemberType_ID = @MemberType_ID AND ((@MUID IS NULL OR MUID = @MUID)) AND ((@Name IS NULL) OR ([Name] = @Name)))  
        WHEN 2 THEN (SELECT ID FROM mdm.tblUser WHERE   
            ((@MUID IS NULL OR MUID = @MUID)) AND ((@Name IS NULL) OR ([UserName] = @Name)))  
        WHEN 3 THEN (SELECT ID FROM mdm.tblUserGroup   
            WHERE ((@MUID IS NULL OR MUID = @MUID)) AND ((@Name IS NULL) OR ([Name] = @Name)))  
    END;   
  
    EXEC mdm.udpAttributeGroupDetailSave @User_ID, @AttributeGroup_ID, @ID, @Type_ID, @Return_ID OUTPUT;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
