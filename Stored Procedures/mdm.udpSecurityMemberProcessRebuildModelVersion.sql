SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
--Puts a msg on the qureue for all entities in the version.  
Then inserts a timer msg onto the queue to effectively "kick it off"  
  
--Account/Version3  
EXEC mdm.udpSecurityMemberProcessRebuildModelVersion @Version_ID=3  
*/  
CREATE PROCEDURE [mdm].[udpSecurityMemberProcessRebuildModelVersion]  
(  
    @Version_ID		INT, --Required  
    @ProcessNow		BIT = 0  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
      
    DECLARE @Items TABLE (EntityID INTEGER);  
    DECLARE	@TempEntityID INTEGER;  
    DECLARE @handle UNIQUEIDENTIFIER;   
      
    --Insert a msg into the Securitymember queue for all entities in the version  
    INSERT INTO @Items(EntityID)  
    SELECT e.ID AS Entity_ID  
    FROM mdm.tblEntity AS e  
    INNER JOIN mdm.tblModelVersion AS v   
        ON v.Model_ID = e.Model_ID  
    WHERE v.ID = @Version_ID;  
      
    WHILE EXISTS (SELECT 1 FROM @Items)  
    BEGIN  
        SELECT TOP 1 @TempEntityID = EntityID FROM @Items ORDER BY EntityID;  
          
        EXEC mdm.udpSecurityMemberQueueSave   
            @Role_ID    = NULL,-- update member count cache for all users  
            @Version_ID = @Version_ID,   
            @Entity_ID  = @TempEntityID;  
          
        DELETE FROM @Items WHERE EntityID=@TempEntityID;  
    END; --while  
              
    --Insert a msg into the Securitymember timer queue to "kick it off"	  
    IF @ProcessNow=1  
    BEGIN  
        --get the existing conversation handle if possible  
        SET @handle = mdm.udfServiceGetConversationHandle(  
            N'microsoft/mdm/service/securitymembertimer',  
            N'microsoft/mdm/service/system');  
  
  
        IF @handle IS NULL   
            BEGIN DIALOG CONVERSATION @handle    
                FROM SERVICE [microsoft/mdm/service/securitymembertimer]    
                TO SERVICE N'microsoft/mdm/service/system'    
                WITH ENCRYPTION=OFF;  
  
        BEGIN CONVERSATION TIMER (@handle) TIMEOUT = 1;  	  
    END; --if  
       
    SET NOCOUNT OFF;  
END; --proc
GO
