SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpValidateModel 1, 9, 5, 0  
select * from mdm.tblValidationLog  
truncate table mdm.tblValidationLog  
select * from mdm.tblModelVersion  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpValidateModel]  
(  
	@User_ID		INT,  
	@Model_ID		INT,  
	@Version_ID		INT,  
	@Status_ID		INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
  
	EXEC mdm.udpSystemEventSave @User_ID,@Version_ID,'ValidateModel',1  
  
	DECLARE @MetaID		INT;  
	DECLARE @EntityID	INT;  
	DECLARE	@Entities   TABLE (EntityID int,ProcessSeq int);  
  
	--Determine processing sequence of entities based on entity dependency or derived hierarchy processing priority.  
	INSERT INTO @Entities  
        SELECT   
              Entity_ID  
             ,[Level]  
        FROM mdm.udfEntityGetProcessingSequence(@Model_ID)  
        ORDER BY [Level]  
		  
	DECLARE @CurrentStatus_ID TINYINT  
	DECLARE @Counter INT = 1;  
	DECLARE @MaxCounter INT = (SELECT MAX(ProcessSeq) FROM @Entities);  
  
	WHILE @Counter <= @MaxCounter  
	BEGIN  
		SELECT @EntityID = EntityID FROM @Entities WHERE ProcessSeq = @Counter;  
    	EXEC mdm.udpValidateEntity @User_ID, @Version_ID, @EntityID  
    	  
		SELECT @CurrentStatus_ID = EventStatus_ID FROM mdm.tblEvent E WHERE E.LastChgUserID = @User_ID AND EventName = CAST(N'ValidateModel' AS NVARCHAR(100)) AND Version_ID = @Version_ID  
		  
		IF @CurrentStatus_ID = 2 --Canceled  
			SET @Counter = @MaxCounter + 1;  
		ELSE  
            SET @Counter += 1;  
	END -- WHILE  
  
	EXEC mdm.udpSystemEventSave @User_ID,@Version_ID,N'ValidateModel',2  
  
	IF @Status_ID = 3 --Commit  
	   BEGIN  
		  IF NOT EXISTS(SELECT 1 FROM mdm.viw_SYSTEM_ISSUE_VALIDATION WHERE Version_ID = @Version_ID)  
			 BEGIN  
				EXEC mdm.udpVersionSave @User_ID,@Model_ID,@Version_ID,null,3,NULL,NULL,NULL  
			 END  
	   END  
  
	SET NOCOUNT OFF  
END --proc
GO
