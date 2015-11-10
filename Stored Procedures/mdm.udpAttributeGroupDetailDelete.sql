SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpAttributeGroupDetailDelete 1,1,1;  
    SELECT * FROM mdm.tblAttributeGroupDetail;  
*/  
CREATE PROCEDURE [mdm].[udpAttributeGroupDetailDelete]  
(  
   @User_ID                INT,  
   @AttributeGroup_ID   INT,  
   @Type_ID                INT --Attributes = 1,Users = 2,UserGroups = 3  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @TempModel_ID        INT,  
            @TempEntity_ID        INT,  
            @TempMemberType_ID    TINYINT,  
            @TempVersion_ID        INT;  
  
    --Get Entity  
    SELECT @TempEntity_ID = Entity_ID, @TempMemberType_ID = MemberType_ID   
    FROM mdm.tblAttributeGroup   
    WHERE ID = @AttributeGroup_ID;  
  
    --Get MemberType_ID and latest Version  
    SELECT   
        @TempModel_ID = e.Model_ID,  
        @TempVersion_ID = MAX(mv.ID)   
    FROM mdm.tblModelVersion AS mv  
    INNER JOIN mdm.tblEntity AS e ON (mv.Model_ID = e.Model_ID)  
    WHERE e.ID = @TempEntity_ID  
    GROUP BY e.Model_ID;  
  
    IF @Type_ID = 1 BEGIN --Attributes  
  
        DELETE FROM mdm.tblAttributeGroupDetail   
        WHERE AttributeGroup_ID = @AttributeGroup_ID;  
  
    END ELSE IF @Type_ID = 2 BEGIN --Users  
  
        EXEC mdm.udpSecurityPrivilegesDelete NULL, 1, 5, @AttributeGroup_ID;  
  
    END ELSE IF @Type_ID = 3 BEGIN --User Groups  
  
        EXEC mdm.udpSecurityPrivilegesDelete NULL, 2, 5, @AttributeGroup_ID;  
  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
