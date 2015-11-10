SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpEntityAttachToModel 11, 0, 0;  
*/  
CREATE PROCEDURE [mdm].[udpEntityAttachToModel]  
(  
    @User_ID	    INT,  
    @Entity_ID		INT,  
    @Base_ID		BIT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @Version_ID INT,  
            @CurrentDTM AS DATETIME2(3);  
  
    --Get the Latest Version  
    SELECT @Version_ID = MAX(mv.ID)  
    FROM  mdm.tblModelVersion AS mv  
    INNER JOIN mdm.tblEntity e ON (mv.Model_ID = e.Model_ID)  
    WHERE e.ID = @Entity_ID;  
  
    IF (@Base_ID IS NULL) --Invalid @Base_ID  
        OR (@Version_ID IS NULL) --Invalid @Entity_ID  
        OR NOT EXISTS(SELECT ID FROM mdm.tblUser WHERE ID = @User_ID) --Invalid @User_ID  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
  
    --Update Entity  
    UPDATE mdm.tblEntity SET   
        IsBase = @Base_ID,  
        LastChgDTM = GETUTCDATE(),  
        LastChgUserID = @User_ID,  
        LastChgVersionID = @Version_ID  
    WHERE   
        ID = @Entity_ID;  
  
    RETURN(0);  
  
    SET NOCOUNT OFF;  
END; --proc
GO
