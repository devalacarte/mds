SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Determines whether the the specified model version (or versions) is being validated by the service broker.  
  
DECLARE @IsRunning BIT = 0;  
EXEC mdm.udpValidationIsRunning @Version_ID = 20, @IsRunning = @IsRunning OUTPUT -- checks one version  
SELECT @IsRunning;  
EXEC mdm.udpValidationIsRunning @Entity_ID = 31, @IsRunning = @IsRunning OUTPUT -- checks all versions that pertain to the specified entity's model.  
SELECT @IsRunning;  
EXEC mdm.udpValidationIsRunning @Model_ID = 7, @IsRunning = @IsRunning OUTPUT -- checks all versions that pertain to the specified model.  
SELECT @IsRunning;  
EXEC mdm.udpValidationIsRunning @IsRunning = @IsRunning OUTPUT -- checks all versions  
SELECT @IsRunning;  
  
*/  
CREATE PROCEDURE [mdm].[udpValidationIsRunning]  
(  
     @Model_ID   INT = NULL  
    ,@Version_ID INT = NULL  
    ,@Entity_ID  INT = NULL  
    ,@IsRunning  BIT OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
      
    DECLARE   
         @EventStatus_Running       INT = 1  
        ,@EventStatus_NotRunning    INT = 2  
        ,@EventName_ValidateModel   NVARCHAR(MAX) = N'ValidateModel';  
      
    -- Sanitize inputs  
    SET @Model_ID = NULLIF(@Model_ID, 0);  
    SET @Version_ID = NULLIF(@Version_ID, 0);  
    SET @Entity_ID = NULLIF(@Entity_ID, 0);  
  
    -- Find all running validation event rows for the version(s) that match the given criteria  
    DECLARE @RunningEventIds TABLE (ID INT PRIMARY KEY)  
    INSERT INTO @RunningEventIds  
    SELECT DISTINCT  
        ev.ID  
    FROM mdm.tblEvent ev  
    INNER JOIN mdm.tblModelVersion mv  
        ON ev.Version_ID = mv.ID  
    INNER JOIN mdm.tblEntity en  
        ON mv.Model_ID = en.Model_ID  
    WHERE  
            (@Version_ID IS NULL OR mv.ID       = @Version_ID)  
        AND (@Model_ID   IS NULL OR mv.Model_ID = @Model_ID)  
        AND (@Entity_ID  IS NULL OR en.ID       = @Entity_ID)  
        AND ev.EventName                        = @EventName_ValidateModel  
        AND ev.EventStatus_ID                   = @EventStatus_Running;  
  
    SET @IsRunning = 0;  
    IF EXISTS (SELECT 1 FROM @RunningEventIds)  
    BEGIN  
        -- At least one 'ValidateModel' event row is marked "running", but this does not guarantee that it really is running. Another check is needed to make sure.  
        -- That is, if the service is interrupted (like from a power outage) while validation is in progress, when the db comes back online the event row will still   
        -- be marked "running", even though the validation process has stopped. So, check to make sure the service broker validation process is running.   
        IF EXISTS (SELECT 1 FROM sys.dm_broker_activated_tasks WHERE procedure_name = N'[mdm].[udpValidationQueueActivate]')  
        BEGIN  
            -- The second check passed, but note that it is not foolproof. It detects whether the validation process is running, but it does not specify on which version.   
            -- If the version does not match the criteria passed in to this sproc, then the @IsRunning bit will be wrongly set. However, the probability of this happening   
            -- is very low, and the impact would be small and transitory (ends once the other version finishes validating).  
            SET @IsRunning = 1;  
        END ELSE  
        BEGIN  
            -- Validation isn't running, contrary to what the event table says, so correct the erroneous event table rows.  
            UPDATE ev  
            SET ev.EventStatus_ID = @EventStatus_NotRunning  
            FROM mdm.tblEvent ev  
            INNER JOIN @RunningEventIds re  
                ON ev.ID = re.ID;  
        END;  
    END;  
  
    SET NOCOUNT OFF  
END --proc
GO
