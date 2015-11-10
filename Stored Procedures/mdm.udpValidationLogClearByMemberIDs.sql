SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
Deletes all validation issues for the specified set of member ids.  
  
DECLARE @MemberIdList       mdm.IdList;  
INSERT INTO @MemberIdList  
VALUES (1), (2), (3)  
  
EXEC mdm.udpValidationLogClearByMemberIDs 7, 5, 1, @MemberIdList  
SELECT * FROM mdm.tblValidationLog  
*/  
CREATE PROCEDURE [mdm].[udpValidationLogClearByMemberIDs]  
(  
     @Version_ID     INT  
    ,@Entity_ID      INT  
    ,@MemberType_ID  TINYINT  
    ,@MemberIdList   mdm.IdList READONLY  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DELETE lg  
    FROM mdm.tblValidationLog lg  
    INNER JOIN @MemberIdList m  
        ON  
            lg.Member_ID = m.ID  
    WHERE  
        lg.Version_ID = @Version_ID  
        AND lg.Entity_ID = @Entity_ID  
        AND lg.MemberType_ID = @MemberType_ID  
  
    SET NOCOUNT OFF  
END --proc
GO
