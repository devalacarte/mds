SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpSystemEventGet null,null,null,'ValidateModel'  
exec mdm.udpSystemEventGet 0,0,,null'ValidateModel'  
exec mdm.udpSystemEventGet 18,null,null,null  
exec mdm.udpSystemEventGet null,7,null,null  
exec mdm.udpSystemEventGet null,null,31,null  
exec mdm.udpSystemEventGet 18,7,null,null  
exec mdm.udpSystemEventGet 18,null,null,'ValidateModel', null  
exec mdm.udpSystemEventGet null,null,31,'ValidateModel'  
exec mdm.udpSystemEventGet null,null,31,'ValidateModel', 1  
  
select * from mdm.tblModelVersion  
select * from mdm.tblEvent  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSystemEventGet]  
(  
	@Version_ID	INT = NULL,  
	@Model_ID	INT = NULL,  
	@Entity_ID	INT = NULL,  
	@EventName	NVARCHAR(100),  
	@EventStatus_ID INT = NULL  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
    SELECT   
         @Version_ID = NULLIF(@Version_ID, 0)  
        ,@EventStatus_ID = NULLIF(@EventStatus_ID, 0);  
  
    IF ISNULL(@Entity_ID,0) > 0    		  
        SELECT @Model_ID = Model_ID FROM mdm.tblEntity WHERE ID = @Entity_ID;  
    ELSE  
        SELECT @Model_ID = NULLIF(@Model_ID, 0);  
          
    SELECT  
	     E.ID  
	    ,E.Version_ID  
	    ,E.EventName  
	    ,E.EventStatus_ID  
	    ,E.EnterDTM  
	    ,E.EnterUserID  
	    ,E.LastChgDTM  
	    ,E.LastChgUserID  
	    ,E.MUID  
	    ,U.UserName  
	    ,L.ListOption		AS EventStatus  
	    ,V.Display_ID		AS VersionNumber  
	    ,M.Name				AS ModelName  
    FROM mdm.tblEvent AS E  
    INNER JOIN mdm.tblUser AS U   
        ON E.LastChgUserID = U.ID  
        AND ((@Version_ID IS NULL) OR (E.Version_ID = @Version_ID))  
    INNER JOIN mdm.tblModelVersion AS V   
        ON E.Version_ID = V.ID  
        AND ((@EventName IS NULL) OR (E.EventName = @EventName))  
        AND ((@EventStatus_ID IS NULL) OR (E.EventStatus_ID = @EventStatus_ID))  
    INNER JOIN mdm.tblModel AS M   
        ON V.Model_ID = M.ID  
        AND ((@Model_ID IS NULL) OR (V.Model_ID = @Model_ID))  
    LEFT OUTER JOIN mdm.tblList AS L   
        ON L.OptionID = E.EventStatus_ID AND L.ListCode = N'lstEventStatus'  
		      
	SET NOCOUNT OFF;  
END; --proc
GO
