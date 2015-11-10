SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
--Puts a msg on the qureue for all entities and all versions in the model  
Then inserts a timer msg onto the queue to effectively "kick it off"  
  
--Account  
EXEC mdm.udpSecurityMemberProcessRebuildModel @Model_ID=3  
*/  
CREATE PROCEDURE [mdm].[udpSecurityMemberProcessRebuildModel]  
(  
	@Model_ID		INT, --Required  
	@ProcessNow		BIT = 0  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;	  
	  
	DECLARE @TempVersionID INT;  
	DECLARE @Items TABLE (VersionID INTEGER);  
	DECLARE @handle UNIQUEIDENTIFIER;   
	  
	INSERT INTO @Items(VersionID)  
	SELECT ID FROM mdm.tblModelVersion   
	WHERE Model_ID = @Model_ID;  
	  
	WHILE EXISTS (SELECT 1 FROM @Items)  
	BEGIN  
		SELECT TOP 1 @TempVersionID = VersionID FROM @Items ORDER BY VersionID;  
		  
		EXEC mdm.udpSecurityMemberProcessRebuildModelVersion @Version_ID=@TempVersionID, @ProcessNow=0;  
		  
		DELETE FROM @Items WHERE VersionID = @TempVersionID;  
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
              
        --set a timer on the handle  
        BEGIN CONVERSATION TIMER (@handle) TIMEOUT = 1;  	  
    END; --if  
	  
	SET NOCOUNT OFF;  
END; --proc
GO
