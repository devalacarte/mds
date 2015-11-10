SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpVersionDelete 7;  
    SELECT * FROM mdm.tblModelVersion;  
*/  
CREATE PROCEDURE [mdm].[udpVersionDelete]  
(  
    @Version_ID	INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
        @ID			        INT,  
        @Model_ID	        INT,  
        @Entity_ID          INT,  
        @MemberType_ID      INT,  
        @TableName	        sysname,  
        @SQL		        NVARCHAR(MAX),  
        @DbaUpdateSeqment   NVARCHAR(MAX),  
        @DbaRowCount        INT;  
  
    --Get the @Model_ID that owns the specific @Version_ID  
    SELECT @Model_ID = Model_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID;  
  
    --Check for invalid parameters      
    IF (@Version_ID IS NULL OR @Model_ID IS NULL) BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
      
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        --Temporary table to hold all the entity table names  
        DECLARE @EntityTable TABLE  
        (  
             RowNumber INT IDENTITY(1, 1) NOT NULL PRIMARY KEY  
            ,TableName sysname NOT NULL  
        );  
          
        --Temporary table to hold all the DBA column names  
        DECLARE @DbaTable TABLE  
        (  
             RowNumber INT IDENTITY(1, 1) NOT NULL PRIMARY KEY  
            ,Entity_ID INT NOT NULL   
            ,MemberType_ID INT NOT NULL   
            ,TableName sysname NOT NULL  
            ,DbaColumnName sysname NOT NULL  
        );  
  
        --Pre-deletion step  
          
        --Delete the subscription views associated with the version  
        EXEC mdm.udpSubscriptionViewsDelete   
            @Model_ID               = NULL,  
            @Version_ID             = @Version_ID,  
            @Entity_ID	            = NULL,  
            @DerivedHierarchy_ID    = NULL;  
  
        --Update all DBA values to NULL for this version.  This ensures there will be no FK violations when deleting member data below.  
        INSERT INTO @DbaTable   
        SELECT  
             att.Entity_ID  
            ,att.Attribute_MemberType_ID    
            ,seq.TableName  
            ,att.Attribute_Column AS DbaColumnName  
        FROM mdm.viw_SYSTEM_SCHEMA_ATTRIBUTES att  
        INNER JOIN mdm.udfEntityDependencyTree(@Model_ID, NULL) seq  
        ON seq.Entity_ID = att.Entity_ID  
        AND att.Attribute_MemberType_ID = seq.MemberType_ID  
        AND att.Attribute_DBAEntity_ID <> 0  
        AND att.Model_ID = @Model_ID  
        ORDER BY att.Entity_ID, att.Attribute_MemberType_ID;  
  
        DECLARE @Counter INT    = 1,  
                @MaxCounter INT = (SELECT MAX(RowNumber) FROM @DbaTable);  
  
        WHILE @Counter <= @MaxCounter  
        BEGIN  
  
            SELECT  
                 @Entity_ID = Entity_ID  
                ,@MemberType_ID = MemberType_ID    
                ,@TableName = TableName  
            FROM @DbaTable  
            WHERE RowNumber = @Counter;  
              
            SELECT @DbaUpdateSeqment=N'';  
            --Generate the portion of the UPDATE statment that sets the DBA columns to NULL  
            --This sets and appends to the variable all in one statement.  
            SELECT  
                @DbaUpdateSeqment = @DbaUpdateSeqment + DbaColumnName + N'=NULL,'  
            FROM @DbaTable  
            WHERE Entity_ID = @Entity_ID  
            AND   MemberType_ID = @MemberType_ID;  
              
            --Get the rowcount of the number of DBAs.  
            SELECT @DbaRowCount = @@ROWCOUNT;  
              
            --Drop the comma on the end.  
            SELECT @DbaUpdateSeqment = SUBSTRING(@DbaUpdateSeqment,1,LEN(@DbaUpdateSeqment)-1)  
  
            SET @SQL = N'  
                UPDATE mdm.' + quotename(@TableName) + N' SET ' + @DbaUpdateSeqment + N'   
                WHERE Version_ID = ' + CONVERT(NVARCHAR(30), @Version_ID) + N';';  
                  
            --PRINT @SQL  
            EXEC sp_executesql @SQL;  
  
            --Increment by the number of DBAs to get to the next Entity or MemberType.  
            SET @Counter += @DbaRowCount;  
  
        END; --while  
  
        --Delete Member data for this version.  Order of deletion doesn't matter since all DBA values have been set to NULL above.  
        INSERT INTO @EntityTable   
            SELECT  TableName  
            FROM mdm.udfEntityDependencyTree(@Model_ID, NULL)  
            ORDER BY [Level] DESC;              
  
        SELECT @Counter = 1,  
                @MaxCounter = (SELECT MAX(RowNumber) FROM @EntityTable);  
  
        WHILE @Counter <= @MaxCounter  
        BEGIN  
            SELECT   
                @TableName = TableName  
            FROM @EntityTable  
            WHERE RowNumber = @Counter;  
              
            SET @SQL = N'  
                DELETE FROM mdm.' + quotename(@TableName) + N'  
                WHERE Version_ID = @Version_ID';  
                  
            --PRINT @SQL  
            EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID;  
  
            SET @Counter += 1;  
        END; --while  
          
        --Delete all notification queue related items  
        DELETE FROM mdm.tblNotificationUsers where Notification_ID IN (select ID from mdm.tblNotificationQueue where Version_ID = @Version_ID);		  
        DELETE FROM mdm.tblNotificationQueue where Version_ID = @Version_ID;  
          
        --Delete all validation issues  
        DELETE FROM mdm.tblValidationLog where Version_ID = @Version_ID;  
  
        --Delete all security role access member items  
        DELETE FROM mdm.tblSecurityRoleAccessMember where Version_ID = @Version_ID;  
  
        -- Delete the Version out of ModelVersion table  
        DELETE FROM mdm.tblModelVersion WHERE ID = @Version_ID;  
          
        --Commit only if we are not nested  
        IF @TranCounter = 0 COMMIT TRANSACTION;  
        RETURN(0);  
  
    END TRY  
    --Compensate as necessary  
    BEGIN CATCH  
  
        -- Get error info  
        DECLARE  
            @ErrorMessage NVARCHAR(4000),  
            @ErrorSeverity INT,  
            @ErrorState INT;  
        EXEC mdm.udpGetErrorInfo  
            @ErrorMessage = @ErrorMessage OUTPUT,  
            @ErrorSeverity = @ErrorSeverity OUTPUT,  
            @ErrorState = @ErrorState OUTPUT;  
  
        IF @TranCounter = 0 ROLLBACK TRANSACTION;  
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
  
        --On error, return NULL results  
        --SELECT @Return_ID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
