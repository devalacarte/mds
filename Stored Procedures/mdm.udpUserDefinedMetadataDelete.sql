SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Deletes a user-defined metadata member  
  
EXEC mdm.udpUserDefinedMetadataDelete @Object_Type='Model',   
                                      @Object_ID='420d36b0-4efc-4870-9433-76a9dec73aaf',   
*/  
CREATE PROCEDURE [mdm].[udpUserDefinedMetadataDelete]  
(  
    @Object_Type    NVARCHAR(50),		-- the MDM object type (model, entity, attribute, etc)  
    @Object_ID		UNIQUEIDENTIFIER	-- the MUID for the object that is associated with the metadata  
)  
  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
  
    SET NOCOUNT ON;  
      
    --Declare local variables  
    DECLARE @MetadataObjectId   INT,			-- the unique key for the metamodel object (model, entity, etc) from tblList  
            @MemberTableName	NVARCHAR(255),	-- name of member table to work with (eg, tbl_1_2_EN)  
            @MemberIdSQL		NVARCHAR(max),	-- dynamic SQL to retrieve member id from appropriate member table  
            @SQL                NVARCHAR(max),  
            @MemberId			INT,			-- the unique key of the member to delete  
            @ReturnId			INT,  
            @return_value		INT;  
  
    --Initialize output parameters and local variables  
    SELECT @ReturnId = 1  
      
    --Test for invalid parameters  
    --Ensure that object type and source MUID are supplied  
    IF (@Object_Type IS NULL) OR (@Object_ID IS NULL)  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if */  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION MetadataMemberDelete;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        -- Get the metadata object id from tblList  
        SELECT @MetadataObjectId = OptionID FROM mdm.tblList WHERE ListCode= CAST(N'lstMetadataDefinitions' AS NVARCHAR(50)) AND ListOption= CAST(@Object_Type AS NVARCHAR(250))  
  
        -- Get the member table that houses the metadata  
        SELECT @MemberTableName = EntityTable FROM mdm.tblEntity WHERE ID = @MetadataObjectId  
  
        -- Get the member id  
        SET @MemberIdSQL = N'SET @MemberId = (SELECT TOP 1 ID FROM mdm.' + @MemberTableName + N' WHERE Status_ID = 1 AND ObjectId = @Object_ID ORDER BY ID DESC)'  
        EXEC sp_executesql @MemberIdSQL, N'@Object_ID UNIQUEIDENTIFIER, @MemberId INT OUTPUT', @Object_ID, @MemberId OUTPUT  
          
        ------------------------------------------------------  
        -- We are now intentionally doing a hard delete  
        -- Since the associated object is being physically   
        -- deleted from the hub, we ensure that these  
        -- records are not left around in an orphaned  
        -- state, and that there is no way to reverse   
        -- the object deletion that invoked the metadata   
        -- deletion.  
        ------------------------------------------------------  
        DECLARE @TempTable TABLE(ID INT NOT NULL);  
        DECLARE @TempHierachy_ID AS INT,  
        @HierarchyTable		sysname;  
          
        INSERT INTO @TempTable(ID)  
        SELECT ID FROM mdm.tblHierarchy   
        WHERE Entity_ID = @MetadataObjectId  AND IsMandatory = 1;  
  
        --Get the Entity Hierarchy Table Name  
        SET @HierarchyTable = mdm.udfTableNameGetByID(@MetadataObjectId, 4);  
  
        -- Delete the members in the hierarchy relationships table  
        WHILE EXISTS(SELECT 1 FROM @TempTable) BEGIN  
            SELECT TOP 1 @TempHierachy_ID = ID FROM @TempTable;  
  
            SET @SQL = N'  
            DELETE FROM mdm.' + quotename(@HierarchyTable) + N'  
            WHERE Version_ID = 1   
                AND ChildType_ID = 1   
                AND Parent_HP_ID IS NULL  
                AND Hierarchy_ID = @TempHierachy_ID   
                AND Child_EN_ID = @Member_ID  
                AND Child_HP_ID IS NULL';  
                 
            EXECUTE sp_executesql @SQL, N'@TempHierachy_ID INT, @Member_ID INT', @TempHierachy_ID, @MemberId;  
              
            DELETE FROM @TempTable WHERE ID = @TempHierachy_ID;  
        END; --while  
                  
        --delete the member record   
        SET @SQL = N'  
            DELETE FROM mdm.' + quotename(@MemberTableName) + N'  
            WHERE   
                Version_ID = 1  
                AND ID = @MemberId   
                AND ObjectId = @ObjectId';  
          
        EXECUTE sp_executesql @SQL, N'@MemberId INT, @ObjectId UNIQUEIDENTIFIER', @MemberId, @Object_ID;  
          
        -- delete the records in Transactions Annotation   
        DELETE a  
            FROM mdm.tblTransactionAnnotation a  
            INNER JOIN mdm.tblTransaction t ON   
                a.Transaction_ID = t.ID  
            WHERE t.Version_ID = 1  
                AND MemberType_ID =1  
                AND Entity_ID = @MetadataObjectId  
                AND Member_ID = @MemberId;  
              
        -- delete the records in Transactions  
        DELETE t FROM mdm.tblTransaction t   
            WHERE t.Version_ID = 1  
                AND MemberType_ID =1  
                AND Entity_ID = @MetadataObjectId  
                AND Member_ID = @MemberId;  
  
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
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION MetadataMemberDelete;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
  
        --On error, return NULL results  
        SELECT @ReturnId = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
  
END; --proc
GO
