SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpMemberAttributeSave @User_ID = 1, @Version_ID = 1, @Entity_ID = 1, @MemberCode = NULL, @Member_ID = 2,   
    @MemberType_ID = 1, @AttributeName = 'Name', @AttributeValue = ' B ', @LogFlag = 1;  
  
    EXEC mdm.udpMemberAttributeSave @User_ID = 1, @Version_ID = 1, @Entity_ID = 1, @MemberCode = NULL, @Member_ID = 2,   
    @MemberType_ID = 1, @AttributeName = 'Code', @AttributeValue = '  ', @LogFlag = 1;  
  
    SELECT * FROM mdm.tblEntity WHERE ID = 2;  
    SELECT * FROM mdm.tblAttribute WHERE Entity_ID = 1;  
    SELECT * FROM mdm.tbl_1_1_EN;  
      
*/  
CREATE PROCEDURE [mdm].[udpMemberAttributeSave]  
(  
    @User_ID				INT,	  
    @Version_ID				INT,  
    @Entity_ID     			INT,  
    @MemberCode    			NVARCHAR(250) = NULL,  
    @Member_ID     			INT = NULL,  
    @MemberType_ID			INT,  
    @AttributeName			NVARCHAR(250),  
    @AttributeValue			NVARCHAR(MAX) = NULL,  
    @LogFlag				INT = NULL, --1 = Log anything else = NotLog  
    @DoInheritanceRuleCheck	BIT = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @TableName					sysname,  
            @TableColumn				sysname,  
            @SQL						NVARCHAR(MAX),  
            @Attribute_ID				INT,  
            @AttributeType_ID           INT,  
            @DataType_ID				INT,  
            @DataTypeNumeric			INT = 2,  
            @TempPriorValue				NVARCHAR(MAX),  
            @TempUpdatedValue			NVARCHAR(MAX),  
            @Return						INT,  
            @ChangeTrackingGroup		INT,  
            @CodeGenEnabled             BIT = 0;  
  
    DECLARE @ValidationStatus           INT = 4;  
      
    --Test for invalid parameters  
    IF @User_ID IS NULL OR @Version_ID IS NULL OR @Entity_ID IS NULL   
        OR (@AttributeName IS NULL OR LEN(@AttributeName) = 0)    
        OR ((@Member_ID IS NULL AND @MemberType_ID IS NULL)   
        AND (@MemberCode IS NULL OR LEN(@MemberCode) =0))  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
  
    --Check if code gen is enabled for this entity  
    EXEC @CodeGenEnabled = mdm.udpIsCodeGenEnabled @Entity_ID;  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        IF @Member_ID IS NULL BEGIN  
            --EXEC mdm.udpMemberIDGetByCode @Version_ID, @Entity_ID, @MemberCode, @MemberType_ID, @Member_ID OUTPUT;  
  
            -- Get the Member_ID and MemberType_ID from the existing Code  
            EXEC mdm.udpMemberTypeIDAndIDGetByCode @Version_ID,@Entity_ID,@MemberCode,@MemberType_ID OUTPUT,@Member_ID OUTPUT  
        END; --if  
          
        --Initialize variables  
        SELECT   
            @Return = 0,  
            @TableName = mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID),  
            @AttributeName = NULLIF(LTRIM(RTRIM(@AttributeName)), N''),  
            @AttributeValue = CASE @AttributeName  
                --Clean member Code value  
                WHEN N'Code' THEN   
                    NULLIF(LTRIM(RTRIM(@AttributeValue)), N'')  
                --Clean member Name value  
                WHEN N'Name' THEN   
                    NULLIF(LTRIM(RTRIM(@AttributeValue)), N'') --Ditto  
                --Clean any other value  
                ELSE  
                    NULLIF(LTRIM(RTRIM(@AttributeValue)), N'') --Ditto  
            END; --case  
  
        --Get The Attribute ID  
        SELECT  
            @Attribute_ID = ID,  
            @AttributeType_ID = AttributeType_ID,  
            @DataType_ID = DataType_ID,  
            @TableColumn = TableColumn,   
            @AttributeName = [Name],  
            @ChangeTrackingGroup = ChangeTrackingGroup  
        FROM mdm.tblAttribute   
        WHERE [Name] = @AttributeName  
        AND Entity_ID = @Entity_ID   
        AND MemberType_ID = @MemberType_ID;  
  
        --Perform additional operations for Code changes.  
        IF @AttributeName = N'Code' BEGIN  
              
            --Member code can not be null  
            IF @MemberCode IS NULL  
                BEGIN  
                    RAISERROR('MDSERR310022|The code can not be empty', 16, 1);  
                    RETURN;  
                END             
  
            --Ensure the new code is unique.  
            DECLARE   
                @ActiveCodeExists BIT = 0,  
                @DeactivatedCodeExists BIT = 0;  
  
            EXEC mdm.udpMemberCodeCheck @Version_ID, @Entity_ID, @AttributeValue, @ActiveCodeExists OUTPUT, @DeactivatedCodeExists OUTPUT  
            IF @ActiveCodeExists = 1 BEGIN   
                RAISERROR('MDSERR300003|The member code already exists.', 16, 1);  
            END		  
            IF @DeactivatedCodeExists = 1 BEGIN  
                RAISERROR('MDSERR300034|The member code is already used by a member that was deleted. Pick a different code or ask an administrator to remove the deleted member from the MDS database.', 16, 1);  
            END  
  
            --If member code is non-null and code gen is enabled process the new code  
            IF @AttributeValue IS NOT NULL AND @CodeGenEnabled = 1  
                BEGIN  
                    --Gather up the valid user provided codes  
                    DECLARE @CodesToProcess mdm.MemberCodes;  
  
                    INSERT @CodesToProcess (MemberCode)   
                    VALUES (@MemberCode);  
  
                    --Process the user-provided codes to update the code gen info table with the largest one  
                    EXEC mdm.udpProcessCodes @Entity_ID, @CodesToProcess;  
                END  
              
            --Update any existing validation issues associated with this member  
            --to ensure they reference the new member code.  
            UPDATE mdm.tblValidationLog  
            SET MemberCode = @AttributeValue  
            WHERE Member_ID = @Member_ID  
            AND MemberType_ID = @MemberType_ID  
            AND Version_ID = @Version_ID  
        END  
  
        --Get The Prior Value  
        EXEC mdm.udpMemberPriorValueGet @Version_ID, @TableName, @TableColumn, @Member_ID, @TempPriorValue OUTPUT;  
  
        DECLARE @ValueSql as NVARCHAR(MAX) = N'@Value';  
        IF (@DataType_ID = @DataTypeNumeric AND CHARINDEX(N'E', UPPER(@AttributeValue)) >= 0) BEGIN  
            -- The new value is in scientific notation, which cannot be directly converted to type DECIMAL. So, first convert it  
            -- to FLOAT.  
            SET @ValueSql = N'CONVERT(FLOAT, ' + @ValueSql + N')';  
        END  
          
        SET @SQL = N'    
            UPDATE mdm.' + quotename(@TableName) + N' SET    
                ' + quotename(@TableColumn) + N' = ' + @ValueSql + N',    
                ValidationStatus_ID = @ValidationStatus,  
                LastChgDTM = GETUTCDATE(),  
                LastChgUserID = @User_ID,  
                LastChgVersionID = @Version_ID' + CASE WHEN @MemberType_ID IN(1,2) THEN  N',    
                ChangeTrackingMask = ISNULL(ChangeTrackingMask, 0) | ISNULL(POWER(2,@ChangeTrackingGroup -1), 0)' ELSE N'' END  + N'  
            WHERE  
                ID = @Member_ID AND  
                Version_ID = @Version_ID;'  
  
        --PRINT(@SQL);  
        EXEC sp_executesql @SQL,   
            N'@Value NVARCHAR(MAX),@ValidationStatus INT, @User_ID INT, @Version_ID INT, @Member_ID INT, @ChangeTrackingGroup INT',   
            @AttributeValue, @ValidationStatus, @User_ID, @Version_ID, @Member_ID, @ChangeTrackingGroup;  
  
  
        IF @DoInheritanceRuleCheck = 1 BEGIN  
            DECLARE @ChildEntityTable			sysname  
            DECLARE @ChildAttributeColumnName	sysname  
  
            --Check for Inheritance Business Rules and update dependent members validation status.  
            --Attribute Inheritance   
            SELECT   
                 @ChildEntityTable = chiEnt.EntityTableName  
                ,@ChildAttributeColumnName = ChildAttributeColumnName  
            FROM mdm.viw_SYSTEM_BUSINESSRULES_ATTRIBUTE_INHERITANCE_HIERARCHY i  
            INNER JOIN mdm.viw_SYSTEM_TABLE_NAME chiEnt  
                ON i.ChildEntityID = chiEnt.ID  
            WHERE ParentEntityID = @Entity_ID  
            AND Attribute_MemberType_ID = @MemberType_ID  
            AND ParentAttributeColumnName = @TableColumn  
              
            IF @ChildAttributeColumnName IS NOT NULL BEGIN  
                --Update immediate dependent member table's validation status.  
                SELECT @SQL = N'  
                     UPDATE   mdm.' + quotename(@ChildEntityTable) + N'  
                     SET      ValidationStatus_ID = 5  
                     FROM  mdm.' + quotename(@ChildEntityTable) + N' ch  
                           INNER JOIN mdm.tblModelVersion dv   
                              ON ch.Version_ID = dv.ID   
                              AND dv.Status_ID <> 3  
                              AND   ch.ValidationStatus_ID <> 5  
                              AND   ch.Version_ID = @Version_ID  
                              AND   ch.' + quotename(@ChildAttributeColumnName) + N' = @Member_ID;  
                     '  
                EXEC sp_executesql @SQL, N'@Version_ID INT, @Member_ID INT', @Version_ID, @Member_ID;  
            END -- IF @ChildAttributeColumnName  
              
            --Hierarchy Inheritance.    
            --  Only need to do this if a hierarchy parent attribute is being updated.  
            IF @MemberType_ID = 2 BEGIN  
                SELECT TOP 1   
                    @ChildAttributeColumnName = i.AttributeColumnName  
                FROM mdm.viw_SYSTEM_BUSINESSRULES_HIERARCHY_CHANGEVALUE_INHERITANCE i  
                WHERE AttributeColumnName = @TableColumn  
                AND   EntityID = @Entity_ID  
                ORDER BY i.HierarchyID;  
                  
                IF @ChildAttributeColumnName IS NOT NULL BEGIN  
                    DECLARE @parentIdList mdm.IdList;  
                    INSERT INTO @parentIdList (ID) VALUES (@Member_ID);  
                      
                    EXEC mdm.udpHierarchyMembersValidationStatusUpdate  
                         @Entity_ID = @Entity_ID  
                        ,@Version_ID = @Version_ID  
                        ,@Hierarchy_ID = NULL  
                        ,@ParentIdList = @parentIdList  
                        ,@ValidationStatus_ID = 5  
                        ,@MaxLevel = 0  
                        ,@IncludeParent = 0;  
                END -- IF @ChildAttributeColumnName  
  
            END -- IF @MemberType_ID  
        END -- IF @DoInheritanceRuleCheck  
  
        -- File Type attribute  
        IF (@AttributeType_ID = 4)   
        BEGIN  
            -- remove old record from mdm.tblFile for updates   
            -- since the new record is being inserted in Business Logic Save  
            DECLARE @TempPriorValueID INT = CONVERT(INT, @TempPriorValue);	  
            SET @SQL = N'DELETE FROM mdm.tblFile    
                         WHERE ID = @TempPriorValueID;';  
            EXEC sp_executesql @SQL, N'@TempPriorValueID INT', @TempPriorValueID;	           
        END;  
          
        --Log the Transaction if value has changed  
        --EDM-1632: calling this mdm.udp to get the updated value back in the same format so we can do a proper comparison below to see if the value has changed.  
        EXEC mdm.udpMemberPriorValueGet @Version_ID, @TableName, @TableColumn, @Member_ID, @TempUpdatedValue OUTPUT;  
  
        IF (ISNULL(@TempPriorValue, N'') <> ISNULL(@TempUpdatedValue, N'')) BEGIN  
  
            IF @LogFlag = 1 BEGIN  
                EXEC mdm.udpTransactionSave @User_ID,@Version_ID,3,NULL,NULL,@Entity_ID,@Member_ID,@MemberType_ID,@Attribute_ID,@TempPriorValue,@TempUpdatedValue;  
            END; --if  
  
        END; --if  
  
        --Put a msg onto the SB queue to process member security  
        EXEC mdm.udpSecurityMemberQueueSave   
            @Role_ID    = NULL,-- update member count cache for all users  
            @Version_ID = @Version_ID,  
            @Entity_ID  = @Entity_ID;  
          
        --Commit only if we are not nested  
        IF @TranCounter = 0 COMMIT TRANSACTION;  
  
        RETURN(@Return);  
  
    END TRY  
    --Compensate as necessary  
    BEGIN CATCH  
  
        -- Get error info  
        DECLARE  
            @ErrorMessage NVARCHAR(4000),  
            @ErrorSeverity INT,  
            @ErrorState INT,  
            @ErrorNumber INT;  
        EXEC mdm.udpGetErrorInfo  
            @ErrorMessage = @ErrorMessage OUTPUT,  
            @ErrorSeverity = @ErrorSeverity OUTPUT,  
            @ErrorState = @ErrorState OUTPUT,  
            @ErrorNumber = @ErrorNumber OUTPUT;  
  
        IF @TranCounter = 0 ROLLBACK TRANSACTION;  
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
        IF (@ErrorNumber = 8152) BEGIN  
            RAISERROR('MDSERR110017|The attribute value length cannot be greater than the maximum size allowed.', 16, 1);  
        END ELSE BEGIN  
            RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);  
        END; --if  
  
        --On error, return NULL results  
        --SELECT @Return_ID = NULL;  
        RETURN(@ErrorNumber);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
